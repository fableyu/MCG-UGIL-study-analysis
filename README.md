# MCG UGIL study analysis

Repository: [https://github.com/fableyu/MCG-UGIL-study-analysis](https://github.com/fableyu/MCG-UGIL-study-analysis).

R code for the diagnostic and non-diagnostic numerical analyses of mobile capsule gastroscopy (MCG) for upper gastrointestinal lesions (UGILs), using oesophagogastroduodenoscopy (OGD) as the reference standard.

## Requirements

Use R 4.1 or later. The code has been run with R 4.6.0 and these packages:

| Package | Tested version |
| --- | --- |
| readxl | 1.5.0 |
| dplyr | 1.2.1 |
| writexl | 1.5.4 |
| DTComPair | 1.2.6 |

Install the packages once in R:

```r
install.packages(c("readxl", "dplyr", "writexl", "DTComPair"),
                 repos = "https://cloud.r-project.org")
```

Package installation requires internet access. The analyses then run locally without internet access. The runner checks the packages before starting; it does not install software automatically.

## Input data

The sole analysis input is the study Excel workbook, `1.HomeCe_RawData.xlsx`. The local copy with an added derived procedural-steps sheet is also supported. Keep the participant IDs as five-character strings and retain the column labels.

The required worksheets are:

- `0.screening log`
- `1baseline+satisfaction+followup`
- `1.Withdraw or excluded list`
- `1.Adverse events`
- `2.lesion record`
- `3.reading time`
- `4.visualisation rates`
- `5.Examination time of MCG`

Participant-level data are not included in this code package.

## Run

Keep the five R files together. From a terminal, run:

```sh
Rscript 00_run_all.R "/path/to/1.HomeCe_RawData.xlsx" "/path/to/results"
```

Quote paths containing spaces. Omit the second argument to write results to `results` beside the scripts. The four analysis scripts may also be run separately with the same arguments. Scripts 02, 03 and 04 load shared functions from script 01.

## Analyses and outputs

| Script | Analyses | Main outputs |
| --- | --- | --- |
| `00_run_all.R` | Dependency checks and sequential execution | Run status |
| `01_primary_analysis.R` | Overall, organ-level, disease-specific and per-lesion diagnostic performance; duodenal FAS/PPS | `primary/` |
| `02_subgroup_analysis.R` | Clinically important UGILs and indication subgroups | `subgroups/` |
| `03_reading_mode_comparison.R` | Paired diagnostic differences, non-inferiority, kappa and reading times | `reading_mode_comparison/` |
| `04_non_diagnostic_analysis.R` | Sample size, recruitment flow, baseline characteristics, procedural status, visualisation, examination durations, comfort, excretion and safety | `non_diagnostic_results.xlsx` |

## Statistical conventions

- Overall diagnostic positives exclude no lesion and superficial/chronic gastritis. Disease-specific analyses still report superficial/chronic gastritis as its own outcome.
- Proportion CIs for diagnostic performance use Wilson intervals. Individual kappa intervals retain the supplied Wald approximation, except duodenal analyses, which use the multinomial delta method. Paired kappa differences use the joint multinomial delta method.
- Sensitivity, specificity and accuracy differences use paired Wald CIs and exact two-sided McNemar tests. PPV and NPV differences use participant bootstrap percentile CIs with 2,000 resamples and seed 1; their two-sided tests use `DTComPair::pv.gs`.
- Non-inferiority uses an absolute margin of 0.05. A lower two-sided 95% CI above -0.05 establishes non-inferiority; one-sided P values are reported separately from two-sided reading-mode comparison P values.
- Paired reading times use a Wilcoxon signed-rank test with normal approximation and continuity correction. Comfort comparisons use exact paired sign/McNemar tests as labelled in the output.
- Landmark and satisfaction proportion intervals use exact Clopper-Pearson intervals. Continuous summaries use R's default type-7 quantiles; the recorded excretion-day mean uses a t-based interval.

## Data provenance and current checks

Routine procedural steps are derived from the overall self-administration status under an author-confirmed rule: the recorded statuses identify water/posture deviations; other routine steps are classified as completed. The derived records are exported for inspection. They are not separate step-level observations. “No deviation recorded” does not establish whether an AI prompt was issued.

The original all-participant calculation of recorded excretion days is retained. Two source notes state that natural expulsion was not observed and the recorded days represent last defecation before radiographic confirmation. Those values have not been altered; interpretation of the mean requires alignment with the source records and Supplementary Methods.

`Chronology_checks` identifies conflicts between screening dates and examination dates. Both sets of supplied dates are retained. These conflicts require verification against the original screening records; code cannot reconstruct actual enrolment dates from ordering constraints.

All five scripts completed without errors with the supplied workbook, including the renamed and reordered worksheets. All 40 result workbooks retained identical analysis values; only the input checksum changed. Main-table numeric values were reconciled. The supplementary document and protocol still require review before the package can be certified as covering every reported result.

## Licence

No open-source licence has been assigned. A code licence should be selected before public release. Data licensing is a separate decision.
