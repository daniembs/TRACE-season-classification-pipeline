# =============================================================================
# STAGE 3 — Decision Ranking and Bootstrap Stability (Climate-Only Pipeline)
# =============================================================================
#   Rank Stage 1 candidates retained by Stage 2 using a two-tier weighted
#   composite score, then assess rank stability via year-block bootstrap
#   and weight sensitivity analysis.
#
# Scoring tiers (weighted rank-aggregation):
#   Tier 1 — Climate structure (60%): month consistency, class balance,
#            entropy, switching rate. Full baseline record.
#   Tier 2 — Internal robustness (40%): std vs quantile threshold-method
#            agreement (BSA_min, normalized conditional entropy).
#
# Bootstrap design:
#   Year-block resampling (B iterations). Climate structure metrics are
#   fixed (properties of the full classification). Std/quantile agreement
#   is resampled across full-climate year blocks.
#
# Inputs:
#   Stage 1 RDS: screened_tbl.rds, season_long.rds
#   Stage 2 RDS: stage2_candidates_retained.rds
#
# Outputs (output_dir/tables/):
#   - decision_table_final.csv      Full decision table with bootstrap ranks
#   - bootstrap_rank_summary.csv    Rank stability summary
#   - weight_sensitivity.csv        Weight-sweep robustness check
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(purrr)
  library(lubridate)
})

source("config_climate_only.R")
set.seed(GLOBAL_SEED)

output_dir <- stage_dir(3)
tab_dir    <- file.path(output_dir, "tables")
dir.create(tab_dir, showWarnings = FALSE, recursive = TRUE)

# =============================================================================
# 1. LOAD DATA
# =============================================================================

screened_tbl <- readRDS(file.path(stage_dir(1), "screened_tbl.rds"))
season_long  <- readRDS(file.path(stage_dir(1), "season_long.rds"))
retained     <- readRDS(file.path(stage_dir(2), "stage2_candidates_retained.rds"))

# =============================================================================
# 2. APPLY STAGE 2 GATE
# =============================================================================

base_tbl <- screened_tbl %>%
  semi_join(retained %>% dplyr::select(candidate_id), by = "candidate_id") %>%
  mutate(k            = as.integer(k),
         candidate_id = as.character(candidate_id),
         driver       = as.character(driver),
         method       = as.character(method))

# =============================================================================
# 3. HELPER FUNCTIONS
# =============================================================================

kappa_safe <- function(tab) {
  tab <- as.matrix(tab)
  n <- sum(tab)
  if (!is.finite(n) || n <= 1) return(NA_real_)
  all_lvls <- union(rownames(tab), colnames(tab))
  sq <- matrix(0, length(all_lvls), length(all_lvls),
               dimnames = list(all_lvls, all_lvls))
  sq[rownames(tab), colnames(tab)] <- tab
  rs <- rowSums(sq); cs <- colSums(sq)
  if (sum(rs > 0) <= 1 || sum(cs > 0) <= 1) return(NA_real_)
  po <- sum(diag(sq)) / n
  pe <- sum(rs * cs) / n^2
  if (!is.finite(pe) || (1 - pe) <= 0) return(NA_real_)
  (po - pe) / (1 - pe)
}

wilson_ci <- function(m, n, z = 1.96) {
  if (!is.finite(n) || n <= 0) return(c(lo = NA_real_, hi = NA_real_))
  p <- m / n
  denom  <- 1 + z^2 / n
  center <- (p + z^2 / (2 * n)) / denom
  half   <- (z * sqrt((p * (1 - p) + z^2 / (4 * n)) / n)) / denom
  c(lo = center - half, hi = center + half)
}

