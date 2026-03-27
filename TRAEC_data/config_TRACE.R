# =============================================================================
# config_TRACE.R — TRACE Pipeline Configuration
# =============================================================================
# Central configuration for the seasonal classification pipeline in the TRACE experimental site.
# =============================================================================

# =============================================================================
# 1. PATHS AND DATA
# =============================================================================

PROJECT_DIR <- tryCatch(
  normalizePath(dirname(sys.frame(1)$ofile), winslash = "/", mustWork = TRUE),
  error = function(e) normalizePath(".", winslash = "/", mustWork = TRUE))

DIR_STAGE_1 <- "output_STAGE_1"
DIR_STAGE_2 <- "output_STAGE_2"
DIR_STAGE_3 <- "output_STAGE_3"
DIR_STAGE_4 <- "output_STAGE_4"

# Monthly climate (Year, Month, driver columns)
CLIMATE_CSV  <- file.path(PROJECT_DIR, "CLIM_TRACE.csv")
# Monthly ecological data (Year, Month, response columns)
RESPONSE_CSV <- file.path(PROJECT_DIR, "RESPONSE_TRACE.csv")
# Column in RESPONSE_CSV containing the monthly ecological response
RESPONSE_COL <- "log_flux"

# =============================================================================
# 2. CLIMATE DRIVER METADATA
# =============================================================================
# One row per candidate driver. Controls polarity and season labeling
# throughout all stages.
#
#   driver      Column name in CLIMATE_CSV
#   high_is_dry TRUE  → high values = dry (e.g., CWD, VPD)
#               FALSE → high values = wet (e.g., SPEI, Rain)
#   label_low   Season label for low-value months
#   label_high  Season label for high-value months
#   label_mid   Season label for the middle bin (k = 3 only)

DRIVER_META <- data.frame(
  driver      = c("SPEI",        "CWD",        "Rain_roll"),
  high_is_dry = c(FALSE,         TRUE,          FALSE),
  label_low   = c("Dry",         "Wet",         "Dry"),
  label_high  = c("Wet",         "Dry",         "Wet"),
  label_mid   = c("Transition",  "Transition",  "Transition"),
  stringsAsFactors = FALSE
)

# =============================================================================
# 3. STAGE 1 — Season Candidate Parameters
# =============================================================================

# Baseline period for climatological thresholds.
BASELINE_START <- 1995
BASELINE_END   <- 2015

# Standard (literature-backed) thresholds: driver → k → cut-point(s)
STD_THRESHOLDS <- list(
  SPEI = list(
    two   = list(t = 0),                   # < 0 Dry, >= 0 Wet
    three = list(t1 = -1, t2 = 1)),        # < -1 Dry, [-1,1) Trans, >= 1 Wet
  CWD = list(
    two   = list(t = 0),                   # = 0 Wet, > 0 Dry
    three = list(t1 = 0, t2 = 20)),        # = 0 Wet, (0,20] Trans, > 20 Dry
  Rain_roll = list(
    two   = list(t = 300),                 # < 300 Dry, >= 300 Wet
    three = list(t1 = 180, t2 = 300))      # < 180 Dry, [180,300) Trans, >= 300 Wet
)

# Screening thresholds
S1_MIN_PCT_ASSIGNED <- 90   # Min fraction of months assigned a label
S1_MIN_BIN_N_2S     <- 24L    # Min months in smallest bin, k = 2 (~2 yr)
S1_MIN_BIN_N_3S     <- 18L    # Min months in smallest bin, k = 3 (~1.5 yr)

# =============================================================================
# 4. STAGE 2 — Segmented Regression Parameters
# =============================================================================

# Segmentation drivers with initial breakpoint guesses and axis labels.
# psi1/psi2: rough estimates of where the response changes slope.
SEG_DRIVERS <- data.frame(
  driver = c("Rain_roll",   "CWD", "SPEI"),
  psi1   = c(300,            10,            -1),
  psi2   = c(600,            30,             0),
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
