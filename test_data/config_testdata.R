# =============================================================================
# config_testdata.R — Pipeline Configuration for Synthetic Test Data
# =============================================================================
# Configuration for running the full 4-stage pipeline on the synthetic test
# dataset provided in test_data/.
#
# To use this config, set the environment variable before running any stage:
#   Sys.setenv(SEASON_CONFIG = "test_data/config_testdata.R")
# =============================================================================

PROJECT_DIR <- tryCatch(
  normalizePath(dirname(sys.frame(1)$ofile), winslash = "/", mustWork = TRUE),
  error = function(e) normalizePath(".", winslash = "/", mustWork = TRUE))

DIR_STAGE_1 <- "output_STAGE_1"
DIR_STAGE_2 <- "output_STAGE_2"
DIR_STAGE_3 <- "output_STAGE_3"
DIR_STAGE_4 <- "output_STAGE_4"

# =============================================================================
# SECTION 1 — SITE SETTINGS
# =============================================================================

CLIMATE_CSV  <- file.path(PROJECT_DIR, "test_data", "CLIM_test_alt_1990_2025.csv")
RESPONSE_CSV <- file.path(PROJECT_DIR, "test_data", "RESPONSE_test_alt_2019_2025.csv")
RESPONSE_COL <- "ndvi_mean"

DRIVER_META <- data.frame(
  driver      = c("VPD_kPa", "SPI_3", "RH_pct", "P3mo_mm"),
  high_is_dry = c(TRUE,      FALSE,   FALSE,     FALSE),
  label_low   = c("Wet",     "Dry",   "Dry",     "Dry"),
  label_high  = c("Dry",     "Wet",   "Wet",     "Wet"),
  label_mid   = c("Transition", "Transition", "Transition", "Transition"),
  stringsAsFactors = FALSE)

BASELINE_START <- 1998
BASELINE_END   <- 2018

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
    three = list(t1 = 260.0, t2 = 560.0)))

SEG_DRIVERS <- data.frame(
  driver = c("VPD_kPa", "SPI_3", "RH_pct", "P3mo_mm"),
  psi1   = c(1.00,      -0.50,   82.0,     360.0),
  psi2   = c(1.45,       0.40,   89.0,     520.0),
  stringsAsFactors = FALSE)

W_CLIMATE <- 0.50
W_ROBUST  <- 0.30
W_VERIFY  <- 0.20

# =============================================================================
# SECTION 2 — METHOD SETTINGS
# =============================================================================

Q_SPLIT_2S   <- 0.50
Q_SPLIT_3S   <- c(1/3, 2/3)
DAVIES_ALPHA <- 0.05

MIN_MONTHS_FOR_SEG <- 45
BOOT_B_SEG         <- 300
MIN_DELTA_AIC      <- 2
BOOT_N_RANK        <- 300

S1_MIN_PCT_ASSIGNED <- 90
S1_MIN_BIN_N_2S     <- 24L
S1_MIN_BIN_N_3S     <- 18L

# =============================================================================
# SECTION 3 — ADVANCED SETTINGS
# =============================================================================

DAVIES_K <- 10

S3_MIN_PCT_ASSIGNED   <- 0.90
S3_MIN_SEASON_PROP    <- 0.10
S3_MEAN_MONTH_CONS    <- 0.55
S3_MIN_BLOCK_PROP     <- 0.05
S3_MIN_HEALTHY_BLOCKS <- 0.50
S3_BLOCK_YEARS        <- 2

S3_FLAG_KAPPA_LOW    <- 0.10
S3_FLAG_ALIGN_IQR    <- 1.5
S3_FLAG_OMEGA_SQ_LOW <- 0.01

S4_NEAR_CONSTANT_THRESHOLD <- 0.95

SENS_W_CLIMATE_RANGE <- c(0.30, 0.70)
SENS_W_ROBUST_RANGE  <- c(0.10, 0.40)
SENS_W_VERIFY_RANGE  <- c(0.10, 0.40)
SENS_W_STEP          <- 0.10

GLOBAL_SEED <- 123

# =============================================================================
# DERIVED OBJECTS (do not edit below this line)
# =============================================================================

stage_dir <- function(stage) {
  d <- switch(as.character(stage),
              "1" = DIR_STAGE_1, "2" = DIR_STAGE_2,
              "3" = DIR_STAGE_3, "4" = DIR_STAGE_4,
              stop("Unknown stage: ", stage))
  file.path(PROJECT_DIR, d)
}

driver_info <- function(drv) {
  row <- DRIVER_META[DRIVER_META$driver == drv, ]
  if (nrow(row) == 0) stop("Driver '", drv, "' not found in DRIVER_META")
  as.list(row)
}

stopifnot(abs(W_CLIMATE + W_ROBUST + W_VERIFY - 1.0) < 1e-6)
# =============================================================================
