# MCG: sample size, participant flow, baseline characteristics, and secondary outcomes.
# Usage: Rscript 04_other_analyses.R input.xlsx [output_directory]

self <- sub("^--file=", "", commandArgs()[grepl("^--file=", commandArgs())][1])
self <- gsub("~+~", " ", self, fixed = TRUE)
source(file.path(dirname(normalizePath(self, mustWork = TRUE)), "01_primary_analysis.R"))
config <- homece_init()
rawdata_path <- config$raw
output <- config$output
read_sheet <- function(sheet, id_col, pattern="^[0-9]{5}$")
  as.data.frame(read_workbook_sheet(sheet, id_col, pattern))
count_rows <- function(group, x, denominator) {
  z <- table(x, useNA = "ifany")
  data.frame(Group = group, Category = names(z), N = as.integer(z),
             Denominator = denominator, Percent = 100 * as.integer(z) / denominator,
             row.names = NULL)
}
exact_rate <- function(label, x, n) {
  ci <- 100 * binom.test(x, n)$conf.int
  data.frame(Measure = label, Numerator = x, Denominator = n,
             Percent = 100 * x / n, CI_low = ci[1], CI_high = ci[2])
}
time_summary <- function(label, seconds, allow_nonentry=FALSE) {
  text <- trimws(as.character(seconds))
  x <- suppressWarnings(as.numeric(text) / 60)
  nonentry <- allow_nonentry & tolower(text) %in% c("na", "n/a")
  if (any((!is.finite(x) & !nonentry) | (is.finite(x) & x < 0)))
    stop("Invalid examination time in region: ", label)
  x <- x[!nonentry]
  data.frame(Region = label, N = length(x), Median = median(x),
             Q1 = unname(quantile(x, .25)), Q3 = unname(quantile(x, .75)), Unit = "minutes")
}

screening <- read_sheet("0.screening log", "Screening number", "^S[0-9]{5}$")
baseline <- read_sheet("0baseline+satisfaction+followup", "Id")
withdrawn <- read_sheet("0.Withdraw or excluded list", "Id")
visualisation <- read_sheet("4.visualisation rates ", "ID")
exam_time <- read_sheet("5.Examination time of MCG", "ID")
reading_time <- read_sheet("3.reading time", "id")
events <- read_sheet("1.Adverse events ", "Id")
lesions <- read_sheet("2.lesion record", "ID")

enrolled <- screening[!is.na(screening$`Enrolment ID`), ]
enrolled_ids <- as.character(enrolled$`Enrolment ID`)
stopifnot(nrow(screening) == 906L, nrow(enrolled) == 482L,
          nrow(baseline) == 475L, nrow(withdrawn) == 7L,
          setequal(enrolled_ids, c(baseline$Id, withdrawn$Id)),
          !anyDuplicated(baseline$Id), !anyDuplicated(visualisation$ID),
          setequal(baseline$Id, visualisation$ID), !anyDuplicated(enrolled_ids),
          !anyDuplicated(screening$`Screening number`), !anyDuplicated(withdrawn$Id),
          !any(baseline$Id %in% withdrawn$Id),
          setequal(baseline$Id, exam_time$ID), !anyDuplicated(exam_time$ID),
          setequal(baseline$Id, reading_time$id), !anyDuplicated(reading_time$id),
          all(events$Id %in% enrolled_ids), !anyDuplicated(events$Id),
          all(is.finite(baseline$Age)), all(baseline$Age >= 18),
          !anyNA(baseline$`Self-administered Results`))
n_fas <- nrow(baseline)
unable_swallow <- sum(withdrawn$Reason == "Unable to swallow capsule")
n_sas <- nrow(enrolled) - unable_swallow
stopifnot(unable_swallow == 1L, n_sas == 481L)

prevalence <- .16
sensitivity <- .95
specificity <- .90
margin <- .05
dropout <- .05
minimum_n <- ceiling(qnorm(.975)^2 * sensitivity * (1 - sensitivity) /
                       (margin^2 * prevalence))
minimum_specificity_n <- ceiling(qnorm(.975)^2 * specificity * (1 - specificity) /
                                  (margin^2 * (1 - prevalence)))
