numeric_fields <- c("time_in_hospital", "num_lab_procedures", "num_procedures",
                    "num_medications", "number_outpatient", "number_emergency",
                    "number_inpatient", "number_diagnoses")
id_fields <- c("encounter_id", "patient_nbr")
mapping_fields <- c("admission_type_id", "discharge_disposition_id", "admission_source_id")
death_codes <- c("11", "19", "20", "21")
hospice_codes <- c("13", "14")

normalize_records <- function(raw) {
  required <- c(id_fields, numeric_fields, mapping_fields, "readmitted", "gender",
                "age", "diag_1", "diag_2", "diag_3", "A1Cresult", "max_glu_serum")
  if (!all(required %in% names(raw))) stop("Required columns missing.")
  if (anyNA(raw) || any(vapply(raw, function(x) any(!nzchar(trimws(x))), logical(1)))) {
    stop("Unexpected empty/NA raw fields; inspect import conventions before cleaning.")
  }
  if (!all(raw$readmitted %in% c("<30", ">30", "NO"))) stop("Unknown target label.")
  if (anyDuplicated(raw$encounter_id)) stop("Duplicate encounter IDs require investigation.")
  if (any(!grepl("^[0-9]+$", raw$patient_nbr)) ||
      any(!grepl("^[0-9]+$", raw$encounter_id))) stop("Invalid identifier.")
  clean <- raw
  clean[] <- lapply(clean, function(x) { x[x == "?"] <- NA_character_; x })
  clean$gender[clean$gender == "Unknown/Invalid"] <- NA_character_
  for (nm in numeric_fields) {
    x <- clean[[nm]]
    if (anyNA(x) || any(!grepl("^[0-9]+$", x))) stop("Invalid nonnegative count: ", nm)
    clean[[nm]] <- as.integer(x)
  }
  if (any(clean$time_in_hospital < 1L | clean$time_in_hospital > 14L)) {
    stop("Length of stay outside documented 1–14 day range.")
  }
  # Known coding rules only: no fitted imputation, scaling or category pooling.
  categorical <- setdiff(names(raw), c(id_fields, numeric_fields))
  clean[categorical] <- lapply(clean[categorical], factor)
  clean$early_readmission <- as.integer(raw$readmitted == "<30")
  clean
}