label_agreement_bsa <- function(a, b, w = NULL) {
  ok <- !is.na(a) & !is.na(b)
  a <- as.character(a[ok]); b <- as.character(b[ok])
  if (!is.null(w)) w <- as.numeric(w[ok])
  if (length(a) <= 1)
    return(tibble(n = length(a), pct_agree = NA_real_, discord = NA_real_,
                  discord_ci_hi = NA_real_, bsa_min = NA_real_, kappa = NA_real_))
  tab <- if (is.null(w)) table(a, b)
         else xtabs(w ~ a + b, data = data.frame(a = a, b = b, w = w))
  n <- sum(tab); agree <- sum(diag(tab)); m <- n - agree
  ci <- wilson_ci(m, n)
  tibble(n = n, pct_agree = agree / n, discord = m / n,
         discord_ci_hi = ci["hi"], bsa_min = 1 - ci["hi"],
         kappa = kappa_safe(tab))
}

rank01 <- function(x, higher_better = TRUE) {
  if (!higher_better) x <- -x
  r <- rank(x, ties.method = "average", na.last = "keep")
  n_ok <- sum(!is.na(r))
  if (n_ok <= 1) return(rep(NA_real_, length(x)))
  (r - 1) / (n_ok - 1)
}

info_metrics_from_tab <- function(tab) {
  tab <- as.matrix(tab); n <- sum(tab)
  if (!is.finite(n) || n <= 1)
    return(tibble(MI = NA_real_, nH1_given_2 = NA_real_,
                  nH2_given_1 = NA_real_, H1_given_2 = NA_real_, H2_given_1 = NA_real_))
  Pij <- tab / n; Pi <- rowSums(Pij); Pj <- colSums(Pij)
  H <- function(p) { p <- p[p > 0]; -sum(p * log(p)) }
  Hi <- H(Pi); Hj <- H(Pj)
  MI <- 0
  for (i in seq_len(nrow(Pij)))
    for (j in seq_len(ncol(Pij)))
      if (Pij[i, j] > 0) MI <- MI + Pij[i, j] * log(Pij[i, j] / (Pi[i] * Pj[j]))
  H1g2 <- Hi - MI
  H2g1 <- Hj - MI
  tibble(MI            = MI,
         H1_given_2    = H1g2,
         H2_given_1    = H2g1,
         nH1_given_2   = if (Hi > 0) H1g2 / Hi else NA_real_,
         nH2_given_1   = if (Hj > 0) H2g1 / Hj else NA_real_)
}

safe_tier_mean <- function(...) {
  v <- mean(c(...), na.rm = TRUE)
  if (is.nan(v)) NA_real_ else v
}

weighted_score <- function(tiers, wts) {
  ok <- !is.na(tiers)
  if (sum(ok) == 0) return(NA_real_)
  sum(tiers[ok] * wts[ok]) / sum(wts[ok])
}

# =============================================================================
# 4. THRESHOLD-METHOD ROBUSTNESS (std vs quantile agreement)
# =============================================================================

std_quant_agreement <- function(sl) {
  wt_tbl <- if ("w" %in% names(sl)) {
    sl %>% distinct(DateMonth, w)
  } else {
    sl %>% distinct(DateMonth) %>% mutate(w = 1)
  }
  meta <- sl %>%
    distinct(candidate_id, driver, k, method) %>%
    filter(method %in% c("std", "quantile"))
  pairs <- meta %>%
    group_by(driver, k) %>%
    summarise(cid_std = candidate_id[method == "std"][1],
              cid_qtl = candidate_id[method == "quantile"][1],
              .groups = "drop") %>%
    filter(!is.na(cid_std), !is.na(cid_qtl))
  pairs %>%
    mutate(metrics = map2(cid_std, cid_qtl, function(c1, c2) {
      s1 <- sl %>%
        filter(candidate_id == c1) %>%
        dplyr::select(DateMonth, s_std = season)
      s2 <- sl %>%
        filter(candidate_id == c2) %>%
        dplyr::select(DateMonth, s_qtl = season)
      joined <- inner_join(s1, s2, by = "DateMonth") %>%
        left_join(wt_tbl, by = "DateMonth")
      met <- label_agreement_bsa(joined$s_std, joined$s_qtl, w = joined$w)
      lv <- union(levels(factor(joined$s_std)), levels(factor(joined$s_qtl)))
      tab <- xtabs(w ~ factor(s_std, levels = lv) + factor(s_qtl, levels = lv),
                   data = joined)
      info <- info_metrics_from_tab(tab)
      tibble(stage1_n = sum(joined$w, na.rm = TRUE),
             kappa_std_quant = met$kappa,
             bsa_min_std_quant = met$bsa_min,
             pct_agree_std_quant = met$pct_agree,
             discord_ci_hi_std_quant = met$discord_ci_hi,
             nce_std_quant = mean(c(info$nH1_given_2, info$nH2_given_1), na.rm = TRUE))
    })) %>%
    unnest(metrics)
}