target_n <- ceiling(minimum_n / (1 - dropout))
sample_size <- data.frame(
  Item = c("Expected prevalence", "Expected sensitivity", "CI margin", "Dropout allowance",
           "Minimum analysable N", "Target enrolment N",
           "Expected specificity", "Minimum N for specificity"),
  Value = c(prevalence, sensitivity, margin, dropout, minimum_n, target_n,
            specificity, minimum_specificity_n))

reason_n <- function(reason) sum(withdrawn$Reason == reason)
study_flow <- data.frame(
  Outcome = c("Screened", "Declined participation", "Did not meet inclusion criteria",
              "Enrolled", "Unable to swallow capsule", "Safety analysis set",
              "Data receiver loss", "MCG recordings for assessment", "Unexpected receiver shutdown",
              "Refused OGD", "OGD incomplete", "Full analysis set"),
  N = c(nrow(screening), sum(screening$`Reason for exclusion` == "Declined participation"),
        sum(screening$`Reason for exclusion` == "Did not meet inclusion criteria"), nrow(enrolled),
        unable_swallow, n_sas, reason_n("Data receiver loss"),
        n_sas - reason_n("Data receiver loss"), reason_n("Unexpected receiver shutdown"),
        reason_n("Refused OGD"), reason_n("OGD incomplete"), n_fas))
normal <- "Normal independent completion"
all_results <- c(baseline$`Self-administered Results`, withdrawn$`Self-administered Results`)
completed <- sum(all_results == normal) -
  sum(withdrawn$Reason == "Unable to swallow capsule" & withdrawn$`Self-administered Results` == normal)
completion_rate <- data.frame(Numerator = completed, Denominator = nrow(enrolled),
                              Percent = 100 * completed / nrow(enrolled))

# Table 1: baseline characteristics.
source_labels <- c(`1` = "Outpatient", `2` = "Endoscopy unit")
baseline_categories <- rbind(
  count_rows("Sex", baseline$Gender, n_fas),
  count_rows("Indication", baseline$Indication, n_fas),
  count_rows("Indication (collapsed)",
             ifelse(baseline$Indication %in% c("Health Screening", "Surveillance"),
                    baseline$Indication, "Symptomatic evaluation"), n_fas),
  count_rows("Patient source", source_labels[as.character(baseline[[grep("^Patient Source", names(baseline), value = TRUE)[1]]])], n_fas))
baseline_age <- data.frame(Statistic = c("N", "Mean", "SD", "Minimum", "Maximum"),
                           Value = c(n_fas, mean(baseline$Age), sd(baseline$Age),
                                     min(baseline$Age), max(baseline$Age)))

# Table S1: enrolment by centre.
centre_names <- c("Nanfang Hospital", "Second Affiliated Hospital of Guangzhou Medical University",
                  "Guangdong Provincial Hospital of Traditional Chinese Medicine", "Zhuhai People's Hospital",
                  "Longgang District People's Hospital of Shenzhen", "Shenzhen Pingshan People's Hospital",
                  "Ganzhou People's Hospital", "Mianyang Central Hospital", "Renhua County People's Hospital",
                  "Wuxi People's Hospital", "Prince of Wales Hospital")
enrolled$Centre <- substr(enrolled_ids, 1, 2)
centres <- do.call(rbind, lapply(sprintf("%02d", 1:11), function(code) {
  d <- enrolled[enrolled$Centre == code, ]
  data.frame(Centre_code = code, Centre = centre_names[as.integer(code)], Enrolled = nrow(d),
             Percent = 100 * nrow(d) / nrow(enrolled), First_enrolment = as.Date(min(d$Date)))
}))

# Table S4: procedural steps.
result <- baseline$`Self-administered Results`
known_results <- c("Normal independent completion", "Posture movements are not standard",
  "Drink water 500-700ml", "Drink water<500ml",
  "Posture movements are not standard, Drink water<500ml",
  "Posture movements are not standard, Drink water 500-700ml")
stopifnot(all(result %in% known_results))
water_low <- grepl("Drink water<500ml", result, fixed = TRUE)
water_mid <- grepl("Drink water 500-700ml", result, fixed = TRUE)
posture_bad <- grepl("Posture movements are not standard", result, fixed = TRUE)
step_rows <- function(step, categories, counts) data.frame(
  Step = step, Category = categories, N = counts, Denominator = n_fas,
  Percent = 100 * counts / n_fas)
