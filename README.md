# MCG UGIL study analysis

Repository: [https://github.com/fableyu/MCG-UGIL-study-analysis](https://github.com/fableyu/MCG-UGIL-study-analysis).

R scripts for statistical analyses of the multicentre study evaluating mobile capsule gastroscopy (MCG) for upper gastrointestinal lesions (UGILs).

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

The analysis input is the study Excel workbook, `1.HomeCe_RawData.xlsx`. Keep participant IDs as five-character strings and retain the column labels.

The required worksheets are:

- `0.screening log`
- `1baseline+satisfaction+followup`
- `1.procedural steps`
- `1.Withdraw or excluded list`
- `1.Adverse events`
- `2.lesion record`
- `3.reading time`
- `4.visualisation rates`
- `5.Examination time of MCG`

Participant-level data are not included in this code package.

Procedural steps are derived from the recorded self-administration status. Responses to water guidance are read from `1.procedural steps`.

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
| `04_other_analyses.R` | Sample size, recruitment flow, baseline characteristics, procedural status, visualisation, examination durations, comfort, excretion and safety | `non_diagnostic_results.xlsx` |

## Statistical conventions

1. A participant was classified as UGIL-positive if upper gastrointestinal lesions were detected. A participant was classified as UGIL-negative if no lesions were detected or if chronic superficial gastritis was the only finding.
2. Proportion CIs for diagnostic performance use Wilson intervals. Individual kappa intervals use the Wald approximation, except duodenal analyses, which use the multinomial delta method. Paired kappa differences use the joint multinomial delta method.
3. Sensitivity, specificity and accuracy differences use paired Wald CIs and exact two-sided McNemar tests. PPV and NPV differences use participant bootstrap percentile CIs with 2,000 resamples and seed 1; their two-sided tests use `DTComPair::pv.gs`.
4. Non-inferiority uses an absolute margin of 0.05. A lower two-sided 95% CI above -0.05 establishes non-inferiority; one-sided P values are reported separately from two-sided reading-mode comparison P values.
5. Paired reading times use a Wilcoxon signed-rank test with normal approximation and continuity correction. Comfort comparisons use exact paired sign/McNemar tests as labelled in the output.
6. Landmark and satisfaction proportion intervals use exact Clopper-Pearson intervals. Continuous summaries use R's default type-7 quantiles; the recorded excretion-day mean uses a t-based interval.

## Licence

No licence has been assigned.
