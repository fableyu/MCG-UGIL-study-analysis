# HomeCe: clinically important lesions and indication subgroups (manual reading).
# Usage: Rscript 02_subgroup_analysis.R input.xlsx [output_directory]
# Group membership and clinical importance are read from the source workbook.

self <- sub("^--file=", "", commandArgs()[grepl("^--file=", commandArgs())][1])
self <- gsub("~+~", " ", self, fixed=TRUE)
source(file.path(dirname(normalizePath(self, mustWork=TRUE)), "01_primary_analysis.R"))
config <- homece_init()
rawdata_path <- config$raw

output_dir <- file.path(config$output, "subgroups")
dir.create(output_dir, recursive=TRUE, showWarnings=FALSE)
lesions <- read_analysis_lesions()
baseline <- read_homece("0baseline+satisfaction+followup", "Id")
stopifnot(nrow(baseline) == 475L, !anyDuplicated(baseline$Id),
          setequal(baseline$Id, lesions$ID), !anyNA(baseline$Indication))
baseline <- baseline %>% transmute(ID=Id, Indication=trimws(as.character(Indication)))
class_col <- "Binary classification in subgroup analysis"
manual_vs <- "Manual vs OGD"

symptom_labels <- c('Dyspepsia, bloating, vomiting or indigestion',
                    'Abdominal pain', 'Acid reflux symptoms',
                    'Hematemesis, melena, hematochezia or history of ulcers')
screening_label <- 'Health Screening'
surveillance_label <- 'Surveillance'
unknown_indications <- setdiff(unique(baseline$Indication), c(symptom_labels, screening_label, surveillance_label))
if (length(unknown_indications)) stop('Unmapped indication labels: ', paste(unknown_indications, collapse='; '))
baseline <- baseline |>
  mutate(Group = case_when(Indication == screening_label ~ 'Health screening',
                           Indication == surveillance_label ~ 'Surveillance',
                           TRUE ~ 'Symptom-labelled'))
stopifnot(setequal(unique(baseline$Group), c('Surveillance','Symptom-labelled','Health screening')))

any_patient <- lesions |>
  group_by(ID) |>
  summarise(OGD_Result = as.integer(any(is_pos(OGD_Result))),
            Manual_Result = as.integer(any(is_pos(Manual_Result))), .groups='drop') |>
  inner_join(baseline, by='ID')

category_map <- lesions |> distinct(OGD_Result, .data[[class_col]])
conflicts <- category_map |> count(OGD_Result) |> filter(n > 1L)
stopifnot(nrow(conflicts) == 0L)
lookup <- setNames(category_map[[class_col]], category_map$OGD_Result)
required_mapping <- c('Duodenal ulcer'='Clinically important UGIL',
                      'Duodenal subepithelial lesion'='Clinically important UGIL',
                      'Duodenal ulcer scar'='Others',
                      'Duodenal erosion'='Others',
                      'Erosive gastritis'='Others')
observed_mapping <- unname(lookup[names(required_mapping)])
if (anyNA(observed_mapping) || any(observed_mapping != unname(required_mapping)))
  stop('Clinically important lesion classification is inconsistent with the analysis definition')
classify <- function(x) {
  y <- unname(lookup[x])
  y[is.na(x) | x == 'No lesion detected'] <- NA_character_
  y
}
lesions$OGD_category <- classify(lesions$OGD_Result)
lesions$Manual_category <- classify(lesions$Manual_Result)
unmapped <- unique(c(lesions$OGD_Result[is.na(lesions$OGD_category) & lesions$OGD_Result != 'No lesion detected'],
                     lesions$Manual_Result[is.na(lesions$Manual_category) & lesions$Manual_Result != 'No lesion detected']))
stopifnot(length(na.omit(unmapped)) == 0L)
important_patient <- lesions |>
  group_by(ID) |>
  summarise(OGD_Result = as.integer(any(OGD_category == 'Clinically important UGIL', na.rm=TRUE)),
            Manual_Result = as.integer(any(Manual_category == 'Clinically important UGIL', na.rm=TRUE)),
            .groups='drop') |>
  inner_join(baseline, by='ID')
stopifnot(nrow(any_patient) == 475L, nrow(important_patient) == 475L,
          setequal(any_patient$ID, important_patient$ID))