other_steps <- c("Watching procedural guidance videos", "Completing gastric cleaning",
                 "Turning on the receiver", "Entering the capsule ID", "Turning on the capsule",
                 "Pairing the capsule with the receiver", "Swallowing the capsule")
procedural_records <- data.frame(ID=baseline$Id, `Self-administered Results`=result,
                                 check.names=FALSE)
for (step in other_steps) procedural_records[[step]] <- "Completed"
procedural_records$`Water intake` <- ifelse(water_low,"<500 mL",
  ifelse(water_mid,"500-<700 mL",">=700 mL"))
procedural_records$`Postural manoeuvres` <- ifelse(posture_bad,"Non-standard","As prescribed")
water_guidance <- read_sheet("1.procedural steps", "ID")
stopifnot(nrow(water_guidance) == n_fas, !anyDuplicated(water_guidance$ID),
          setequal(water_guidance$ID, baseline$Id))
response <- water_guidance$`Response to water guidance`[match(baseline$Id, water_guidance$ID)]
response_labels <- c("Completed" = "Completed as prompted",
                     "Completed as prompted" = "Completed as prompted",
                     "Not completed despite prompting" = "Not completed despite prompting",
                     "No prompt issued" = "No prompt issued")
stopifnot(!anyNA(response), all(response %in% names(response_labels)))
procedural_records$`Response to water guidance` <- unname(response_labels[response])
procedural_steps <- do.call(rbind, c(
  lapply(other_steps, function(step) step_rows(step, c("Success", "Fail"),
    c(sum(procedural_records[[step]] == "Completed"),sum(procedural_records[[step]] != "Completed")))),
  list(step_rows("Drinking sufficient water", c(">=700 mL", "500-<700 mL", "<500 mL"),
                 c(sum(!water_low & !water_mid), sum(water_mid), sum(water_low))),
       step_rows("Adherence to prescribed postural manoeuvres",
                 c("Completed as prescribed", "Completed with non-standard postural manoeuvres", "Not completed"),
                 c(sum(!posture_bad), sum(posture_bad), 0L)),
       step_rows("Response to water guidance",
                 c("Completed as prompted", "Not completed despite prompting", "No prompt issued"),
                 vapply(c("Completed as prompted", "Not completed despite prompting", "No prompt issued"),
                   function(x) sum(procedural_records$`Response to water guidance` == x), integer(1))))))
protocol_deviations <- data.frame(
  Type = c("Any protocol deviation", "Non-standard postural manoeuvres", "Inadequate water intake", "Both types"),
  N = c(sum(water_low | water_mid | posture_bad), sum(posture_bad),
        sum(water_low | water_mid), sum((water_low | water_mid) & posture_bad)),
  Denominator = n_fas)
protocol_deviations$Percent <- 100 * protocol_deviations$N / n_fas

# Table S5: landmark visualisation.
landmarks <- c("Cardia", "Fundus", "Body", "Angle", "Antrum", "Pylorus")
stopifnot(all(vapply(visualisation[landmarks], function(x) all(x %in% 0:1), logical(1))))
coverage <- do.call(rbind, lapply(landmarks, function(site)
  exact_rate(site, sum(visualisation[[site]] == 1), n_fas)))
coverage <- rbind(coverage, data.frame(
  Measure = "Overall gastric coverage", Numerator = sum(coverage$Numerator),
  Denominator = n_fas * length(landmarks),
  Percent = 100 * sum(coverage$Numerator) / (n_fas * length(landmarks)),
  CI_low = NA_real_, CI_high = NA_real_))

# Table S6: examination times.
examination_duration <- rbind(
  time_summary("Oesophagus", exam_time[[grep("^oesophagus", names(exam_time), value = TRUE)[1]]]),
  time_summary("Stomach", exam_time[[grep("^stomach", names(exam_time), value = TRUE)[1]]]),
  time_summary("Small intestine", exam_time[[grep("^small intestine", names(exam_time), value = TRUE)[1]]], TRUE))
stopifnot(identical(examination_duration$N, c(475L,475L,420L)))
ogd_column <- intersect(c("OGD examination time", "EGD examination time"), names(baseline))
if (length(ogd_column) != 1L) stop("Expected one OGD examination time column (OGD or EGD).")
ogd_time <- baseline[[ogd_column]]
ogd_interval <- as.numeric(difftime(ogd_time, baseline$`MCG examination time`, units = "mins"))
stopifnot(length(ogd_interval) == n_fas, all(is.finite(ogd_interval)), all(ogd_interval >= 0))
screening_date <- enrolled$Date[match(baseline$Id,enrolled_ids)]
chronology <- data.frame(ID=baseline$Id, Screening_date=as.Date(screening_date),
  MCG_date=as.Date(baseline$`MCG examination time`),
  OGD_date=as.Date(ogd_time))
