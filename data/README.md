# Data acquisition

Source: [UCI dataset 296](https://archive.ics.uci.edu/dataset/296/diabetes-130-us-hospitals-for-years-1999-2008), DOI [10.24432/C5230J](https://doi.org/10.24432/C5230J), CC BY 4.0. Cite Clore et al. (2014) and the Strack et al. (2014) background paper linked in the root README.

Run from the repository root:

```r
install.packages(c("digest", "rmarkdown", "knitr", "ggplot2")) # once, if missing
```

```sh
Rscript scripts/acquire_data.R
Rscript scripts/run_audit.R
Rscript tests/check_audit.R
Rscript scripts/render_audit.R
```

RStudio supplies Pandoc for HTML rendering. A standalone R session may need Pandoc installed or RStudio's Pandoc on its path. The audit itself uses base R and digest; ggplot2, knitr, rmarkdown and Pandoc are needed for HTML. No package is installed automatically. These commands do not fit models.

If R cannot reach UCI, download the ZIP using the dataset page and import it:

```sh
Rscript scripts/acquire_data.R /absolute/path/to/the-downloaded.zip
```

The script extracts only `diabetic_data.csv` and `IDS_mapping.csv` into `data/raw/`. Committed SHA-256 pins in `source_manifest.csv` verify the extracted bytes. Existing matching files are reused. A partial directory or checksum mismatch stops execution rather than replacing existing raw data. If UCI changes the files, investigate and explicitly review updated pins before proceeding.

The original UCI archive was acquired on November 26, 2026 (UTC). The full data contain 101,766 encounters and 50 columns, including identifiers and the source outcome. The UCI feature count excludes these non-predictor columns.

`data/raw/`, `data/derived/`, and `results/` are ignored by Git. Do not upload full data or patient-level normalized outputs to the repository. Regenerate them using these scripts. Keep raw source bytes unchanged.

The normalized RDS is for audit only: it retains all encounters, IDs, source labels, and the new binary target. It is **not model-ready** and should not be used as a preprocessed matrix across validation folds. All learned preprocessing and factor-level handling must be fitted within training folds. The final cohort and shared splits remain pending.

The behavioral checks require a system `zip` command and build a temporary test archive from the verified source files. They cover local acquisition, reuse, tampering rejection, target coding, missing-value semantics, mapping parsing, and non-destructive cohort scenarios. Downloading through R remains dependent on local network access; the local-ZIP path supports restricted environments.