metric <- function(group,name,num,den,kappa=FALSE,est=NA_real_,ci=c(NA_real_,NA_real_)) {
  if (!kappa) {est <- if (den > 0L) num/den else NA_real_; ci <- wilson(num,den)}
  display <- if (is.na(est)) 'Not estimable' else if (kappa && is.na(ci[1]))
    sprintf('%.2f (CI not estimated)',est) else if (kappa)
    sprintf('%.2f (%.2f to %.2f)',est,ci[1],ci[2]) else
    sprintf('%.1f%% (%.1f to %.1f)',100*est,100*ci[1],100*ci[2])
  data.frame(Group=group,Metric=name,Numerator=num,Denominator=den,
             Estimate=est,CI_low=ci[1],CI_high=ci[2],
             `Value (95% CI)`=display,check.names=FALSE)
}
calculate <- function(x,group) {
  tp <- sum(x$OGD_Result == 1L & x$Manual_Result == 1L)
  fn <- sum(x$OGD_Result == 1L & x$Manual_Result == 0L)
  fp <- sum(x$OGD_Result == 0L & x$Manual_Result == 1L)
  tn <- sum(x$OGD_Result == 0L & x$Manual_Result == 0L)
  n <- tp+fn+fp+tn;stopifnot(n > 0L)
  prevalence <- (tp+fn)/n
  cont <- data.frame(Group=group,TP=tp,FN=fn,FP=fp,TN=tn,N=n,
                     OGD_positive=tp+fn,OGD_prevalence=prevalence,Status='Calculated')
  po <- (tp+tn)/n
  pe <- ((tp+fn)*(tp+fp)+(tn+fp)*(tn+fn))/n^2
  two_class_margins <- tp+fn > 0L && tn+fp > 0L && tp+fp > 0L && tn+fn > 0L
  k <- if (two_class_margins && pe < 1) (po-pe)/(1-pe) else NA_real_
  se <- if (two_class_margins && pe < 1) sqrt(po*(1-po)/(n*(1-pe)^2)) else NA_real_
  # Suppress the Wald interval at perfect agreement, where it collapses to a point.
  kci <- if (is.na(k) || po == 1) c(NA_real_,NA_real_) else c(max(-1,k-1.96*se),min(1,k+1.96*se))
  metrics <- bind_rows(
    metric(group,'Sensitivity',tp,tp+fn),metric(group,'Specificity',tn,tn+fp),
    metric(group,'PPV',tp,tp+fp),metric(group,'NPV',tn,tn+fn),
    metric(group,'Accuracy',tp+tn,n),
    metric(group,"Cohen's kappa",NA_integer_,NA_integer_,TRUE,k,kci))
  list(cont=cont,metrics=metrics)
}
make_tables <- function(patient) {
  v <- calculate(filter(patient,Group=='Surveillance'),'Surveillance')
  s <- calculate(filter(patient,Group=='Symptom-labelled'),'Symptom-labelled')
  h <- calculate(filter(patient,Group=='Health screening'),'Health screening')
  o <- calculate(patient,'Overall QC')
  for (name in c('TP','FN','FP','TN'))
    stopifnot(v$cont[[name]]+s$cont[[name]]+h$cont[[name]] == o$cont[[name]])
  list(cont=bind_rows(v$cont,s$cont,h$cont,o$cont),
       metrics=bind_rows(v$metrics,s$metrics,h$metrics,o$metrics))
}
all_ugil <- make_tables(any_patient)
important <- make_tables(important_patient)
indication_audit <- baseline |> count(Indication,Group,name='Patients') |> arrange(desc(Patients))
run_audit <- data.frame(Item=c('Source workbook','Source MD5','Lesion rows','Paired patients',
  'Manual concordance column','Any-UGIL negative labels','Clinically-important classification conflicts',
  'Clinically-important unmapped diagnoses','Kappa interval rule','Surveillance patients','Symptom-labelled patients','Health-screening patients','R version'),
  Value=c(basename(rawdata_path),unname(tools::md5sum(rawdata_path)),nrow(lesions),nrow(any_patient),
          manual_vs,paste(negative_terms,collapse='; '),nrow(conflicts),length(na.omit(unmapped)),
          'Wald CI suppressed when agreement is perfect; kappa requires both classes in both margins',sum(baseline$Group=='Surveillance'),sum(baseline$Group=='Symptom-labelled'),sum(baseline$Group=='Health screening'),as.character(getRversion())),
  check.names=FALSE)

# The pooled clinically important analysis and its indication strata use the
# same diagnosis map and the same patient-level aggregation rule.
pooled <- calculate(important_patient, "Clinically important UGIL")
write_xlsx(list(Contingency=pooled$cont, Metrics=pooled$metrics,
                Patient_results=important_patient,
                Classification=category_map),
           file.path(output_dir, "clinically_important_UGIL.xlsx"))
write_xlsx(list(AnyUGIL_Contingency=all_ugil$cont, AnyUGIL_Metrics=all_ugil$metrics,
                Important_Contingency=important$cont, Important_Metrics=important$metrics,
                Indication_audit=indication_audit, Run_audit=run_audit),
           file.path(output_dir, "indication_subgroups.xlsx"))
cat("Subgroup analyses completed: 475 paired participants.\n")
