# MCG: paired comparison of AI-assisted and manual reading against OGD.
# Usage: Rscript 03_reading_mode_comparison.R input.xlsx [output_directory]
# Differences are AI minus manual. Proportion differences are on the 0-1 scale.

self <- sub("^--file=", "", commandArgs()[grepl("^--file=", commandArgs())][1])
self <- gsub("~+~", " ", self, fixed=TRUE)
source(file.path(dirname(normalizePath(self, mustWork=TRUE)), "01_primary_analysis.R"))
config <- homece_init()
rawdata_path <- config$raw

if (!requireNamespace("DTComPair", quietly=TRUE)) stop("Install the DTComPair package.")
output_dir <- file.path(config$output, "reading_mode_comparison")
dir.create(output_dir, recursive=TRUE, showWarnings=FALSE)
lesions <- read_analysis_lesions()
mc <- lesions %>% group_by(ID) %>%
  summarise(ogd=as.integer(any(is_pos(OGD_Result))),
            manual=as.integer(any(is_pos(Manual_Result))),
            ai=as.integer(any(is_pos(AI_keyframe_reading_Result))), .groups="drop") %>%
  rename(id=ID) %>% arrange(id)
stopifnot(nrow(mc) == 475L, !anyDuplicated(mc$id), !anyNA(mc))

# Paired Wald intervals; absolute non-inferiority margin: 5 percentage points.
# NI_p_value tests H0: AI - manual <= -0.05 (one-sided). NI uses the lower
# bound of the two-sided 95% interval, equivalent to a one-sided 2.5% rule.
paired_ni <- function(xa, xm, delta = .05) {
  b <- sum(xa == 1 & xm == 0); cc <- sum(xa == 0 & xm == 1); n <- length(xa)
  d <- (b - cc) / n; se <- sqrt((b + cc - (b - cc)^2 / n) / n^2)
  lo <- d - 1.96 * se; hi <- d + 1.96 * se
  tibble(Diff = d, CI_low = lo, CI_high = hi,
         NI_p = if (se == 0) ifelse(d + delta > 0, 0, 1) else 1 - pnorm((d + delta) / se),
         NI = lo > -delta)
}
# Predictive-value CIs resample participants jointly (2,000 samples, seed 1).
# Their two-sided P values use generalised score tests from DTComPair.
paired_pv <- function(kind, nboot = 2000, delta = .05) {
  set.seed(1)
  f <- if (kind == "PPV") function(t, z) if (any(t == 1)) mean(z[t == 1] == 1) else NA_real_
       else function(t, z) if (any(t == 0)) mean(z[t == 0] == 0) else NA_real_
  d <- f(mc$ai, mc$ogd) - f(mc$manual, mc$ogd); n <- nrow(mc)
  boot <- replicate(nboot, { i <- sample.int(n, n, TRUE); f(mc$ai[i], mc$ogd[i]) - f(mc$manual[i], mc$ogd[i]) })
  ci <- quantile(boot, c(.025, .975), na.rm = TRUE); se <- sd(boot, na.rm = TRUE)
  tibble(Diff = d, CI_low = ci[1], CI_high = ci[2], NI_p = if (se == 0) ifelse(d + delta > 0, 0, 1) else 1 - pnorm((d + delta) / se), NI = ci[1] > -delta)
}
manual_met <- diagnostic_metrics(mc$ogd, mc$manual, "Manual")$metrics
ai_met <- diagnostic_metrics(mc$ogd, mc$ai, "AI keyframe reading")$metrics
pos <- mc$ogd == 1; neg <- mc$ogd == 0
ni <- bind_rows(paired_ni(mc$ai[pos], mc$manual[pos]), paired_ni(1 - mc$ai[neg], 1 - mc$manual[neg]),
                paired_ni(as.integer(mc$ai == mc$ogd), as.integer(mc$manual == mc$ogd)),
                paired_pv("PPV"), paired_pv("NPV"))
dtc <- DTComPair::tab.paired(d = mc$ogd, y1 = mc$manual, y2 = mc$ai)
pv <- DTComPair::pv.gs(dtc)
# Exact two-sided McNemar tests use discordant pairs only.
mcnemar_exact_p <- function(y1, y2) {
  b <- sum(y1 == 1 & y2 == 0); c <- sum(y1 == 0 & y2 == 1)
  if (b + c == 0) return(1)
  binom.test(b, b + c, 0.5)$p.value
}
mp <- c(mcnemar_exact_p(mc$ai[pos], mc$manual[pos]),
        mcnemar_exact_p(1 - mc$ai[neg], 1 - mc$manual[neg]),
        mcnemar_exact_p(as.integer(mc$ai == mc$ogd), as.integer(mc$manual == mc$ogd)),
        as.numeric(pv$ppv["p.value"]), as.numeric(pv$npv["p.value"]))
