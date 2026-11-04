# Run all MCG study analyses from a single Excel workbook.
# Usage: Rscript 00_run_all.R input.xlsx [output_directory]

# Read arguments and check required packages.
args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 1L || length(args) > 2L)
  stop("Usage: Rscript 00_run_all.R input.xlsx [output_directory]")
required <- c("readxl", "dplyr", "writexl", "DTComPair")
missing <- required[!vapply(required, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing)) stop("Install required packages first: ", paste(missing, collapse = ", "))

# Set input and output paths.
input <- normalizePath(args[1], mustWork = TRUE)
script_file <- gsub("~+~", " ", sub("^--file=", "", commandArgs()[grepl("^--file=", commandArgs())][1]), fixed = TRUE)
code_dir <- dirname(normalizePath(script_file, mustWork = TRUE))
output <- if (length(args) == 2L) args[2] else file.path(code_dir, "results")
dir.create(output, recursive = TRUE, showWarnings = FALSE)
output <- normalizePath(output, mustWork = TRUE)

# Run the analysis scripts in sequence.
scripts <- c("01_primary_analysis.R", "02_subgroup_analysis.R",
             "03_reading_mode_comparison.R", "04_other_analyses.R")
for (script in scripts) {
  status <- system2(file.path(R.home("bin"), "Rscript"),
                    c("--vanilla", shQuote(file.path(code_dir, script)), shQuote(input), shQuote(output)))
  if (status != 0L) stop("Analysis failed: ", script)
}
cat("All analyses completed. Results:", output, "\n")
