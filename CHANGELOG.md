# CHANGELOG

All changes relative to the original `daniembs/TRACE-season-classification-pipeline` repository (main branch).

| Branch | Content |
|--------|---------|
| `corrected-release` | v2 — all bug fixes and improvements documented below |
| `v3-corrected` | v3 — additional bug fixes and documentation improvements from second full review |

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

## What was NOT changed (v2 / corrected-release)

- All `.csv` and `.rds` data files are unchanged.
- `.docx` SOP files cannot be programmatically edited; any documentation corrections noted above apply only to `README.md` and code comments.
- Stage logic, statistical methods, and default parameter values are unchanged except where required by the bug fixes documented above.

---

## v3 changes (branch: v3-corrected)

The following additional fixes were applied after a second full review of the corrected-release codebase.

### Bug fixes

#### STAGE_2_ecological_segmentation.R
- **`davies_p` missing from null_result (fit_seg1 and fit_seg2).**
  When `nrow(d0) < MIN_MONTHS_FOR_SEG` or the near-constant response path fires,
  `null_result` was returned without `davies_p`. The subsequent `map_dbl(res, "davies_p")`
  crashed with a length-0 coercion error. Added `davies_p = NA_real_` to both null_result
  lists so the list schema matches the success path.

#### STAGE_3_season_validation.R
- **`posthoc_tbl` column select crash when no valid Tukey results exist.**
  If all k=3 Tukey computations return NULL (or there are no k=3 candidates),
  `unnest(tukey)` produces a tibble without the Tukey-specific columns, and the subsequent
  `dplyr::select(..., comparison, diff, ...)` crashed. Added a guard that writes an
  empty-but-typed tibble when no Tukey results are available.

#### STAGE_4_decision_ranking.R
- **`stage2_near_constant` used hardcoded 0.95 instead of `S4_NEAR_CONSTANT_THRESHOLD`.**
  Two occurrences: in `stage2_best_match()` and in the bootstrap inner function.
  Both replaced with `S4_NEAR_CONSTANT_THRESHOLD`. The config parameter was defined
  but never used.
- **No guard for empty `base_tbl`.**
  If all candidates were dropped by Stage 3, the script ran silently through 300 bootstrap
  iterations and crashed in Section 12 when accessing `winner_row` columns on a zero-row
  tibble. Added `stop()` immediately after base_tbl construction.
- **Dead variable `n_weight_combos`.**
  Assigned but never referenced. Removed.

#### STAGE_1_season_candidates.R
- **`assign_2season` missing `!is.finite(t)` guard.**
  When `t = NA_real_` (baseline period too short), `case_when`'s `x <= NA_real_`
  evaluates to NA, which falls through to `TRUE ~ high`, silently assigning every finite
  value to the "high" bin instead of returning NA. The 3STAGE version already had this
  guard. Added `if (!is.finite(t)) return(rep(NA_character_, length(x)))`.

#### FINAL_season_assignment.R
- **No validation of winner_id or season_final.**
  Added checks: (1) `boot_summary` non-empty and `top_candidate` non-NA before
  extracting winner; (2) `winner_meta` non-empty (candidate exists in threshold_tbl);
  (3) `season_final` non-empty after filtering.

#### 3STAGE/STAGE_1, STAGE_2, STAGE_3 climate-only scripts
- **Default config path missing directory prefix.**
  `unset = "config_climate_only.R"` failed when scripts were run from the project root
  because R searched for the file in the working directory. Changed to
  `unset = "3STAGE/config_climate_only.R"` in all three scripts.

### Documentation and code clarity

- **STAGE_4 bootstrap**: Added comment explaining why `nce_ssa` is taken from the
  original decision_set (fixed structural property) while `bsa_min_ssa` is resampled
  (year-dependent). The asymmetry is intentional but was undocumented.
- **STAGE_1 comment drift**: Comment referencing "0.66 value is a fixed scientific choice"
  updated to reference `Q_HID_T2` (the config parameter that replaced the hardcoded value).
- **README**: Added PIPELINE_OUTPUTS_GUIDE.md reference and description of
  `season_assignment_final.csv` output columns.
- **PIPELINE_OUTPUTS_GUIDE.md**:
  - Fixed inconsistency between quick-reference table and narrative benchmarks for
    `bsa_min_ssa` (table said "Investigate < 0.30"; narrative said "< 0.40 weak").
    Aligned both to "Investigate < 0.30" (matching the runtime quality flag threshold).
  - Added coverage for `kappa_std_quant`, `kappa_ssa`, `stage2_pmax`, `entropy_norm`,
    `med_run`, `block_stability.csv`, `prop_healthy`, `n_collapsed`.
  - Added dedicated section on climate-only (3-stage) pipeline output differences:
    absent Tier 3 columns, max score_n_components = 6, 2-column weight sensitivity.
  - Added climate-only note to quick-reference table.
- **CHANGELOG**: Updated branch reference table; added v3 section.

### What was NOT changed in v3

- All statistical methods, default parameter values, and pipeline logic are unchanged.
- All `.csv` and `.rds` data files are unchanged.
- The `.docx` SOP files are not edited.