sq_tbl <- std_quant_agreement(season_long)

# =============================================================================
# 5. ASSEMBLE DECISION SET AND COMPUTE SCORE
# =============================================================================

decision_set <- base_tbl %>%
  left_join(sq_tbl, by = c("driver", "k"))

decision_set <- decision_set %>%
  mutate(
    u_mean_month = rank01(mean_month_consistency, TRUE),
    u_min_month  = rank01(min_month_consistency,  TRUE),
    u_min_bin    = rank01(min_bin_prop,           TRUE),
    u_switch     = rank01(mean_switch_per_year,   FALSE),
    u_sq_bsa     = rank01(bsa_min_std_quant,      TRUE),
    u_sq_ce      = rank01(nce_std_quant,          FALSE)) %>%
  rowwise() %>%
  mutate(
    tier_climate = safe_tier_mean(u_mean_month, u_min_month, u_min_bin, u_switch),
    tier_robust  = safe_tier_mean(u_sq_bsa, u_sq_ce),
    climate_score = weighted_score(
      c(tier_climate, tier_robust),
      c(W_CLIMATE, W_ROBUST)),
    score_n_components = sum(!is.na(c(
      u_mean_month, u_min_month, u_min_bin, u_switch,
      u_sq_bsa, u_sq_ce)))) %>%
  ungroup()

# =============================================================================
# 6. DECISION TABLE OUTPUT
# =============================================================================

decision_table <- decision_set %>%
  arrange(desc(climate_score), desc(bsa_min_std_quant)) %>%
  dplyr::select(
    candidate_id, driver, k, method,
    climate_score, score_n_components,
    mean_month_consistency, min_month_consistency,
    min_bin_prop, entropy_norm, mean_switch_per_year,
    stage1_n, bsa_min_std_quant,
    kappa_std_quant, nce_std_quant)

# =============================================================================
# 7. BOOTSTRAP RANK STABILITY
# =============================================================================

years_full <- sort(unique(year(season_long$DateMonth)))

boot_months <- function(src_tbl, years_vec) {
  yrs <- sample(years_vec, length(years_vec), replace = TRUE)
  map2_dfr(yrs, seq_along(yrs), ~{
    src_tbl %>%
      mutate(Year = year(DateMonth)) %>%
      filter(Year == .x) %>%
      mutate(.boot_block = .y)
  })
}

boot_once <- function() {
  months_full_b <- boot_months(season_long, years_full)
  full_w <- months_full_b %>% count(DateMonth, name = "w")
  sq_b <- std_quant_agreement(
    season_long %>% semi_join(full_w, by = "DateMonth") %>%
      left_join(full_w, by = "DateMonth"))
  decision_set %>%
    dplyr::select(candidate_id, driver, k,
                  mean_month_consistency, min_month_consistency,
                  min_bin_prop, mean_switch_per_year) %>%
    left_join(sq_b, by = c("driver", "k")) %>%
    mutate(
      u_mean_month = rank01(mean_month_consistency, TRUE),
      u_min_month  = rank01(min_month_consistency,  TRUE),
      u_min_bin    = rank01(min_bin_prop,           TRUE),
      u_switch     = rank01(mean_switch_per_year,   FALSE),
      u_sq_bsa     = rank01(bsa_min_std_quant,      TRUE),
      u_sq_ce      = rank01(nce_std_quant,          FALSE)) %>%
    rowwise() %>%
    mutate(
      tier_climate = safe_tier_mean(u_mean_month, u_min_month, u_min_bin, u_switch),
      tier_robust  = safe_tier_mean(u_sq_bsa, u_sq_ce),
      climate_score = weighted_score(
        c(tier_climate, tier_robust),
        c(W_CLIMATE, W_ROBUST))) %>%
    ungroup() %>%
    arrange(desc(climate_score)) %>%
    mutate(rank = row_number()) %>%
    dplyr::select(candidate_id, rank)
}

