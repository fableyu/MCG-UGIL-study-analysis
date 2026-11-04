# MCG: diagnostic performance against OGD.
# Usage: Rscript 01_primary_analysis.R input.xlsx [output_directory]

suppressPackageStartupMessages({
  library(readxl)
  library(dplyr)
  library(writexl)
})

script_path <- function() {
  arg <- commandArgs()[grepl("^--file=", commandArgs())]
  if (length(arg) != 1L) stop("Run this analysis with Rscript.")
  normalizePath(gsub("~+~", " ", sub("^--file=", "", arg), fixed=TRUE), mustWork=TRUE)
}

homece_init <- function() {
  args <- commandArgs(trailingOnly=TRUE)
  if (length(args) < 1L || length(args) > 2L)
    stop("Usage: Rscript <analysis.R> input.xlsx [output_directory]")
  raw <- normalizePath(args[1], mustWork=TRUE)
  output <- if (length(args) == 2L) args[2] else file.path(dirname(script_path()), "results")
  dir.create(output, recursive=TRUE, showWarnings=FALSE)
  output <- normalizePath(output, mustWork=TRUE)
  writeLines(capture.output(sessionInfo()), file.path(output, "sessionInfo.txt"))
  write.csv(data.frame(Input=basename(raw), MD5=unname(tools::md5sum(raw))),
            file.path(output, "input_checksum.csv"), row.names=FALSE)
  list(raw=raw, output=output)
}

read_workbook_sheet <- function(sheet, id_col="ID", pattern="^[0-9]{5}$") {
  sheets <- readxl::excel_sheets(rawdata_path)
  sheet_key <- function(x) trimws(sub("^[0-9]+[.]?[[:space:]]*", "", trimws(x)))
  matches <- sheets[sheet_key(sheets) == sheet_key(sheet)]
  if (length(matches) != 1L) stop("Missing or ambiguous worksheet: ", sheet)
  x <- readxl::read_excel(rawdata_path, sheet=matches, .name_repair="minimal")
  names(x) <- trimws(names(x))
  if (sheet_key(sheet) == "reading time")
    names(x) <- sub("^(manual reading|AI keyframe reading) [(]min[)]$", "\\1", names(x))
  if (sum(names(x) == id_col) != 1L) stop("Missing or duplicate ID column in sheet: ", sheet)
  x[[id_col]] <- trimws(as.character(x[[id_col]]))
  populated <- !is.na(x[[id_col]]) & nzchar(x[[id_col]])
  if (any(populated & !grepl(pattern, x[[id_col]]))) stop("Invalid ID in sheet: ", sheet)
  x <- x[populated, , drop=FALSE]
  x
}

read_homece <- function(sheet, id_col="ID") read_workbook_sheet(sheet, id_col)

kappa_multinomial <- function(tp, fn, fp, tn) {
  counts <- c(tp, fn, fp, tn); n <- sum(counts)
  stopifnot(n > 0, all(counts >= 0))
  p <- counts/n; ref <- c(1,1,0,0); test <- c(1,0,1,0)
  agree <- as.numeric(ref == test)
  po <- sum(p*agree); qr <- sum(p*ref); qt <- sum(p*test)
  pe <- qr*qt + (1-qr)*(1-qt)
  if (1-pe <= .Machine$double.eps)
    return(c(Estimate=NA_real_, CI_low=NA_real_, CI_high=NA_real_))
  k <- (po-pe)/(1-pe)
  gpe <- (2*qt-1)*ref + (2*qr-1)*test
  gradient <- agree/(1-pe) + (po-1)*gpe/(1-pe)^2
  centered_gradient <- gradient-sum(p*gradient)
  variance <- sum(p*centered_gradient^2)/n
  stopifnot(variance >= -1e-12)
  se <- sqrt(max(0, variance))
  c(Estimate=k, CI_low=max(-1,k-1.96*se), CI_high=min(1,k+1.96*se))
}

negative_terms <- c("No lesion detected", "Superficial gastritis/chronic gastritis")
is_pos <- function(x) !is.na(x) & !(x %in% negative_terms)

wilson <- function(x, n) {
  if (n == 0) return(c(NA_real_, NA_real_))
  z <- 1.96; p <- x / n; den <- 1 + z^2 / n
  ctr <- (p + z^2 / (2 * n)) / den
  mar <- z * sqrt(p * (1 - p) / n + z^2 / (4 * n^2)) / den
  c(max(0, ctr - mar), min(1, ctr + mar))
}