chronology$MCG_before_screening <- chronology$MCG_date < chronology$Screening_date
chronology$Different_calendar_date <- chronology$MCG_date != chronology$Screening_date
ogd_interval_summary <- data.frame(
  Measure = "OGD minus MCG examination time", N = n_fas, Median = median(ogd_interval),
  Q1 = unname(quantile(ogd_interval, .25)), Q3 = unname(quantile(ogd_interval, .75)), Unit = "minutes")
reading_difference <- reading_time$`AI keyframe reading` - reading_time$`manual reading`
reading_difference <- data.frame(
  Comparison = "AI keyframe minus manual", N = length(reading_difference),
  Median = median(reading_difference), Q1 = unname(quantile(reading_difference, .25)),
  Q3 = unname(quantile(reading_difference, .75)), Unit = "minutes")

# Table S7: satisfaction.
mcg_comfort <- baseline[[grep("^Comfort Rating Of MCG", names(baseline), value = TRUE)[1]]]
ogd_comfort <- baseline[[grep("^Comfort Rating Of OGD", names(baseline), value = TRUE)[1]]]
convenience <- baseline[[grep("^Operational Convenience", names(baseline), value = TRUE)[1]]]
stopifnot(all(mcg_comfort %in% 1:3), all(ogd_comfort %in% 1:3), all(convenience %in% 1:3))
exact_paired_p <- function(wins, discordant)
  if (discordant == 0L) 1 else binom.test(wins, discordant)$p.value
rating_labels <- c(`1` = "Excellent", `2` = "Good", `3` = "Poor")
satisfaction_ratings <- rbind(
  count_rows("MCG comfort", factor(rating_labels[as.character(mcg_comfort)], levels = rating_labels), n_fas),
  count_rows("OGD comfort", factor(rating_labels[as.character(ogd_comfort)], levels = rating_labels), n_fas),
  count_rows("MCG operational convenience", factor(rating_labels[as.character(convenience)], levels = rating_labels), n_fas))
satisfaction_rates <- rbind(exact_rate("MCG comfort excellent or good", sum(mcg_comfort <= 2), n_fas),
                            exact_rate("OGD comfort excellent or good", sum(ogd_comfort <= 2), n_fas),
                            exact_rate("MCG convenience excellent or good", sum(convenience <= 2), n_fas))
ordinal_discordant <- mcg_comfort != ogd_comfort
binary_discordant <- (mcg_comfort <= 2) != (ogd_comfort <= 2)
satisfaction_tests <- data.frame(
  Test = c("Exact sign test for paired ordinal comfort", "Exact McNemar test for excellent-or-good comfort"),
  Favour_MCG = c(sum(mcg_comfort < ogd_comfort), sum(mcg_comfort <= 2 & ogd_comfort > 2)),
  Favour_OGD = c(sum(mcg_comfort > ogd_comfort), sum(mcg_comfort > 2 & ogd_comfort <= 2)),
  Ties_or_concordant = c(sum(!ordinal_discordant), sum(!binary_discordant)),
  P_value = c(exact_paired_p(sum(mcg_comfort < ogd_comfort), sum(ordinal_discordant)),
              exact_paired_p(sum(mcg_comfort <= 2 & ogd_comfort > 2), sum(binary_discordant))))

# Table S8: capsule excretion.
days <- baseline[[grep("Capsule Elimination Time", names(baseline), value = TRUE)[1]]]
stopifnot(all(is.finite(days)), all(days > 0))
not_observed <- grepl("not observed", baseline$note, ignore.case=TRUE)
excretion_levels <- c("Within 24 hours", "24-48 hours", "48-72 hours", ">72 hours",
                      "Excretion not observed but confirmed by abdominal radiography")
excretion_class <- ifelse(not_observed,excretion_levels[5],
  ifelse(days<=1,excretion_levels[1],ifelse(days<=2,excretion_levels[2],
    ifelse(days<=3,excretion_levels[3],excretion_levels[4]))))
