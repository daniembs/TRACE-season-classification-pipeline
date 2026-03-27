# =============================================================================
# config_climate_only.R — Pipeline Configuration (Climate-Only Version)
# =============================================================================
# Central configuration for the climate-only seasonal classification pipeline.
# This version does NOT require ecological response data or segmented
# regression (Stage 2 of the full pipeline is omitted).
#
# Pipeline: Stage 1 (candidates) → Stage 2 (validation) → Stage 3 (ranking)
#
# Usage: source("config_climate_only.R")
# =============================================================================

# =============================================================================
# 1. PATHS AND DATA
# =============================================================================

PROJECT_DIR <- tryCatch(
  normalizePath(dirname(sys.frame(1)$ofile), winslash = "/", mustWork = TRUE),
  error = function(e) normalizePath(".", winslash = "/", mustWork = TRUE))

DIR_STAGE_1 <- "output_STAGE_1_climate_only_candidates"
DIR_STAGE_2 <- "output_STAGE_2_climate_only_validation"
DIR_STAGE_3 <- "output_STAGE_3_climate_only_ranking"

# Set monthly climate csv name  (Year, Month, driver columns)
CLIMATE_CSV <- file.path(PROJECT_DIR, "CLIM.csv")

# =============================================================================
# 2. CLIMATE DRIVER METADATA
# =============================================================================
# One row per candidate driver. Controls polarity and season labelling
# throughout all stages (adjust/add/remove drivers as necessary).
#
# Set driver names (must match the climate CSV exactly).
# Set season limits (Dry or Wet, TRUE or FALSE):
# high_is_dry = TRUE  for variables that increase under drier conditions.
# high_is_dry = FALSE for variables that increase under wetter conditions.

DRIVER_META <- data.frame(
  driver      = c("DRIVER_1", "DRIVER_2", "DRIVER_3"),
  high_is_dry = c(TRUE/FALSE,      TRUE/FALSE,   TRUE/FALSE,    TRUE/FALSE),
  label_low   = c("Dry/Wet",     "Dry/Wet",   "Dry/Wet"),
  label_high  = c("Dry/Wet",     "Dry/Wet",   "Dry/Wet"),
  label_mid   = c("Transition", "Transition", "Transition"),
  stringsAsFactors = FALSE)

# =============================================================================
# 3. STAGE 1 — Season Candidate Parameters
# =============================================================================

# Set Baseline period for climatological thresholds (adjust as necessary for your dataset)
BASELINE_START <- 0000
BASELINE_END   <- 0000

# Set driver names and standard thresholds according to literature or prior local knowledge.
STD_THRESHOLDS <- list(
  DRIVER_1 = list(
    two   = list(t = 0.0),
    three = list(t1 = 0.0, t2 = 0.0)),
  DRIVER_2 = list(
    two   = list(t = 0.0),
    three = list(t1 = 0.0, t2 = 0.0)),
  DRIVER_3 = list(
    two   = list(t = 0.0),
    three = list(t1 = 0.0, t2 = 0.0)))

# Screening thresholds
S1_MIN_PCT_ASSIGNED <- 90   # Min fraction of months assigned a label
S1_MIN_BIN_N_2S     <- 24L    # Min months in smallest bin, k = 2 (~2 yr)
S1_MIN_BIN_N_3S     <- 18L    # Min months in smallest bin, k = 3 (~1.5 yr)

# =============================================================================
# 4. STAGE 2 — Stress-Test Parameters
# =============================================================================
# Optional validation window. If both are NA, the full climate record is used.
# Otherwise, restrict structural stress tests to this period (e.g., a holdout
# interval or a study-period subset).

VALIDATION_START <- NA    # e.g., 2016
VALIDATION_END   <- NA    # e.g., 2024

# Hard screens (climate-only analogue of full-pipeline Stage 3 structural filters)
S2_MIN_PCT_ASSIGNED   <- 0.90    # Min assignment completeness within validation window
S2_MIN_SEASON_PROP    <- 0.10  # Min proportion per season level within validation window
S2_MEAN_MONTH_CONS    <- 0.55  # Min calendar-month consistency within validation window
S2_MIN_BLOCK_PROP     <- 0.05  # Min season proportion within any block
S2_MIN_HEALTHY_BLOCKS <- 0.50  # Fraction of blocks retaining all k levels
S2_BLOCK_YEARS        <- 2     # Block length in years for stability test

# =============================================================================
# 5. STAGE 3 — Decision Ranking Parameters
# =============================================================================

# Tier weights (must sum to 1.0)
W_CLIMATE <- 0.60    # Tier 1: Climate structure
W_ROBUST  <- 0.40    # Tier 2: Internal robustness (std vs quantile)

BOOT_N_RANK <- 300   # Year-block bootstrap replicates

# =============================================================================
# 6. GLOBAL SEED
# =============================================================================

GLOBAL_SEED <- 123

# =============================================================================
# DERIVED OBJECTS (do not edit below this line)
# =============================================================================

# Stage output directory resolver
stage_dir <- function(stage) {
  d <- switch(as.character(stage),
              "1" = DIR_STAGE_1,
              "2" = DIR_STAGE_2,
              "3" = DIR_STAGE_3,
              stop("Unknown stage: ", stage))
  file.path(PROJECT_DIR, d)
}

# Driver metadata lookup (returns named list for one driver)
driver_info <- function(drv) {
  row <- DRIVER_META[DRIVER_META$driver == drv, ]
  if (nrow(row) == 0) stop("Driver '", drv, "' not found in DRIVER_META")
  as.list(row)
}

# Validate tier weights
stopifnot(abs(W_CLIMATE + W_ROBUST - 1.0) < 1e-6)
# =============================================================================
