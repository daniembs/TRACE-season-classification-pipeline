# =============================================================================
# config_testdata.R — Test Data Configuration
# =============================================================================
# Central configuration for the seasonal classification pipeline.
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

CLIMATE_CSV  <- file.path(PROJECT_DIR, "test_data", "CLIM_test_alt_1990_2025.csv")
RESPONSE_CSV <- file.path(PROJECT_DIR, "test_data", "RESPONSE_test_alt_2019_2025.csv")
RESPONSE_COL <- "ndvi_mean"

# =============================================================================
# 2. CLIMATE DRIVER METADATA
# =============================================================================
# One row per candidate driver. Controls polarity and season labeling
# throughout all stages.
#
# Driver names
# Season limits (Dry or Wet, TRUE or FALSE):
# high_is_dry = TRUE  for variables that increase under drier conditions.
# high_is_dry = FALSE for variables that increase under wetter conditions.

DRIVER_META <- data.frame(
  driver      = c("VPD_kPa", "SPI_3", "RH_pct", "P3mo_mm"),
  high_is_dry = c(TRUE,      FALSE,   FALSE,    FALSE),
  label_low   = c("Wet",     "Dry",   "Dry",    "Dry"),
  label_high  = c("Dry",     "Wet",   "Wet",    "Wet"),
  label_mid   = c("Transition", "Transition", "Transition", "Transition"),
  stringsAsFactors = FALSE
)

# =============================================================================
# 3. STAGE 1 — Season Candidate Parameters
# =============================================================================

# Set Baseline period for climatological thresholds
BASELINE_START <- 1998
BASELINE_END   <- 2018

# Driver names and standard thresholds according to literature or prior local knowledge.
STD_THRESHOLDS <- list(
  VPD_kPa = list(
    two   = list(t = 1.05),
    three = list(t1 = 0.85, t2 = 1.55)),
  SPI_3 = list(
    two   = list(t = 0.00),
    three = list(t1 = -0.80, t2 = 0.80)),
  RH_pct = list(
    two   = list(t = 84.0),
    three = list(t1 = 78.0, t2 = 90.0)),
  P3mo_mm = list(
    two   = list(t = 420.0),
    three = list(t1 = 260.0, t2 = 560.0))
)

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
  driver = c("VPD_kPa", "SPI_3", "RH_pct", "P3mo_mm"),
  psi1   = c(1.00,      -0.50,   82.0,     360.0),
  psi2   = c(1.45,       0.40,   89.0,     520.0),
  stringsAsFactors = FALSE
)

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

DAVIES_K                    <- 10
S4_NEAR_CONSTANT_THRESHOLD  <- 0.95
SENS_W_CLIMATE_RANGE        <- c(0.30, 0.70)
SENS_W_ROBUST_RANGE         <- c(0.10, 0.40)
SENS_W_VERIFY_RANGE         <- c(0.10, 0.40)
SENS_W_STEP                 <- 0.10

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
