# CHANGELOG

All changes relative to the original `daniembs/TRACE-season-classification-pipeline` repository (main branch).
Applied on branch `claude/review-pipeline-structure-TVCqH`.

---

## Bug fixes

### STAGE_1_season_candidates.R
- **Bug A — missing `lower_closed` in quantile k=2 `assign_2season()` call.**
  The std-method path correctly passed `lower_closed = dm$high_is_dry`, but the quantile-method path omitted it. Added the argument so boundary convention is consistent across both threshold methods.
- **Bug A — hardcoded quantile split fractions replaced by config params.**
  `quantile(xb_q, 0.5, ...)` replaced by `quantile(xb_q, Q_SPLIT_2S, ...)`.
  `get_q(xb, probs = c(1/3, 2/3))` replaced by `get_q(xb, probs = Q_SPLIT_3S)`.

### STAGE_2_ecological_segmentation.R
- **Bug B — spurious `davies_p` column in `null_result$boot_sum`.**
  The null-path `boot_sum` tibble inside both `fit_seg1` and `fit_seg2` contained `davies_p = NA_real_`, but the success-path tibble did not. This caused a schema mismatch when rows were bound via `bind_rows()`. Removed `davies_p` from both null-path tibbles.
- **Bug C — inconsistent upper boundary in `season_from_thresholds()` k=3 high_is_dry path.**
  Used open boundary `x < t2` (inconsistent with `assign_3season(lower_closed=TRUE)` which uses `x <= t2`). Changed to `x <= t2`.
- **Hardcoded Davies alpha.**
  `davies_p < 0.05` replaced by `davies_p < DAVIES_ALPHA` so the significance level is controlled from config.

### 3STAGE/STAGE_1_climate_only_candidates.R
- Same Bug A fixes as the main STAGE_1 (see above): `lower_closed`, `Q_SPLIT_2S`, `Q_SPLIT_3S`.
- `assign_3season()` call in quantile path was also missing `lower_closed = dm$high_is_dry`; added.

---

## Configuration

### config.R (full pipeline)
- **Restructured into three tiers:** SITE SETTINGS (mandatory, site-specific) / METHOD SETTINGS (defaults with scientific justification required to change) / ADVANCED SETTINGS (internal thresholds; do not change lightly).
- **Fixed `DRIVER_META` template:** vector length mismatch (4 `high_is_dry` values vs 3 drivers); `TRUE/FALSE` placeholder (evaluates to `Inf`) replaced with explicit `TRUE`/`FALSE` values.
- **Added new config parameters:** `Q_SPLIT_2S <- 0.50`, `Q_SPLIT_3S <- c(1/3, 2/3)`, `DAVIES_ALPHA <- 0.05`.
- Moved `MIN_DELTA_AIC`, `BOOT_N_RANK`, `BOOT_B_SEG`, `MIN_MONTHS_FOR_SEG`, stage-1 screening thresholds to METHOD SETTINGS.
- Added `SEASON_CONFIG` usage note in file header.
- Improved all inline comments (explain why, not just what).

### TRAEC_data/config_TRACE.R
- Restructured to match new three-tier format.
- Added `Q_SPLIT_2S`, `Q_SPLIT_3S`, `DAVIES_ALPHA`.

### test_data/config_testdata.R
- Restructured to match new three-tier format.
- Added `Q_SPLIT_2S`, `Q_SPLIT_3S`, `DAVIES_ALPHA`.

### 3STAGE/config_climate_only.R
- Full rewrite into three-tier format matching `config.R`.
- **Fixed `DRIVER_META` template:** same vector-length and `TRUE/FALSE` issues as main `config.R`; corrected.
- Added `Q_SPLIT_2S`, `Q_SPLIT_3S`.
- Added `SENS_W_CLIMATE_RANGE`, `SENS_W_ROBUST_RANGE`, `SENS_W_STEP` (2-tier version).
- Added `SEASON_CONFIG` usage note in file header.

---

## Script improvements (applied in earlier commits on this branch)

All four main pipeline scripts (STAGE_1 through STAGE_4) received:

- **Defensive data checks** (commit `8a477fe`): validation of required columns, date ranges, minimum row counts, and RDS input compatibility at the start of each stage.
- **Reproducibility improvements** (commit `545c469`): `set.seed()` placement and commentary, session-info capture, `packageVersion()` notes, promotion of remaining hardcoded values to config.
- **Style normalisation** (commits `8479837`, `4b3db98`): purpose-oriented section headers (describe what the section achieves, not just the operation name); function comments explain *why* choices were made, not just what the code does; dashed sub-section markers normalised to plain inline comments.

### 3STAGE/STAGE_3_climate_only_ranking.R
- Hardcoded weight sensitivity grid `seq(0.30, 0.90, by = 0.05)` / `seq(0.10, 0.70, by = 0.05)` replaced with `SENS_W_CLIMATE_RANGE`, `SENS_W_ROBUST_RANGE`, `SENS_W_STEP` from config.

---

## Documentation

### README.md
- Fixed broken backtick in file listing.
- Corrected `SOP_Season_Pipeline.docx` → `SOP_Pipeline.docx`.
- Added note that climate-only scripts are in `3STAGE/` subfolder.
- Corrected `TRACE_data/` → `TRAEC_data/` throughout.
- Added `SEASON_CONFIG` environment variable documentation.
- Added R package installation instructions.
- Added section on switching config files without editing stage scripts.

### FINAL_season_assignment.R
- Section 0 comment "edit ONE of the two lines below" removed. The script auto-detects the pipeline version from the config (presence of `DIR_STAGE_4`); no manual editing is required for standard use. Comment updated to explain the auto-detection logic.

---

## What was NOT changed

- All `.csv` and `.rds` data files are unchanged.
- `.docx` SOP files cannot be programmatically edited; any documentation corrections noted above apply only to `README.md` and code comments.
- Stage logic, statistical methods, and default parameter values are unchanged except where required by the bug fixes documented above.
