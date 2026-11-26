needed <- c("digest", "rmarkdown", "knitr", "ggplot2")
missing <- needed[!vapply(needed, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing)) stop("Install required packages: ", paste(missing, collapse = ", "))
if (!rmarkdown::pandoc_available()) stop("Pandoc required; use the RStudio bundled Pandoc.")
dir.create("results/audit", recursive = TRUE, showWarnings = FALSE)
rmarkdown::render("analysis/01_cleaning_audit.Rmd", output_file = "cleaning_audit.html",
                  output_dir = normalizePath("results/audit"),
                  knit_root_dir = normalizePath("."), envir = new.env(), quiet = TRUE)
cat("Rendered results/audit/cleaning_audit.html\n")