boot_ranks <- map_dfr(seq_len(BOOT_N_RANK), ~boot_once() %>% mutate(iter = .x))

rank_stats <- boot_ranks %>%
  group_by(candidate_id) %>%
  summarise(p_top1 = mean(rank == 1), rank_IQR = IQR(rank),
            .groups = "drop") %>%
  arrange(desc(p_top1))

top_probs <- boot_ranks %>%
  filter(rank == 1) %>% count(candidate_id) %>% mutate(prob = n / BOOT_N_RANK)

boot_summary <- tibble(
  N_BOOT               = BOOT_N_RANK,
  top_candidate        = top_probs$candidate_id[1],
  top_probability      = top_probs$prob[1],
  runnerup_probability = if (nrow(top_probs) >= 2) top_probs$prob[2] else NA_real_,
  decision_entropy     = -sum(top_probs$prob * log(top_probs$prob)))

decision_table_final <- decision_table %>%
  left_join(rank_stats, by = "candidate_id") %>%
  arrange(desc(p_top1), desc(climate_score))

# =============================================================================
# 8. WEIGHT SENSITIVITY ANALYSIS
# =============================================================================

weight_grid <- tibble(w_clim = seq(0.30, 0.70, by = 0.10)) %>%
  mutate(w_rob = 1 - w_clim)

weight_sensitivity <- weight_grid %>%
  pmap_dfr(function(w_clim, w_rob) {
    scored <- decision_set %>%
      rowwise() %>%
      mutate(cs = weighted_score(
        c(tier_climate, tier_robust),
        c(w_clim, w_rob))) %>%
      ungroup() %>% arrange(desc(cs))
    tibble(top_candidate = scored$candidate_id[1],
           top_score     = scored$cs[1],
           w_climate     = w_clim,
           w_robust      = w_rob,
           gap_to_second = scored$cs[1] - scored$cs[2])
  })

message("Stage 3 complete. Winner: ", boot_summary$top_candidate,
        " (P(rank 1) = ", round(boot_summary$top_probability, 3), ").",
        " Weight sensitivity: ", n_distinct(weight_sensitivity$top_candidate),
        " unique winner(s) across ", nrow(weight_grid), " weight combos.")

# =============================================================================
# 9. SAVE OUTPUTS
# =============================================================================

write.csv(decision_table_final %>%
            dplyr::select(
              candidate_id, driver, n_seasons = k, method,
              climate_score, p_top1, rank_IQR, score_n_components,
              mean_month_consistency, min_month_consistency,
              min_bin_prop, mean_switch_per_year, entropy_norm,
              stage1_n, bsa_min_std_quant, nce_std_quant, kappa_std_quant),
          file.path(tab_dir, "decision_table_final.csv"), row.names = FALSE)

write.csv(weight_sensitivity %>%
            dplyr::select(w_climate, w_robust,
                          top_candidate, top_score, gap_to_second),
          file.path(tab_dir, "weight_sensitivity.csv"), row.names = FALSE)

write.csv(boot_summary,
          file.path(tab_dir, "bootstrap_rank_summary.csv"), row.names = FALSE)

saveRDS(decision_set, file.path(output_dir, "decision_set.rds"))
saveRDS(boot_ranks,   file.path(output_dir, "boot_ranks.rds"))
# =============================================================================