audit_records <- function(raw, mapping) {
  normalized <- normalize_records(raw)
  n <- nrow(raw)
  missing <- data.frame(
    variable = names(raw),
    question_mark = vapply(raw, function(x) sum(x == "?"), integer(1)),
    normalized_missing = vapply(normalized[names(raw)], function(x) sum(is.na(x)), integer(1)),
    distinct_nonmissing = vapply(normalized[names(raw)], function(x) length(unique(x[!is.na(x)])), integer(1)),
    stringsAsFactors = FALSE)
  missing$missing_percent <- 100 * missing$normalized_missing / n
  missing <- missing[order(-missing$normalized_missing, missing$variable), ]
  rownames(missing) <- NULL
  class_counts <- as.data.frame(table(factor(raw$readmitted, levels = c("<30", ">30", "NO"))),
                                stringsAsFactors = FALSE)
  names(class_counts) <- c("source_label", "encounters")
  class_counts$percent <- 100 * class_counts$encounters / n
  visits <- table(raw$patient_nbr)
  overview <- data.frame(
    measure = c("encounters", "source_columns", "unique_patients", "patients_with_multiple_encounters",
                "encounters_from_repeat_patients", "maximum_encounters_per_patient",
                "duplicate_encounter_ids", "duplicate_full_rows", "early_readmissions"),
    value = c(n, ncol(raw), length(visits), sum(visits > 1L), sum(visits[visits > 1L]),
              max(visits), sum(duplicated(raw$encounter_id)), sum(duplicated(raw)),
              sum(normalized$early_readmission)))
  map_counts <- do.call(rbind, lapply(mapping_fields, function(nm) {
    counts <- as.data.frame(table(raw[[nm]]), stringsAsFactors = FALSE)
    names(counts) <- c("code", "encounters")
    dictionary <- mapping[mapping$variable == nm, ]
    counts$variable <- nm
    counts$description <- dictionary$description[match(counts$code, dictionary$code)]
    counts$mapping_found <- !is.na(counts$description)
    counts$unknown_description <- !counts$mapping_found |
      counts$description %in% c("NULL", "Not Available", "Not Mapped", "Unknown/Invalid")
    counts[c("variable", "code", "description", "encounters", "mapping_found", "unknown_description")]
  }))
  # Counts only: these masks DO NOT remove encounters from normalized data.
  d <- raw$discharge_disposition_id
  masks <- list(
    all_records = rep(TRUE, n),
    exclude_expired_only = !d %in% death_codes,
    exclude_expired_and_hospice = !d %in% c(death_codes, hospice_codes))
  cohort <- do.call(rbind, lapply(names(masks), function(nm) {
    keep <- masks[[nm]]
    data.frame(scenario = nm, encounters_retained = sum(keep), encounters_excluded = sum(!keep),
               patients_retained = length(unique(raw$patient_nbr[keep])), stringsAsFactors = FALSE)
  }))
  levels_table <- do.call(rbind, lapply(setdiff(names(raw), c(id_fields, numeric_fields)), function(nm) {
    x <- normalized[[nm]]
    counts <- as.data.frame(table(x, useNA = "ifany"), stringsAsFactors = FALSE)
    names(counts) <- c("level", "encounters")
    data.frame(variable = nm, counts, stringsAsFactors = FALSE)
  }))
  schema <- data.frame(variable = names(normalized),
                       storage = vapply(normalized, function(x) paste(class(x), collapse = "/"), character(1)),
                       role = ifelse(names(normalized) %in% id_fields, "tracking_only",
                         ifelse(names(normalized) %in% c("readmitted", "early_readmission"), "outcome",
                                "candidate_predictor")))
  flags <- data.frame(
    rule = c("missing_gender_normalized", "unmapped_categorical_code", "incomplete_diagnosis",
             "expired_discharge", "hospice_discharge"),
    affected_encounters = c(sum(raw$gender == "Unknown/Invalid"),
      sum(map_counts$encounters[!map_counts$mapping_found]),
      sum(rowSums(is.na(normalized[c("diag_1", "diag_2", "diag_3")])) > 0L),
      sum(d %in% death_codes), sum(d %in% hospice_codes)))
  list(normalized = normalized, overview = overview, missingness = missing,
       outcome = class_counts, mapping_counts = map_counts, cohort_scenarios = cohort,
       category_counts = levels_table, schema = schema, flags = flags)
}

run_audit <- function(output_dir = "results/audit") {
  provenance <- verify_raw()
  raw <- read_raw()
  if (nrow(raw) != 101766L || ncol(raw) != 50L) stop("Unexpected source dimensions.")
  mapping <- read_id_mapping()
  audit <- audit_records(raw, mapping)
  stopifnot(nrow(audit$normalized) == nrow(raw),
            identical(audit$normalized$encounter_id, raw$encounter_id),
            identical(audit$normalized$patient_nbr, raw$patient_nbr))
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  tables <- setdiff(names(audit), "normalized")
  for (nm in tables) write.csv(audit[[nm]], file.path(output_dir, paste0(nm, ".csv")),
                              row.names = FALSE, na = "")
  write.csv(provenance, file.path(output_dir, "source_checksums.csv"), row.names = FALSE)
  write.csv(mapping, file.path(output_dir, "id_mapping.csv"), row.names = FALSE)
  writeLines(c(paste("Retrieved/verified UTC:", format(Sys.time(), tz = "UTC", usetz = TRUE)),
               paste("Source:", uci_url), "SHA-256 pins: data/source_manifest.csv",
               "Scope: full-source data quality only; no fitted preprocessing or model evaluation."),
             file.path(output_dir, "provenance.txt"))
  writeLines(capture.output(sessionInfo()), file.path(output_dir, "session_info.txt"))
  dir.create("data/derived", recursive = TRUE, showWarnings = FALSE)
  saveRDS(audit$normalized, "data/derived/normalized_audit_only.rds", version = 3)
  invisible(audit)
}
