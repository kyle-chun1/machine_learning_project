# Behavioral checks: label safety, missing semantics, mapping parser and integrity.
# Run from project root after acquiring data. Base R + digest only.
source("R/data_io.R")
source("R/cleaning_audit.R")
expect_error <- function(expr, pattern) {
  e <- tryCatch({force(expr); NULL}, error = identity)
  stopifnot(inherits(e, "error"), grepl(pattern, conditionMessage(e)))
}
fixture <- data.frame(encounter_id = c("001", "002", "003"),
  patient_nbr = c("010", "010", "020"), gender = c("Female", "Male", "Unknown/Invalid"),
  age = c("[50-60)", "[60-70)", "[70-80)"),
  admission_type_id = c("1", "2", "3"), discharge_disposition_id = c("1", "11", "13"),
  admission_source_id = c("7", "1", "1"), readmitted = c("NO", "<30", ">30"),
  diag_1 = c("250.13", "?", "V45"), diag_2 = c("?", "401", "250"),
  diag_3 = c("401", "250", "?"), A1Cresult = c("None", ">7", "Norm"),
  max_glu_serum = c("None", "Norm", ">200"), stringsAsFactors = FALSE)
for (nm in numeric_fields) fixture[[nm]] <- c("1", "2", "3")
clean <- normalize_records(fixture)
stopifnot(identical(clean$early_readmission, c(0L, 1L, 0L)),
          identical(clean$patient_nbr, fixture$patient_nbr), nrow(clean) == 3L,
          is.na(clean$gender[3]), is.na(clean$diag_1[2]),
          as.character(clean$diag_1[1]) == "250.13",
          as.character(clean$A1Cresult[1]) == "None", !is.na(clean$max_glu_serum[1]),
          is.factor(clean$admission_type_id), is.integer(clean$time_in_hospital))
bad <- fixture; bad$readmitted[1] <- "unknown"
expect_error(normalize_records(bad), "Unknown target")
bad <- fixture; bad$encounter_id[2] <- bad$encounter_id[1]
expect_error(normalize_records(bad), "Duplicate encounter")
bad <- fixture; bad$num_medications[1] <- "-1"
expect_error(normalize_records(bad), "Invalid nonnegative")
bad <- fixture; bad$time_in_hospital[1] <- "15"
expect_error(normalize_records(bad), "Length of stay")
mapping <- read_id_mapping()
stopifnot(nrow(mapping) == 63L,
  mapping$description[mapping$variable == "discharge_disposition_id" & mapping$code == "19"] ==
    "Expired at home. Medicaid only, hospice.")
a <- audit_records(fixture, mapping)
stopifnot(identical(a$cohort_scenarios$encounters_retained, c(3L, 2L, 1L)),
          nrow(a$normalized) == 3L, a$overview$value[a$overview$measure == "unique_patients"] == 2L)
bad <- fixture; bad$admission_type_id[1] <- "999"
b <- audit_records(bad, mapping)
stopifnot(b$flags$affected_encounters[b$flags$rule == "unmapped_categorical_code"] == 1L)
# Exercise local ZIP acquisition in a disposable directory and reject tampering.
scratch <- tempfile("acquisition-check-"); dir.create(scratch)
on.exit_cleanup <- function() unlink(scratch, recursive = TRUE)
tryCatch({
  dest <- file.path(scratch, "raw")
  archive <- file.path(scratch, "source.zip")
  if (!nzchar(Sys.which("zip"))) stop("Acquisition tests require the system zip command.")
  utils::zip(archive, file.path("data/raw", c("diabetic_data.csv", "IDS_mapping.csv")),
             flags = "-jq")
  acquire_data(archive, raw_dir = dest)
  before <- verify_raw(dest)
  acquire_data(raw_dir = dest)
  stopifnot(identical(before, verify_raw(dest)))
  cat("\ntampered", file = file.path(dest, "IDS_mapping.csv"), append = TRUE)
  expect_error(verify_raw(dest), "checksum mismatch")
  expect_error(acquire_data(raw_dir = dest), "checksum mismatch")
}, finally = on.exit_cleanup())
cat("All audit and acquisition checks passed.\n")
