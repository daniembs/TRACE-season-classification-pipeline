# =============================================================================
# STAGE 2 — Season Factor Stress-Testing (Climate-Only Pipeline)
# =============================================================================
#   Stress-test Stage 1 climate candidates for temporal stability using
#   block-level diagnostics and calendar consistency. This stage eliminates
#   candidates with structural pathologies without requiring ecological data.
#
# Core principle:
#   Only structural criteria are used as drop rules. Multiple defensible
#   candidates are carried forward into Stage 3 (decision ranking).
#
# Inputs:
#   Stage 1 RDS: season_long.rds, screened_tbl.rds
#   Climate: CLIMATE_CSV
#
# Outputs (output_dir/tables/):
#   - block_stability.csv       Block-level stability tests
#   - filter_results.csv        All diagnostics + drop decisions
#   - retained_candidates.csv   Survivors for Stage 3
# =============================================================================

suppressPackageStartupMessages({
  library(tidyverse)
  library(lubridate)
})

source("config_climate_only.R")
set.seed(GLOBAL_SEED)

output_dir <- stage_dir(2)
tab_dir    <- file.path(output_dir, "tables")
dir.create(tab_dir, showWarnings = FALSE, recursive = TRUE)

# =============================================================================
# 1. LOAD DATA
# =============================================================================

season_long  <- readRDS(file.path(stage_dir(1), "season_long.rds"))
screened_tbl <- readRDS(file.path(stage_dir(1), "screened_tbl.rds"))

monthly_clim <- read.csv(CLIMATE_CSV, stringsAsFactors = FALSE) %>%
  mutate(Year      = as.integer(Year),
         Month     = as.integer(Month),
         DateMonth = as.Date(sprintf("%d-%02d-15", Year, Month)))

# =============================================================================
# 2. DEFINE VALIDATION WINDOW
# =============================================================================

if (!is.na(VALIDATION_START) && !is.na(VALIDATION_END)) {
  validation_months <- monthly_clim %>%
    filter(Year >= VALIDATION_START, Year <= VALIDATION_END) %>%
    distinct(DateMonth)
  message("Validation window: ", VALIDATION_START, "-", VALIDATION_END,
          " (", nrow(validation_months), " months)")
} else {
  validation_months <- monthly_clim %>% distinct(DateMonth)
  message("Validation window: full climate record (",
          nrow(validation_months), " months)")
}

stage1_long <- season_long %>%
  semi_join(validation_months, by = "DateMonth") %>%
  dplyr::select(candidate_id, driver, k, method, DateMonth, season)

valwin_overview <- stage1_long %>%
  group_by(candidate_id, driver, k, method) %>%
  summarise(
    n_months       = n(),
    n_assigned     = sum(!is.na(season)),
    pct_assigned_val = (n_assigned / n_months) * 100,
    n_levels_val   = n_distinct(season[!is.na(season)]),
    .groups = "drop")

# =============================================================================
# 3. HELPER FUNCTIONS
# =============================================================================

balance_metrics <- function(season_vec) {
  tab <- table(droplevels(season_vec))
  if (sum(tab) == 0)
    return(tibble(min_bin_prop = NA_real_, min_bin_n = 0L,
                  n_levels_used = 0L))
  tibble(min_bin_prop = min(as.numeric(tab) / sum(tab)),
         min_bin_n = as.integer(min(tab)),
         n_levels_used = length(tab))
}

month_consistency <- function(df, season_col = "season") {
  d <- df %>% filter(!is.na(.data[[season_col]]))
  if (nrow(d) == 0)
    return(tibble(mean_month_consistency = NA_real_,
                  min_month_consistency = NA_real_))
  mm <- d %>%
    count(Month, Year, .data[[season_col]], name = "n") %>%
    group_by(Month, Year) %>% slice_max(n, with_ties = FALSE) %>% ungroup() %>%
    count(Month, .data[[season_col]], name = "n") %>%
    group_by(Month) %>% mutate(prop = n / sum(n)) %>%
    summarise(max_prop = max(prop), .groups = "drop")
  tibble(mean_month_consistency = mean(mm$max_prop),
         min_month_consistency  = min(mm$max_prop))
}

make_year_blocks <- function(dates, block_years = 2) {
  yrs <- sort(unique(year(dates)))
  blocks <- list(); i <- 1
  while (i <= length(yrs)) {
    blocks[[length(blocks) + 1]] <- yrs[i:min(i + block_years - 1, length(yrs))]
    i <- i + block_years
  }
  blocks
}

# =============================================================================
# 4. STRESS TESTS — BLOCK STABILITY AND CALENDAR CONSISTENCY
# =============================================================================

year_blocks <- make_year_blocks(validation_months$DateMonth, block_years = S2_BLOCK_YEARS)

block_stability <- stage1_long %>%
  mutate(Year = year(DateMonth)) %>%
  group_by(candidate_id, driver, k, method) %>%
  group_modify(~{
    d <- .x
    map_dfr(year_blocks, function(yrs) {
      db  <- d %>% filter(Year %in% yrs)
      bal <- balance_metrics(db$season)
      tibble(test_years         = paste(range(yrs), collapse = "-"),
             n_block            = nrow(db),
             n_assigned_block   = sum(!is.na(db$season)),
             n_levels_block     = bal$n_levels_used,
             min_bin_prop_block = bal$min_bin_prop,
             min_bin_n_block    = bal$min_bin_n)
    })
  }) %>% ungroup()

