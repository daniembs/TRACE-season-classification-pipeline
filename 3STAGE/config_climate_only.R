# =============================================================================
# config_climate_only.R — Pipeline Configuration (Climate-Only Version)
# =============================================================================
# Central configuration for the climate-only seasonal classification pipeline.
# This version does NOT require ecological response data; Stage 2 of the full
# pipeline (ecological segmentation) is omitted.
#
# Pipeline: Stage 1 (candidates) → Stage 2 (validation) → Stage 3 (ranking)
# Scripts are located in the 3STAGE/ subfolder.
#
# To use a different config file without editing scripts, set the environment
# variable SEASON_CONFIG before running any stage, e.g.:
#   Sys.setenv(SEASON_CONFIG = "3STAGE/config_climate_only.R")
#
# Structure:
#   SECTION 1 — SITE SETTINGS  (must be reviewed and edited for every new site)
#   SECTION 2 — METHOD SETTINGS (well-tested defaults; edit only with justification)
#   SECTION 3 — ADVANCED SETTINGS (internal thresholds; do not change lightly)
# =============================================================================

PROJECT_DIR <- tryCatch(
  normalizePath(dirname(sys.frame(1)$ofile), winslash = "/", mustWork = TRUE),
  error = function(e) normalizePath(".", winslash = "/", mustWork = TRUE))

DIR_STAGE_1 <- "output_STAGE_1_climate_only_candidates"
DIR_STAGE_2 <- "output_STAGE_2_climate_only_validation"
DIR_STAGE_3 <- "output_STAGE_3_climate_only_ranking"

# =============================================================================
# SECTION 1 — SITE SETTINGS
# Review and edit all items in this section before running the pipeline at a
# new site. Every item here is site-specific and has no universal default.
# =============================================================================

# ---- Input file -------------------------------------------------------------
# Monthly climate CSV: must contain Year, Month, and the driver columns below.
CLIMATE_CSV <- file.path(PROJECT_DIR, "CLIM.csv")

# ---- Climate driver metadata ------------------------------------------------
# One row per candidate driver. Controls polarity and season labelling
# throughout all stages.
#
# driver      : column name in CLIMATE_CSV (case-sensitive).
# high_is_dry : TRUE  if high values indicate drier conditions (e.g. CWD, VPD).
#               FALSE if high values indicate wetter conditions (e.g. rainfall).
# label_low/high/mid : season labels assigned to each value range.
#
# Add or remove rows to match your drivers. Names must match CLIMATE_CSV and
# STD_THRESHOLDS exactly.

DRIVER_META <- data.frame(
  driver      = c("DRIVER_1", "DRIVER_2", "DRIVER_3"),
  high_is_dry = c(TRUE,        FALSE,       TRUE),
  label_low   = c("Wet",       "Dry",       "Wet"),
  label_high  = c("Dry",       "Wet",       "Dry"),
  label_mid   = c("Transition", "Transition", "Transition"),
  stringsAsFactors = FALSE)

# ---- Baseline period --------------------------------------------------------
# Years used to compute climatological thresholds (quantile method).
# Choose a period long enough to be climatologically representative (>=20 yr).
BASELINE_START <- 1990
BASELINE_END   <- 2020

# ---- Standard thresholds ----------------------------------------------------
# Literature- or expert-based thresholds for each driver and season count.
# two$t    : single threshold separating k = 2 seasons.
# three$t1 : lower threshold (low/mid boundary) for k = 3.
# three$t2 : upper threshold (mid/high boundary) for k = 3.

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

# ---- Validation window (Stage 2) --------------------------------------------
# Optional: restrict structural stress tests to a sub-period (e.g. a holdout
# interval or study-period subset). Set both to NA to use the full record.
VALIDATION_START <- NA    # e.g., 2016
VALIDATION_END   <- NA    # e.g., 2024

# ---- Tier weights (Stage 3 ranking) ----------------------------------------
# Only two tiers in the climate-only version (no ecological verification tier).
# Must sum to exactly 1.0.
W_CLIMATE <- 0.60    # Tier 1: Climate structure
W_ROBUST  <- 0.40    # Tier 2: Internal robustness (std vs quantile agreement)

# =============================================================================
# SECTION 2 — METHOD SETTINGS
# =============================================================================

# ---- Quantile split points --------------------------------------------------
Q_SPLIT_2S <- 0.50          # Median split for k = 2
Q_SPLIT_3S <- c(1/3, 2/3)  # Tertile split for k = 3

# ---- Rank bootstrap ---------------------------------------------------------
BOOT_N_RANK <- 300   # Year-block bootstrap replicates for rank stability

# ---- Stage 1 screening thresholds ------------------------------------------
S1_MIN_PCT_ASSIGNED <- 90   # Min % of months assigned a non-NA season label
S1_MIN_BIN_N_2S     <- 24L  # Min months in the smallest bin (k = 2, ~2 yr)
S1_MIN_BIN_N_3S     <- 18L  # Min months in the smallest bin (k = 3, ~1.5 yr)

# =============================================================================
# SECTION 3 — ADVANCED SETTINGS
# =============================================================================

# ---- Stage 2 hard-screen thresholds ----------------------------------------
S2_MIN_PCT_ASSIGNED   <- 0.90  # Min assignment completeness in validation window
S2_MIN_SEASON_PROP    <- 0.10  # Min proportion for any single season level
S2_MEAN_MONTH_CONS    <- 0.55  # Min calendar-month consistency
S2_MIN_BLOCK_PROP     <- 0.05  # Min season proportion within any temporal block
S2_MIN_HEALTHY_BLOCKS <- 0.50  # Min fraction of blocks retaining all k levels
S2_BLOCK_YEARS        <- 2     # Block length (years) for temporal stability test

# ---- Weight sensitivity grid (Stage 3) -------------------------------------
# Sweeps all (W_CLIMATE, W_ROBUST) combinations that sum to 1 and lie within
# these ranges. Step size controls grid resolution.
SENS_W_CLIMATE_RANGE <- c(0.40, 0.80)
SENS_W_ROBUST_RANGE  <- c(0.20, 0.60)
SENS_W_STEP          <- 0.10

# ---- Global RNG seed --------------------------------------------------------
GLOBAL_SEED <- 123

# =============================================================================
# DERIVED OBJECTS (do not edit below this line)
# =============================================================================

# Resolve the absolute path for a given pipeline stage output directory.
stage_dir <- function(stage) {
  d <- switch(as.character(stage),
              "1" = DIR_STAGE_1,
              "2" = DIR_STAGE_2,
              "3" = DIR_STAGE_3,
              stop("Unknown stage: ", stage))
  file.path(PROJECT_DIR, d)
}

# Return driver metadata as a named list for a single driver name.
driver_info <- function(drv) {
  row <- DRIVER_META[DRIVER_META$driver == drv, ]
  if (nrow(row) == 0) stop("Driver '", drv, "' not found in DRIVER_META")
  as.list(row)
}

# Validate tier weights sum to 1.
stopifnot(abs(W_CLIMATE + W_ROBUST - 1.0) < 1e-6)
# =============================================================================
