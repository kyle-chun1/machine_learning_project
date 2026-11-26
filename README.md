# STSCI 3740: Predicting 30-Day Hospital Readmission

A four-person course project using R to predict early hospital readmission among patients with diabetes.

**Deadline:** December 4, 2026, at 9:00 PM EST, via Canvas.  
**Deliverables:** PDF report and the R code used for the analysis.

## Research question

How well can information available at discharge predict readmission within 30 days, and does allowing nonlinear relationships improve prediction?

We will define the binary outcome from `readmitted`:

- **1 (early readmission):** `<30`
- **0 (no early readmission recorded):** `>30` or `NO`

`NO` means no recorded readmission; it does not establish that a patient was never readmitted elsewhere.

## Data and references

Use the **Diabetes 130-US Hospitals for Years 1999–2008** dataset:

- [UCI dataset, variable descriptions, and download](https://archive.ics.uci.edu/dataset/296/diabetes-130-us-hospitals-for-years-1999-2008)
- Files: `diabetic_data.csv` and `IDS_mapping.csv`
- Dataset citation: Clore, J., Cios, K., DeShazo, J., and Strack, B. (2014). *Diabetes 130-US Hospitals for Years 1999–2008*. UCI Machine Learning Repository. https://doi.org/10.24432/C5230J
- Background paper: Strack et al. (2014), *Impact of HbA1c Measurement on Hospital Readmission Rates: Analysis of 70,000 Clinical Database Patient Records*. https://doi.org/10.1155/2014/781670

The source contains 101,766 hospital encounters from 130 US hospitals and integrated delivery networks. Rows represent encounters, not necessarily distinct patients. The dataset is licensed under CC BY 4.0; retain attribution.

## Agreed analysis

We will compare a small set of models grounded in the course slides.

| Model | Role | Course connection |
| --- | --- | --- |
| Majority-class baseline | Always predict the training set's majority class | Classification error |
| Multiple logistic regression | Main interpretable model | Lecture 7 |
| Linear discriminant analysis (LDA) | Alternative classifier using the same predictor information | Lecture 7 |
| Logistic regression with natural splines | Test nonlinear relationships for selected numeric predictors | Lecture 14 |

Categorical encoding and interpretation connect to Lecture 6. Model comparison uses the resampling and model-selection material.

SLR, MLR, and OLS remain useful foundations, but the primary outcome is binary. Logistic regression keeps fitted probabilities between zero and one. A separate continuous-outcome analysis is not part of the initial scope.

Ridge/lasso, PCR, extensive subset searches, trees, random forests, and boosting are outside this agreed comparison.

### 1. Data audit and preparation

- Check column types, missing-value codes, repeated patients, outcome balance, and discharge categories.
- Read the mapping file before interpreting integer-coded categories.
- Document cohort exclusions, including the treatment of death/hospice discharge categories, before modeling.
- Distinguish missing values from meaningful categories such as a laboratory test not being performed.
- Use only information available at discharge.
- Keep `patient_nbr` for grouping and `encounter_id` for tracking; exclude both from predictors.
- Record cleaning decisions and resulting encounter and patient counts. Do not automatically drop every incomplete record.
- Choose a manageable, justified predictor set after the audit. Review sparse categories and redundant columns before fitting LDA.
- Fit imputation, scaling, category pooling, and other learned preprocessing within each training fold.

### 2. Exploratory analysis

Use training data to examine missingness and outcome balance, then make focused plots of readmission patterns against predictors such as age group, previous inpatient visits, and length of stay. Use `ggplot2` and keep figures tied to modeling decisions.

### 3. Shared validation

- Set and record a random seed.
- Reserve approximately 20% of patients for a final test set; encounter proportions may differ.
- Use five-fold cross-validation within the remaining patients.
- Keep every encounter for a patient in the same partition and cross-validation fold.
- Share one saved split/fold assignment across all model comparisons.
- Use the same eligible cohort and predictor information for the core comparisons; document model-specific encoding.
- Tune only a small range of spline complexity using training cross-validation.
- Choose the model and any alternative classification threshold before examining test performance.
- Evaluate the frozen comparisons on the test set and report them without further tuning.

Patient grouping assesses prediction for held-out patients. It does not establish performance in future years or unseen hospitals.

### 4. Evaluation and interpretation

Report classification error/accuracy alongside sensitivity, specificity, precision, and ROC-AUC. Include a confusion matrix and majority-class benchmark: accuracy alone may hide poor identification of early readmissions.

Use 0.5 as the conventional classification threshold. If we also report a lower threshold, define its selection rule in advance and choose it using training cross-validation only. Select a primary model-comparison criterion before fitting models.

Interpret logistic coefficients as associations, not causal effects. Discuss LDA's class-conditional normality and shared-covariance assumptions, and whether splines improve prediction enough to justify their complexity.

## Report requirements

- PDF of **no more than eight pages**, with **12-point font** and **1.5 or double spacing**.
- All statistical analysis conducted in **R**.
- R programs submitted with the report; programs do not count toward the eight-page limit.
- Every group member's name and NetID on the first page.
- Justify models and methods through prediction accuracy/error comparisons.

Connect the math, selected code excerpts, reasoning, results, and limitations. Submit complete runnable code separately. Keep references within the eight-page budget unless the instructor explicitly says otherwise.

One teammate submits through Canvas for the group. Test the group submission process before the deadline. The assignment specifies a hard deadline and penalties for late work.

## R Markdown workflow

1. Develop and review R Markdown analyses as HTML.
2. Put shared preparation and reusable functions in R scripts.
3. Integrate agreed figures, tables, explanations, and selected code into one `report.Rmd`.
4. Test PDF rendering early; produce and check the final PDF once analysis is settled.
5. Confirm the final report renders from a fresh R session using documented setup steps.

Use project-relative paths, record seeds and package versions, and use `renv` to share the package environment once initialized.

### Planned repository layout

This is a proposed structure, not a list of files already implemented:

| Path | Purpose |
| --- | --- |
| `report.Rmd` | Final report source |
| `analysis/` | Exploration and model-development R Markdown files |
| `R/` | Shared import, preparation, splitting, and evaluation scripts |
| `data/` | Downloaded source data and generated analysis inputs |
| `results/` | Generated figures, tables, and model summaries |
| `renv.lock` | Shared package versions, once initialized |

Data-download instructions, package setup, and render commands will be added when implemented. Avoid committing large model objects, caches, or temporary outputs.

This repository is public. Keep private course materials, credentials, and personal files out of it. Names and NetIDs are required in the submitted report; do not add teammates' NetIDs to public files without their agreement.

## Working together

All four members contribute to analysis, interpretation, and review. Responsibilities have not yet been assigned.

- Coordinate tasks before starting overlapping work.
- Use descriptive branches such as `analysis/data-audit` or `analysis/logistic`.
- Make small commits and open pull requests explaining the change and how it was checked.
- Review changes before merging into `main`.
- Reuse the shared cohort, preprocessing rules, and folds. Propose changes to shared decisions explicitly.
- Develop independently in separate notebooks, then integrate reviewed results into the report.
- Record methods and decisions as work progresses.

## Current status and next steps

**Planning is complete; analysis implementation has not started.** This README records the agreed scope and does not report model results.

1. Implement reproducible data acquisition and the cleaning audit.
2. Agree on cohort exclusions, predictors, and the primary comparison criterion.
3. Save shared patient-level test and cross-validation assignments.
4. Build the HTML exploration notebook and fit the baseline and logistic model.
5. Add LDA and the spline extension, compare results, and write the report.