calendar_consistency_val <- stage1_long %>%
  mutate(Month = month(DateMonth), Year = year(DateMonth)) %>%
  group_by(candidate_id, driver, k, method) %>%
  summarise(
    cal = list(month_consistency(tibble(Month = Month, Year = Year, season = season))),
    .groups = "drop") %>%
  unnest_wider(cal) %>%
  rename(mean_month_consistency_val = mean_month_consistency,
         min_month_consistency_val  = min_month_consistency)

# =============================================================================
# 5. CONSERVATIVE FILTERING
# =============================================================================

block_flags <- block_stability %>%
  group_by(candidate_id, driver, k, method) %>%
  summarise(
    n_blocks = n(),
    n_collapsed = sum(n_levels_block < k, na.rm = TRUE),
    prop_healthy = (n_blocks - n_collapsed) / n_blocks,
    min_block_min_bin_prop = {
      vals <- min_bin_prop_block[is.finite(min_bin_prop_block)]
      if (length(vals) == 0) NA_real_ else min(vals)
    },
    any_block_extreme_imbalance = any(
      is.finite(min_bin_prop_block) & min_bin_prop_block < S2_MIN_BLOCK_PROP,
      na.rm = TRUE),
    .groups = "drop") %>%
  mutate(fail_block_collapse = prop_healthy < S2_MIN_HEALTHY_BLOCKS)

val_balance <- stage1_long %>%
  group_by(candidate_id, driver, k, method) %>%
  summarise(bal = list(balance_metrics(season)), .groups = "drop") %>%
  unnest_wider(bal) %>%
  rename(min_bin_prop_val = min_bin_prop,
         min_bin_n_val = min_bin_n,
         n_levels_used_val = n_levels_used)

filters_tbl <- screened_tbl %>%
  dplyr::select(candidate_id, driver, k, method) %>%
  mutate(k = as.integer(k)) %>%
  left_join(valwin_overview,
            by = c("candidate_id", "driver", "k", "method")) %>%
  left_join(calendar_consistency_val,
            by = c("candidate_id", "driver", "k", "method")) %>%
  left_join(block_flags,
            by = c("candidate_id", "driver", "k", "method")) %>%
  left_join(val_balance %>%
              dplyr::select(candidate_id, driver, k, method,
                            min_bin_prop_val, min_bin_n_val,
                            n_levels_used_val),
            by = c("candidate_id", "driver", "k", "method")) %>%
  mutate(
    fail_assignment = is.finite(pct_assigned_val) &
      pct_assigned_val < S2_MIN_PCT_ASSIGNED,
    fail_imbalance  = is.finite(min_bin_prop_val) &
      min_bin_prop_val < S2_MIN_SEASON_PROP,
    fail_calendar   = is.finite(mean_month_consistency_val) &
      mean_month_consistency_val < S2_MEAN_MONTH_CONS,
    fail_block_imbalance = !is.na(any_block_extreme_imbalance) &
      any_block_extreme_imbalance,
    drop_candidate = fail_assignment | fail_imbalance | fail_calendar |
      (!is.na(fail_block_collapse) & fail_block_collapse) |
      fail_block_imbalance)

# =============================================================================
# 6. RETAINED CANDIDATES
# =============================================================================

retained <- filters_tbl %>%
  filter(!drop_candidate) %>%
  dplyr::select(
    candidate_id, driver, k, method,
    pct_assigned_val, n_levels_val, min_bin_prop_val,
    mean_month_consistency_val, min_month_consistency_val,
    prop_healthy, n_collapsed, min_block_min_bin_prop)

message("Stage 2: ", nrow(retained), " of ", nrow(filters_tbl),
        " candidates retained after structural stress-testing.")

# =============================================================================
# 7. SAVE OUTPUTS
# =============================================================================

write.csv(filters_tbl %>%
            dplyr::select(
              candidate_id, driver, n_seasons = k, method,
              pct_assigned_val, n_levels_val,
              min_bin_prop_val, min_bin_n_val,
              mean_month_consistency_val, min_month_consistency_val,
              prop_healthy, n_collapsed, min_block_min_bin_prop,
              fail_block_collapse, any_block_extreme_imbalance,
              fail_assignment, fail_imbalance, fail_calendar,
              fail_block_imbalance, drop_candidate),
          file.path(tab_dir, "filter_results.csv"), row.names = FALSE)

write.csv(retained %>%
            dplyr::select(
              candidate_id, driver, n_seasons = k, method,
              pct_assigned_val, n_levels_val, min_bin_prop_val,
              mean_month_consistency_val, min_month_consistency_val,
              prop_healthy, n_collapsed, min_block_min_bin_prop),
          file.path(tab_dir, "retained_candidates.csv"), row.names = FALSE)

write.csv(block_stability %>%
            dplyr::select(candidate_id, driver, n_seasons = k, method,
                          test_years, n_block, n_assigned_block,
                          n_levels_block, min_bin_prop_block, min_bin_n_block),
          file.path(tab_dir, "block_stability.csv"), row.names = FALSE)

saveRDS(retained, file.path(output_dir, "stage2_candidates_retained.rds"))
# =============================================================================
