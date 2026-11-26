# Run entry-point scripts from the repository root. No packages auto-install.
uci_url <- paste0("https://archive.ics.uci.edu/static/public/296/",
                  "diabetes+130-us+hospitals+for+years+1999-2008.zip")

sha256_file <- function(path) {
  if (!requireNamespace("digest", quietly = TRUE)) {
    stop("Install digest first: install.packages('digest')")
  }
  digest::digest(file = path, algo = "sha256", serialize = FALSE)
}

verify_raw <- function(raw_dir = "data/raw", manifest = "data/source_manifest.csv") {
  pins <- read.csv(manifest, colClasses = "character")
  paths <- file.path(raw_dir, pins$file)
  if (!all(file.exists(paths))) stop("Raw files missing. Run Rscript scripts/acquire_data.R")
  actual <- vapply(paths, sha256_file, character(1))
  if (any(actual != pins$sha256)) {
    stop("Raw file checksum mismatch: ", paste(pins$file[actual != pins$sha256], collapse = ", "),
         ". Preserve these files and investigate; do not silently replace them.")
  }
  data.frame(file = pins$file, bytes = unname(file.info(paths)$size),
             sha256 = unname(actual), stringsAsFactors = FALSE)
}

acquire_data <- function(archive = NULL, raw_dir = "data/raw") {
  expected <- read.csv("data/source_manifest.csv", colClasses = "character")$file
  present <- file.exists(file.path(raw_dir, expected))
  if (all(present)) return(invisible(verify_raw(raw_dir)))
  if (any(present)) stop("Partial raw directory: preserve it and resolve before acquisition.")
  stage <- tempfile("uci-stage-")
  dir.create(stage)
  on.exit(unlink(stage, recursive = TRUE), add = TRUE)
  if (is.null(archive)) {
    archive <- file.path(stage, "uci_diabetes.zip")
    old_timeout <- getOption("timeout")
    options(timeout = max(120, old_timeout))
    on.exit(options(timeout = old_timeout), add = TRUE)
    tryCatch(download.file(uci_url, archive, mode = "wb", quiet = TRUE),
             error = function(e) stop("Download failed. Download the UCI ZIP in your browser, then run ",
               "Rscript scripts/acquire_data.R /path/to/download.zip\n", conditionMessage(e)))
  }
  if (!file.exists(archive)) stop("Archive not found: ", archive)
  entries <- unzip(archive, list = TRUE)$Name
  if (!all(expected %in% entries)) stop("Archive lacks the two expected UCI CSV files.")
  unzip(archive, files = expected, exdir = stage)
  verify_raw(stage)
  dir.create(raw_dir, recursive = TRUE, showWarnings = FALSE)
  for (f in expected) {
    if (file.exists(file.path(raw_dir, f))) stop("Refusing to overwrite raw file: ", f)
    if (!file.copy(file.path(stage, f), file.path(raw_dir, f))) stop("Copy failed: ", f)
  }
  invisible(verify_raw(raw_dir))
}

read_raw <- function(path = "data/raw/diabetic_data.csv") {
  # All-character import preserves IDs, ICD codes, '?' and literal 'None'.
  read.csv(path, colClasses = "character", na.strings = character(),
           check.names = FALSE, stringsAsFactors = FALSE)
}

read_id_mapping <- function(path = "data/raw/IDS_mapping.csv") {
  # The source has THREE header-separated sections, not one rectangular table.
  lines <- readLines(path, warn = FALSE)
  headers <- which(grepl("^(admission_type_id|discharge_disposition_id|admission_source_id),", lines))
  if (length(headers) != 3L) stop("Unexpected mapping sections.")
  ends <- c(headers[-1L] - 1L, length(lines))
  pieces <- lapply(seq_along(headers), function(i) {
    block <- read.csv(text = paste(lines[headers[i]:ends[i]], collapse = "\n"),
                      colClasses = "character", na.strings = character(),
                      stringsAsFactors = FALSE)
    variable <- names(block)[1]
    block <- block[nzchar(trimws(block[[1]])), , drop = FALSE]
    data.frame(variable = variable, code = trimws(block[[1]]),
               description = trimws(block[[2]]), stringsAsFactors = FALSE)
  })
  out <- do.call(rbind, pieces)
  if (anyDuplicated(out[c("variable", "code")])) stop("Duplicate mapping keys.")
  out
}
