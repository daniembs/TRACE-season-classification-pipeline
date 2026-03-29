# =============================================================================
# config.R — Shared Pipeline Configuration
# =============================================================================
# Central configuration for the seasonal classification pipeline.
# Edit this file for your site and dataset. All stage scripts source it.
# =============================================================================

# =============================================================================
# 1. PATHS AND DATA
# =============================================================================

PROJECT_DIR <- tryCatch(
  normalizePath(dirname(sys.frame(1)$ofile), winslash = "/", mustWork = TRUE),
  error = function(e) normalizePath(".", winslash = "/", mustWork = TRUE)
)

DIR_STAGE_1 <- "output_STAGE_1"
DIR_STAGE_2 <- "output_STAGE_2"
DIR_STAGE_3 <- "output_STAGE_3"
DIR_STAGE_4 <- "output_STAGE_4"

# Set monthly climate csv name  (Year, Month, driver columns)
CLIMATE_CSV  <- file.path(PROJECT_DIR, "CLIM.csv")
# Set monthly ecological csv name (Year, Month, response columns)
RESPONSE_CSV <- file.path(PROJECT_DIR, "RESPONSE.csv")
# Set response variable in RESPONSE_CSV containing the monthly ecological response
RESPONSE_COL <- "response_variable"

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
# 4. STAGE 2 — Segmented Regression Parameters
# =============================================================================

# Set initial breakpoint guesses (should be rough but plausible).
# psi1 and psi2 are used for the k = 3 segmented fits.
SEG_DRIVERS <- data.frame(
  driver = c("DRIVER_1", "DRIVER_1", "DRIVER_1"),
  psi1   = c(0.0,      0.0,   0.0),
  psi2   = c(0.0,       0.0,   0.0),
  stringsAsFactors = FALSE)

MIN_MONTHS_FOR_SEG <- 45     # Minimum months for segmented regression
BOOT_B_SEG         <- 300    # Bootstrap iterations for breakpoint CI
MIN_DELTA_AIC      <- 2      # ΔAIC threshold: segmented > linear

# =============================================================================
# 5. STAGE 3 — Stress-Test Parameters
# =============================================================================

# Hard screens (candidates failing any of these are dropped)
S3_MIN_PCT_ASSIGNED   <- 0.90   # Ecological-window assignment completeness
S3_MIN_SEASON_PROP    <- 0.10   # Min proportion per season level
S3_MEAN_MONTH_CONS    <- 0.55   # Ecological-window calendar-month consistency
S3_MIN_BLOCK_PROP     <- 0.05   # Min season proportion within any block
S3_MIN_HEALTHY_BLOCKS <- 0.50   # Fraction of blocks retaining all k levels
S3_BLOCK_YEARS        <- 2      # Block length in years for stability test

# Informational flags (reported but never trigger a drop)
S3_FLAG_KAPPA_LOW  <- 0.10      # κ below "slight" agreement
S3_FLAG_ALIGN_IQR  <- 1.5       # Threshold–breakpoint distance in IQR units
S3_FLAG_OMEGA_SQ_LOW <- 0.01    # omega-squared below Cohen's "small" benchmark

# =============================================================================
# 6. STAGE 4 — Decision Ranking Parameters
# =============================================================================

# Tier weights (must sum to 1.0)
W_CLIMATE <- 0.50    # Tier 1: Climate structure
W_ROBUST  <- 0.30    # Tier 2: Internal robustness (std vs quantile)
W_VERIFY  <- 0.20    # Tier 3: External verification (Stage 1 vs Stage 2)

BOOT_N_RANK <- 300   # Year-block bootstrap replicates

# Number of sub-intervals for Davies' test for a breakpoint (segmented package).
# Higher values give a more precise p-value but increase compute time.
# Results can differ across values; record this alongside output for reproducibility.
DAVIES_K <- 10

# Proportion threshold above which a Stage 2 ecological candidate's dominant
# season class is flagged as near-constant (too imbalanced for meaningful
# label-agreement metrics). Applied in Stage 4 stage2_best_match.
S4_NEAR_CONSTANT_THRESHOLD <- 0.95

# Weight-sensitivity grid: bounds and step size for the tier-weight sweep in
# Stage 4.  The grid covers all (W_CLIMATE, W_ROBUST, W_VERIFY) combinations
# that sum to 1 and fall within these ranges.
SENS_W_CLIMATE_RANGE <- c(0.30, 0.70)
SENS_W_ROBUST_RANGE  <- c(0.10, 0.40)
SENS_W_VERIFY_RANGE  <- c(0.10, 0.40)   # applied as a filter, not a sweep axis
SENS_W_STEP          <- 0.10

# =============================================================================
# 7. GLOBAL SEED
# =============================================================================

GLOBAL_SEED <- 123

# =============================================================================
# DERIVED OBJECTS (do not edit below this line)
# =============================================================================

# Stage output directory resolver
stage_dir <- function(stage) {
  d <- switch(as.character(stage),
              "1" = DIR_STAGE_1, "2" = DIR_STAGE_2,
              "3" = DIR_STAGE_3, "4" = DIR_STAGE_4,
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
stopifnot(abs(W_CLIMATE + W_ROBUST + W_VERIFY - 1.0) < 1e-6)
# =============================================================================
