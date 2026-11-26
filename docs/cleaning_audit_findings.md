# Cleaning audit checkpoint

Source: UCI dataset 296, original files verified using `data/source_manifest.csv`.
Run `Rscript scripts/render_audit.R` from the repository root for the full HTML audit, including code, tables, plot, and session information. No model has been fitted.

## Observations

| Check | Result |
| --- | ---: |
| Encounters | 101,766 |
| Source columns | 50 |
| Distinct patients | 71,518 |
| Patients with repeated encounters | 16,773 |
| Maximum encounters for one patient | 40 |
| Duplicate encounter IDs / duplicate full rows | 0 / 0 |
| Early readmission labels | 11,357 (11.16%) |
| Missing weight | 98,569 (96.86%) |
| Missing medical specialty | 49,949 (49.08%) |
| Missing payer code | 40,256 (39.56%) |
| Missing race | 2,273 (2.23%) |
| Unknown/invalid gender | 3 |
| Encounters missing at least one diagnosis | 1,522 |
| Observed admission/discharge codes absent from dictionary | 0 |

## Applied changes

Convert `?` to `NA`, and unknown/invalid gender to `NA`; retain literal laboratory `None` levels. Keep IDs as strings, counts as integers, and categorical predictors (including diagnosis and mapping codes) as factors. Add binary `early_readmission`, preserving source outcome `readmitted`. No encounters are removed. No imputation, scaling, rare-level pooling, model fitting, or predictor selection is performed.

## Proposals for team review

| Cohort scenario | Retained encounters | Retained patients | Excluded encounters |
| --- | ---: | ---: | ---: |
| Retain all source encounters | 101,766 | 71,518 | 0 |
| Exclude expired discharges only | 100,114 | 70,439 | 1,652 |
| Exclude expired and hospice discharges | 99,343 | 69,990 | 2,423 |

Expired codes: 11, 19, 20, 21. Hospice codes: 13, 14. Hospice is a separate scope decision, not a claim that readmission is impossible. These scenarios count alternatives only and do not filter the saved data.

Weight is a candidate for omission; specialty and payer need an explicit missing-data strategy. Treat dictionary values such as `NULL`, `Not Mapped`, and `Not Available` deliberately. Avoid treating integer-coded categories or ICD codes as numeric measurements. Decide the predictor set and primary comparison criterion before modeling.

Full-source summaries here serve only data-quality and target-coding checks. Outcome-focused exploration and learned preprocessing must use the training data after shared patient splits are established. Repeated patients are not duplicate encounters and must remain grouped in splits and folds.

## Verification

The raw source hashes and full-data dimensions are checked before every run. Behavioral checks cover label rejection, repeated-patient preservation, explicit missing values versus unperformed tests, mapping descriptions with commas, non-destructive cohort scenarios, invalid counts, checksum failure, and repeat acquisition. Generated tables and HTML are reproducible local outputs; the aggregate checkpoint above is the versioned review summary.

Package environment locking, final cohort decisions, shared patient splits, model development, and the final report remain future work.