metrics <- c("Sensitivity", "Specificity", "Accuracy", "PPV", "NPV")
summary <- tibble(Metric = metrics,
  Manual = sapply(metrics, function(z) manual_met$Estimate[manual_met$Metric == z]),
  AI_keyframe = sapply(metrics, function(z) ai_met$Estimate[ai_met$Metric == z]),
  Diff = ni$Diff, CI_low = ni$CI_low, CI_high = ni$CI_high,
  CI_95 = sprintf("(%.4f, %.4f)", ni$CI_low, ni$CI_high),
  NI_p_value = ni$NI_p, NI = ni$NI, P_value = mp,
  P_method = ifelse(metrics %in% c("PPV", "NPV"), "Generalised score test", "Exact McNemar test"))
cont <- bind_rows(diagnostic_metrics(mc$ogd, mc$manual, "Manual")$contingency,
                  diagnostic_metrics(mc$ogd, mc$ai, "AI keyframe reading")$contingency)

# Kappa differences account for dependence between both tests in each patient.
paired_kappa <- function(ref, manual, ai) {
  stopifnot(length(ref) == length(manual), length(ref) == length(ai),
            length(ref) > 1, all(ref %in% 0:1), all(manual %in% 0:1), all(ai %in% 0:1))
  cells <- expand.grid(ref=0:1, manual=0:1, ai=0:1)
  n <- length(ref)
  counts <- tabulate(1L + ref + 2L*manual + 4L*ai, nbins=8)
  p <- counts/n
  one <- function(test) {
    r <- cells$ref; t <- cells[[test]]
    agreement <- as.numeric(r == t)
    po <- sum(p*agreement); qr <- sum(p*r); qt <- sum(p*t)
    pe <- qr*qt + (1-qr)*(1-qt)
    if (1-pe <= .Machine$double.eps) stop('Kappa undefined: degenerate margins.')
    k <- (po-pe)/(1-pe)
    gpe <- (2*qt-1)*r + (2*qr-1)*t
    gradient <- agreement/(1-pe) + (po-1)*gpe/(1-pe)^2
    list(k=k, gradient=gradient)
  }
  m <- one('manual'); a <- one('ai')
  V <- (diag(p)-tcrossprod(p))/n
  g <- a$gradient-m$gradient
  se <- sqrt(drop(t(g)%*%V%*%g))
  delta <- a$k-m$k
  if (se == 0) stop('Zero variance: Wald comparison undefined.')
  lo <- delta-qnorm(.975)*se; hi <- delta+qnorm(.975)*se
  z <- delta/se; pv <- 2*pnorm(-abs(z))
  result <- data.frame(Metric='Kappa', N=n, Manual=m$k, AI_keyframe=a$k,
    Diff=delta, CI_low=lo, CI_high=hi, SE=se, Z=z, P_value=pv,
    Manual_AI_covariance=drop(t(m$gradient)%*%V%*%a$gradient),
    Unit='kappa units', P_method='Paired multinomial delta-method Wald test (two-sided)',
    Table_difference=sprintf('%.2f (%.2f to %.2f)',delta,lo,hi),
    Table_P=ifelse(pv<.001,'<0.001',sprintf('%.3f',pv)))
  list(result=result, joint_counts=cbind(cells,N=counts))
}

k <- paired_kappa(mc$ogd, mc$manual, mc$ai)
summary$Unit <- "proportion difference; multiply by 100 for percentage points"
krow <- summary[1,,drop=FALSE]
krow[1,] <- NA
for (nm in c("Metric", "Manual", "AI_keyframe", "Diff", "CI_low", "CI_high",
             "P_value", "P_method", "Unit")) krow[[nm]] <- k$result[[nm]]
krow$CI_95 <- sprintf("(%.4f, %.4f)", k$result$CI_low, k$result$CI_high)
summary <- bind_rows(summary, krow)

# Reading times are paired by participant, with no deletion of incomplete pairs.
reading <- read_homece("3.reading time", "id")
stopifnot(nrow(reading) == 475L, !anyDuplicated(reading$id),
          setequal(reading$id, mc$id),
          is.numeric(reading$`manual reading`), is.numeric(reading$`AI keyframe reading`),
          all(is.finite(reading$`manual reading`)),
          all(is.finite(reading$`AI keyframe reading`)),
          all(reading$`manual reading` >= 0), all(reading$`AI keyframe reading` >= 0))
reading_test <- wilcox.test(reading$`AI keyframe reading`, reading$`manual reading`,
                           paired=TRUE, exact=FALSE, correct=TRUE)
time_summary <- function(x, method) data.frame(Method=method, N=length(x),
  Median=median(x), Q1=unname(quantile(x,.25)), Q3=unname(quantile(x,.75)), Unit="minutes")
reading_summary <- bind_rows(time_summary(reading$`manual reading`, "Manual"),
                             time_summary(reading$`AI keyframe reading`, "AI keyframe reading"))
write_xlsx(list(Summary=summary, Contingency=cont, Paired_patient_results=mc,
                Kappa_comparison=k$result, Kappa_joint_counts=k$joint_counts,
                Reading_time_summary=reading_summary,
                Reading_time_test=data.frame(P_value=reading_test$p.value,
                  Method="Paired Wilcoxon signed-rank test; normal approximation with continuity correction")),
           file.path(output_dir, "AI_vs_manual_comparison.xlsx"))
cat("Reading-mode comparison completed: 475 paired participants.\n")