diagnostic_metrics <- function(ref, test, method, kappa_method = "wald") {
  stopifnot(length(ref)==length(test), length(ref)>0, all(ref %in% 0:1), all(test %in% 0:1))
  tp <- sum(ref == 1 & test == 1); fn <- sum(ref == 1 & test == 0)
  fp <- sum(ref == 0 & test == 1); tn <- sum(ref == 0 & test == 0); n <- tp + fn + fp + tn
  vals <- c(Sensitivity = tp / (tp + fn), Specificity = tn / (tn + fp), PPV = tp / (tp + fp),
            NPV = tn / (tn + fn), Accuracy = (tp + tn) / n)
  cis <- rbind(wilson(tp, tp + fn), wilson(tn, tn + fp), wilson(tp, tp + fp),
               wilson(tn, tn + fn), wilson(tp + tn, n))
  po <- vals[["Accuracy"]]
  pe <- ((tp + fn) * (tp + fp) + (tn + fp) * (tn + fn)) / n^2
  kap <- ifelse(pe < 1, (po - pe) / (1 - pe), NA_real_)
  kap_se <- ifelse(pe < 1, sqrt((po * (1 - po)) / (n * (1 - pe)^2)), NA_real_)
  kap_ci <- c(max(-1, kap - 1.96 * kap_se), min(1, kap + 1.96 * kap_se))
  if (kappa_method == "multinomial") {
    km <- kappa_multinomial(tp,fn,fp,tn)
    kap <- unname(km["Estimate"]); kap_ci <- unname(km[c("CI_low","CI_high")])
  } else stopifnot(kappa_method == "wald")
  list(
    contingency = tibble(Method = method, TP = tp, FN = fn, FP = fp, TN = tn, N = n),
    metrics = tibble(Method = method, Metric = c(names(vals), "Kappa"),
                     Estimate = c(unname(vals), kap),
                     CI_low = c(cis[, 1], kap_ci[1]), CI_high = c(cis[, 2], kap_ci[2]))
  )
}

classify_site <- function(txt) {
  if (grepl("Duoden", txt, ignore.case = TRUE)) return("Duodenum")
  if (grepl("Oesophag|Barrett|hiatal hernia", txt, ignore.case = TRUE)) return("Oesophagus")
  if (grepl("Gastric|gastritis", txt, ignore.case = TRUE)) return("Stomach")
  NA_character_
}
site_of <- function(e, m, a) {
  for (txt in c(e, m, a)) {
    s <- classify_site(txt)
    if (!is.na(s)) return(s)
  }
  "Other"
}

read_analysis_lesions <- function() {
  x <- read_homece("1.lesion record")
  required <- c("ID", "Lesion", "OGD_Result", "Manual_Result", "Manual vs OGD",
                "AI_keyframe_reading_Result", "OGD vs AI",
                "Binary classification in subgroup analysis")
  stopifnot(all(required %in% names(x)), nrow(x) == 798L,
            length(unique(x$ID)) == 475L, !anyNA(x[, setdiff(required, "Lesion")]),
            !anyDuplicated(paste(x$ID, x$Lesion, sep="/")),
            all(x$`Manual vs OGD` %in% c("Consistent", "Inconsistent")),
            all(x$`OGD vs AI` %in% c("Consistent", "Inconsistent")),
            !any(x$ID %in% c("10053", "07021", "09013", "10014", "08045", "09006", "01053")))
  x$Manual_Result[x$`Manual vs OGD` == "Consistent"] <-
    x$OGD_Result[x$`Manual vs OGD` == "Consistent"]
  x$AI_keyframe_reading_Result[x$`OGD vs AI` == "Consistent"] <-
    x$OGD_Result[x$`OGD vs AI` == "Consistent"]
  x
}

