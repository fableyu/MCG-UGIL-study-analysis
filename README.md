# MCG UGIL diagnostic accuracy analysis

R scripts for evaluating the diagnostic accuracy of mobile capsule gastroscopy (MCG) for upper gastrointestinal lesions (UGILs) against oesophagogastroduodenoscopy (OGD), including subgroup analyses and paired comparisons of manual and AI-assisted keyframe reading.

## Files

| Script | Purpose |
| --- | --- |
| `01_primary_analysis.R` | Overall, organ-specific, individual-disease and per-lesion diagnostic analyses; shared functions used by the other scripts. |
| `02_subgroup_analysis.R` | Clinically important upper gastrointestinal lesions (UGIL) and indication subgroups. |
| `03_reading_mode_comparison.R` | Paired comparisons of diagnostic metrics and reading times between manual and AI-assisted keyframe reading. |

Keep all three scripts in the same directory.

## Requirements

Use R 4.1 or later (the scripts use the native pipe operator). Install the required packages in R:

```r
install.packages(c("readxl", "dplyr", "writexl", "DTComPair"))
```

`DTComPair` is required for script 03. Package versions and R session information are recorded in `sessionInfo.txt` when each script runs.

## Input data

Deidentified participant data in the source Excel workbook and associated documentation will be made available to researchers for any reasonable purpose, subject to a data use agreement, after completion and publication of all preplanned analyses. Requests should be directed to Xiaobei Luo or James Yun Wong Lau, the corresponding authors.

These scripts target the final study workbook, containing 475 paired participants and 798 lesion records, and validate its structure and analysis populations. They are not generic scripts for arbitrary workbooks.

Required worksheets include:

- `lesion record`: lesion-level diagnoses, adjudicated concordance and clinically important lesion classification.
- `0baseline+satisfaction+followup`: participant IDs and indications.
- `Examination time of MCG`: examination times used to identify duodenal entry.
- `reading time`: paired manual and AI keyframe reading times.

The shared reader ignores leading worksheet numbering of the form `1.`. Exact column names, diagnosis labels and validation rules are specified in the scripts. Participant IDs must be five-character numeric strings. The primary script also contains seven excluded research IDs as an input validation rule; no associated participant records are included.

## Run

From the directory containing the scripts:

```sh
Rscript 01_primary_analysis.R /path/to/input.xlsx /path/to/results
Rscript 02_subgroup_analysis.R /path/to/input.xlsx /path/to/results
Rscript 03_reading_mode_comparison.R /path/to/input.xlsx /path/to/results
```

Quote paths containing spaces. The output directory is optional and defaults to `results` beside the scripts. Scripts 02 and 03 load shared functions from script 01 and can run independently of its outputs.

## Outputs

The scripts create Excel results under `primary/`, `subgroups/` and `reading_mode_comparison/`, respectively. They also record the input filename and MD5 checksum in `input_checksum.csv`. When the same output directory is reused, the top-level session information and checksum files are overwritten by the latest run.

Generated workbooks include participant-level records. Keep input data and generated results outside version control; the supplied `.gitignore` excludes Excel files and the default results directory.

## Validation scope

The uploaded R files match the supplied source scripts. All three scripts passed an R syntax check before upload. The analyses were not rerun against a source workbook as part of this upload.

## License

No open-source license has been assigned.