stopifnot(identical(excretion_class,baseline$`Observed excretion time category`))
excretion_categories <- count_rows("Observed excretion time",
                                   factor(excretion_class, levels=excretion_levels),n_fas)
mean_ci <- mean(days) + c(-1,1)*qt(.975,n_fas-1)*sd(days)/sqrt(n_fas)
excretion_summary <- data.frame(
  Measure = c("Excretion within 72 hours", "Mean excretion time", "Mean CI low", "Mean CI high"),
  Numerator = c(sum(!not_observed & days<=3),NA,NA,NA),
  Denominator = c(n_fas,n_fas,n_fas,n_fas),
  Value = c(100*sum(!not_observed & days<=3)/n_fas,mean(days),mean_ci),
  Unit = c("percent","days","days","days"))

# Table S9: safety outcomes.
event_type <- trimws(events$`Event type`)
adverse <- events[event_type == "Adverse events", ]
event_names <- c("Delayed confirmation of capsule expulsion",
                 "Diarrhoea with delayed confirmation of capsule expulsion", "Abdominal bloating")
safety <- data.frame(
  Event = c("Any adverse event", event_names, "Serious adverse events", "Capsule retention",
            "Device failure: unexpected receiver shutdown", "Adverse events resolving within 24 hours"),
  N = c(nrow(adverse), sapply(event_names, function(x) sum(adverse$Indication == x)),
        sum(events$Severity == "Serious", na.rm = TRUE),
        sum(grepl("capsule retention", events$Indication, ignore.case = TRUE)),
        sum(event_type == "device failure"), sum(adverse$Duration == "<24h")),
  Denominator = n_sas)
safety$Percent <- 100 * safety$N / n_sas

negative_terms <- c("No lesion detected", "Superficial gastritis/chronic gastritis")
is_pos <- function(x) !is.na(x) & !(x %in% negative_terms)
lesions$Manual_Result[lesions$`Manual vs OGD` == "Consistent"] <-
  lesions$OGD_Result[lesions$`Manual vs OGD` == "Consistent"]
lesions$AI_keyframe_reading_Result[lesions$`OGD vs AI` == "Consistent"] <-
  lesions$OGD_Result[lesions$`OGD vs AI` == "Consistent"]
lesion_counts <- function(method, result, concordance) {
  reference_positive <- is_pos(lesions$OGD_Result)
  test_positive <- is_pos(lesions[[result]])
  discordant <- lesions[[concordance]] == "Inconsistent"
  missed <- table(lesions$OGD_Result[reference_positive & discordant])
  false_positive <- table(lesions[[result]][!reference_positive & test_positive])
  rbind(data.frame(Method = method, Status = "Missed OGD-positive lesion", Diagnosis = names(missed), N = as.integer(missed)),
        data.frame(Method = method, Status = "MCG-positive not confirmed by OGD",
                   Diagnosis = names(false_positive), N = as.integer(false_positive)))
}
lesion_descriptives <- rbind(lesion_counts("Manual", "Manual_Result", "Manual vs OGD"),
                             lesion_counts("AI keyframe", "AI_keyframe_reading_Result", "OGD vs AI"))

write_xlsx(list(
  Sample_size = sample_size, Study_flow = study_flow, Completion_rate = completion_rate,
  Table_1_age = baseline_age, Table_1_categories = baseline_categories, Table_S1_centres = centres,
  Table_S4_steps = procedural_steps, Derived_procedural_steps = procedural_records,
  Protocol_deviations = protocol_deviations,
  Table_S5_coverage = coverage, Table_S6_exam_time = examination_duration,
  OGD_interval = ogd_interval_summary, Reading_time_difference = reading_difference,
  Table_S7_ratings = satisfaction_ratings,
  Table_S7_rates = satisfaction_rates, Table_S7_tests = satisfaction_tests,
  Table_S8_categories = excretion_categories, Table_S8_summary = excretion_summary,
  Table_S9_safety = safety, Lesion_descriptives = lesion_descriptives,
  Chronology_checks = chronology),
  file.path(output, "non_diagnostic_results.xlsx"))
writeLines(capture.output(sessionInfo()), file.path(output, "sessionInfo.txt"))

cat("Non-diagnostic analyses completed:", n_fas, "FAS participants;", n_sas, "SAS participants.\n")