if (sys.nframe() == 0L) {
  config <- homece_init()
  rawdata_path <- config$raw

  root <- file.path(config$output, "primary")

  dir0 <- file.path(root, "input")
  dir1 <- file.path(root, "overall")
  dirs <- file.path(root, "organs")
  dir2 <- file.path(root, "individual_diseases")
  dir3 <- file.path(root, "lesions")
  dir4 <- file.path(root, "paired_input")
  for (p in c(dir0, dir1, dirs, dir2, dir3, dir4)) dir.create(p, recursive = TRUE, showWarnings = FALSE)

  dat <- read_analysis_lesions()

  write_xlsx(dat, file.path(dir0, "analysis_lesion_records.xlsx"))

  all_ids <- sort(unique(dat$ID))
  baseline <- read_homece("0baseline+satisfaction+followup", "Id")
  times <- read_homece("5.Examination time of MCG")
  stopifnot(nrow(baseline)==475L, !anyDuplicated(baseline$Id), setequal(baseline$Id,all_ids),
            nrow(times)==475L, !anyDuplicated(times$ID), setequal(times$ID,all_ids))
  time_col <- grep("^small intestine",names(times),value=TRUE,ignore.case=TRUE)
  stopifnot(length(time_col)==1L)
  small_intestine_time <- suppressWarnings(as.numeric(times[[time_col]]))
  entered_ids <- sort(times$ID[!is.na(small_intestine_time) & is.finite(small_intestine_time) & small_intestine_time>=0])
  excluded_ids <- setdiff(all_ids,entered_ids)
  stopifnot(length(entered_ids)==420L,length(excluded_ids)==55L)
  write_xlsx(list(Included=data.frame(ID=entered_ids),Excluded=data.frame(ID=excluded_ids)),file.path(root,"duodenal_population_audit.xlsx"))

  patient_binary <- function(x, ids) {
    stopifnot(!missing(ids), !anyDuplicated(ids), all(ids %in% all_ids))
    base <- tibble(ID = ids)
    agg <- x %>% group_by(ID) %>% summarise(
      OGD_Result         = as.integer(any(is_pos(OGD_Result))),
      Manual_Result      = as.integer(any(is_pos(Manual_Result))),
      AI_keyframe_reading_Result = as.integer(any(is_pos(AI_keyframe_reading_Result))), .groups = "drop")
    base %>% left_join(agg, by = "ID") %>% mutate(across(-ID, ~ coalesce(.x, 0L)))
  }

  write_patient_results <- function(pdat, cleaned_name, out_name, folder, kappa_method="wald") {
    write_xlsx(pdat, file.path(folder, cleaned_name))
    m <- diagnostic_metrics(pdat$OGD_Result, pdat$Manual_Result, "Manual", kappa_method)
    a <- diagnostic_metrics(pdat$OGD_Result, pdat$AI_keyframe_reading_Result, "AI keyframe reading", kappa_method)
    write_xlsx(list(Contingency = bind_rows(m$contingency, a$contingency),
                    Metrics = bind_rows(m$metrics, a$metrics)), file.path(folder, out_name))
  }

  pall <- patient_binary(dat, all_ids)
  write_xlsx(pall %>% select(ID, OGD_Result, Manual_Result), file.path(dir1, "per-patient_cleaned.xlsx"))
  write_xlsx(pall %>% select(ID, OGD_Result, AI_keyframe_reading_Result), file.path(dir1, "per-patient_cleaned_ai.xlsx"))
  m0 <- diagnostic_metrics(pall$OGD_Result, pall$Manual_Result, "Manual")
  a0 <- diagnostic_metrics(pall$OGD_Result, pall$AI_keyframe_reading_Result, "AI keyframe reading")
  write_xlsx(list(Contingency = m0$contingency, Metrics = m0$metrics), file.path(dir1, "per-patient accuracy.xlsx"))
  write_xlsx(list(Contingency = a0$contingency, Metrics = a0$metrics), file.path(dir1, "per-patient accuracy_ai.xlsx"))

  dat$Site <- mapply(site_of, dat$OGD_Result, dat$Manual_Result, dat$AI_keyframe_reading_Result)
  site_map <- c("Stomach" = "stomach", "Duodenum" = "duodenum", "Oesophagus" = "oesophagus")
  organ_contingencies <- list(); organ_metrics <- list()
  for (s in names(site_map)) {
    tag <- site_map[[s]]
    populations <- if (s == "Duodenum") list(FAS=all_ids, PPS=entered_ids) else list(FAS=all_ids)
    for (set_name in names(populations)) {
      analysis_ids <- populations[[set_name]]
      sub <- dat %>% filter(Site == s, ID %in% analysis_ids)
      pd <- patient_binary(sub, analysis_ids)
      if (s == "Duodenum") {
        failure <- pd$ID %in% excluded_ids
        pd$Manual_Result[failure] <- 0L
        pd$AI_keyframe_reading_Result[failure] <- 0L
        pd$Duodenal_entry_eligible <- pd$ID %in% entered_ids
      }
      km <- if (s == "Duodenum") "multinomial" else "wald"
      if (set_name == "FAS") {
        write_xlsx(sub,file.path(dirs,paste0("lesion_records_",tag,".xlsx")))
        write_patient_results(pd,paste0("per-patient_cleaned_",tag,".xlsx"),
                              paste0("per-patient accuracy_",tag,".xlsx"),dirs,km)
      }
      if (s == "Duodenum") {
        write_xlsx(sub,file.path(dirs,paste0("lesion_records_",tag,"_",set_name,".xlsx")))
        write_patient_results(pd,paste0("per-patient_cleaned_",tag,"_",set_name,".xlsx"),
                              paste0("per-patient accuracy_",tag,"_",set_name,".xlsx"),dirs,km)
        if (set_name == "FAS") duodenal_fas <- pd else duodenal_pps <- pd
      }
      for (method in c("Manual","AI keyframe reading")) {
        pred <- if (method=="Manual") pd$Manual_Result else pd$AI_keyframe_reading_Result
        res <- diagnostic_metrics(pd$OGD_Result,pred,method,km)
        key <- paste(s,set_name,method)
        organ_contingencies[[key]] <- mutate(res$contingency,Organ=s,Analysis_set=set_name)
        organ_metrics[[key]] <- mutate(res$metrics,Organ=s,Analysis_set=set_name)
      }
    }
  }
  nonentry <- duodenal_fas %>% filter(ID %in% excluded_ids)
  stopifnot(nrow(duodenal_fas)==475L,nrow(duodenal_pps)==420L,nrow(nonentry)==55L,
            sum(nonentry$OGD_Result)==6L,sum(nonentry$OGD_Result==0L)==49L,
            all(nonentry$Manual_Result==0L),all(nonentry$AI_keyframe_reading_Result==0L))
  nonentry_contingency <- bind_rows(
    diagnostic_metrics(nonentry$OGD_Result,nonentry$Manual_Result,"Manual","multinomial")$contingency,
    diagnostic_metrics(nonentry$OGD_Result,nonentry$AI_keyframe_reading_Result,"AI keyframe reading","multinomial")$contingency)
  write_xlsx(list(Contingency=bind_rows(organ_contingencies),Metrics=bind_rows(organ_metrics),
                  FAS_patient=duodenal_fas,PPS_patient=duodenal_pps,
                  Nonentry_patient=nonentry,Nonentry_contingency=nonentry_contingency,
                  Methods=data.frame(Item=c("Primary population","Secondary population","Non-entry handling","Proportion CI","Duodenal kappa CI","Input workbook","R version"),
                  Value=c("FAS: all 475 paired participants","PPS: FAS excluding the 55 without duodenal entry; n=420",
                          "Duodenal test=0 for non-entry; OGD-positive=FN, OGD-negative=TN",
                          "Wilson score 95% CI (z=1.96)","Four-cell multinomial delta-method asymptotic 95% CI",
                          basename(rawdata_path),as.character(getRversion())))),
             file.path(root,"duodenal_FAS_PPS_results.xlsx"))

  disease_input <- dat %>% mutate(Duodenal_entry_eligible = ID %in% entered_ids)
  write_xlsx(list(Records = disease_input,
                  Duodenal_included = data.frame(ID = entered_ids),
                  Duodenal_excluded = data.frame(ID = excluded_ids)),
             file.path(dir2, "analysis_input.xlsx"))
  write_xlsx(disease_input %>% filter(Site == "Duodenum", Duodenal_entry_eligible),
             file.path(dir2, "analysis_input_duodenal_420.xlsx"))
  write_xlsx(disease_input %>% filter(Site == "Duodenum"),
             file.path(dir2, "analysis_input_duodenal_FAS_475.xlsx"))
  diseases <- sort(setdiff(unique(c(dat$OGD_Result, dat$Manual_Result, dat$AI_keyframe_reading_Result)), "No lesion detected"))
  lesion_patient <- function(method_col, label, analysis_set="FAS", duodenal_only=FALSE) {
    stopifnot(analysis_set %in% c("FAS","PPS"))
    selected_diseases <- if (duodenal_only) diseases[vapply(diseases,function(dx) identical(classify_site(dx),"Duodenum"),logical(1))] else diseases
    bind_rows(lapply(selected_diseases, function(dx) {
      duodenal <- identical(classify_site(dx), "Duodenum")
      disease_ids <- if (duodenal && analysis_set=="PPS") entered_ids else all_ids
      r <- sapply(disease_ids, function(id) any(dat$ID == id & dat$OGD_Result == dx))
      t <- sapply(disease_ids, function(id) any(dat$ID == id & dat[[method_col]] == dx))
      if (duodenal) t[disease_ids %in% excluded_ids] <- FALSE
      res <- diagnostic_metrics(as.integer(r), as.integer(t), label,
                                if (duodenal) "multinomial" else "wald")
      z <- res$contingency; vals <- res$metrics
      ge <- function(mm) vals$Estimate[vals$Metric == mm]
      gl <- function(mm) vals$CI_low[vals$Metric == mm]
      gh <- function(mm) vals$CI_high[vals$Metric == mm]
      tibble(Lesion = dx, TP = z$TP, FN = z$FN, FP = z$FP, TN = z$TN, N = z$N,
             Sensitivity = ge("Sensitivity"), Sensitivity_CI_low = gl("Sensitivity"), Sensitivity_CI_high = gh("Sensitivity"),
             Specificity = ge("Specificity"), Specificity_CI_low = gl("Specificity"), Specificity_CI_high = gh("Specificity"),
             PPV = ge("PPV"), PPV_CI_low = gl("PPV"), PPV_CI_high = gh("PPV"),
             NPV = ge("NPV"), NPV_CI_low = gl("NPV"), NPV_CI_high = gh("NPV"),
             Accuracy = ge("Accuracy"), Accuracy_CI_low = gl("Accuracy"), Accuracy_CI_high = gh("Accuracy"),
             Kappa = ge("Kappa"), Kappa_CI_low = gl("Kappa"), Kappa_CI_high = gh("Kappa"))
    }))
  }
  lp_manual <- lesion_patient("Manual_Result", "Manual")
  lp_ai <- lesion_patient("AI_keyframe_reading_Result", "AI keyframe reading")
  lp_manual_pps <- lesion_patient("Manual_Result","Manual","PPS",TRUE)
  lp_ai_pps <- lesion_patient("AI_keyframe_reading_Result","AI keyframe reading","PPS",TRUE)
  write_xlsx(list(Manual=lp_manual,AI_keyframe=lp_ai,
                  Manual_duodenal_PPS=lp_manual_pps,AI_duodenal_PPS=lp_ai_pps),
             file.path(dir2,"per_patient_analysis_complete.xlsx"))

  per_lesion <- function(x, group) {
    calc <- function(method_col, cons_col, label) {
      rp <- is_pos(x$OGD_Result); called <- is_pos(x[[method_col]])
      agree <- x[[cons_col]] == "Consistent"
      tp <- sum(rp & agree); fn <- sum(rp & !agree); fp <- sum(!rp & called)
      ns <- tp + fn; np <- tp + fp
      sc <- if (ns) tp / ns else NA_real_; pr <- if (np) tp / np else NA_real_
      cs <- wilson(tp, ns); cp <- wilson(tp, np)
      tibble(Group = group, Method = label, TP = tp, FN = fn, FP = fp,
             OGD_positive = ns, Detected_positive = np,
             Sensitivity = sc, Sensitivity_CI_low = cs[1], Sensitivity_CI_high = cs[2],
             Miss_rate = if (ns) fn / ns else NA_real_,
             Precision = pr, Precision_CI_low = cp[1], Precision_CI_high = cp[2],
             F1 = if ((2 * tp + fn + fp) > 0) 2 * tp / (2 * tp + fn + fp) else NA_real_)
    }
    bind_rows(calc("Manual_Result", "Manual vs OGD", "Manual vs OGD"),
              calc("AI_keyframe_reading_Result", "OGD vs AI", "AI vs OGD"))
  }
  write_xlsx(dat, file.path(dir3, "cleaned_output_data.xlsx"))
  write_xlsx(list(Overall = per_lesion(dat, "Overall")), file.path(dir3, "per_lesion_analysis_results.xlsx"))
  region_map <- c("Stomach" = "gastro", "Duodenum" = "duo", "Oesophagus" = "ous")
  for (s in names(region_map)) {
    fn <- region_map[[s]]
    sub <- dat %>% filter(Site == s)
    write_xlsx(sub, file.path(dir3, paste0("2.input_", fn, ".xlsx")))
    write_xlsx(list(Overall = per_lesion(sub, s)), file.path(dir3, paste0("per_lesion_analysis_results_", fn, ".xlsx")))
  }

  mc <- pall %>% transmute(id=ID, ogd=OGD_Result, manual=Manual_Result,
                           ai=AI_keyframe_reading_Result)
  write_xlsx(mc, file.path(dir4, "paired_patient_results.xlsx"))
  write_xlsx(list(Overall_contingency=bind_rows(m0$contingency, a0$contingency),
                  Overall_metrics=bind_rows(m0$metrics, a0$metrics)),
             file.path(root, "overall_summary.xlsx"))
  cat("Primary analysis completed:", nrow(dat), "lesion records;",
      length(all_ids), "paired participants.\n")
}
