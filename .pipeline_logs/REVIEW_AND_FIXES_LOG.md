# TRACE Season Classification Pipeline — Review & Fixes Log

**Convention:** This file is the permanent record for all assessments, findings, and fixes to this pipeline.
Always read this file at the start of any session that touches this codebase.
Always append entries when findings are made or changes are applied.

---

## Log format

Each entry has:
- **Date** — session date
- **Branch / commit** — where the work happened
- **Type** — FINDING | FIX | DOCUMENTATION | ARCHITECTURE
- **Severity** — CRITICAL | SIGNIFICANT | ROBUSTNESS | STYLE | DOCS
- **Status** — OPEN | FIXED | WONTFIX | DEFERRED

---

## SESSION 1 — Prior context (pre-summary)

Work done before context compression. Summary reconstructed from automated summary.

### Bug A — `lower_closed` missing in STAGE_1 quantile k=2 and k=3
- **Type:** FIX | **Severity:** SIGNIFICANT | **Status:** FIXED (corrected-release)
- `assign_2season()` quantile path in STAGE_1 and 3STAGE/STAGE_1 missing `lower_closed = dm$high_is_dry`.
- Fixed in both files.

### Bug B — Spurious `davies_p` in `null_result$boot_sum`
- **Type:** FIX | **Severity:** SIGNIFICANT | **Status:** FIXED (corrected-release)
- `boot_sum` tibble in `fit_seg1` and `fit_seg2` null paths contained `davies_p = NA_real_`.
- This caused schema mismatch on `bind_rows`. Removed from both null-path boot_sum tibbles.
- **NOTE:** This fix exposed a RELATED NEW BUG (see SESSION 2 finding #1).

### Bug C — Open boundary `x < t2` in `season_from_thresholds()` k=3 high_is_dry
- **Type:** FIX | **Severity:** SIGNIFICANT | **Status:** FIXED (corrected-release)
- Changed to `x <= t2` for consistency with `assign_3season(lower_closed=TRUE)`.

### Hardcoded Davies alpha
- **Type:** FIX | **Severity:** SIGNIFICANT | **Status:** FIXED (corrected-release)
- `davies_p < 0.05` replaced with `davies_p < DAVIES_ALPHA` in STAGE_2.

### Hardcoded quantile split fractions
- **Type:** FIX | **Severity:** SIGNIFICANT | **Status:** FIXED (corrected-release)
- `0.5`, `c(1/3, 2/3)` replaced with `Q_SPLIT_2S`, `Q_SPLIT_3S` in STAGE_1 and 3STAGE/STAGE_1.

### Hardcoded `0.66` for Q_HID_T2
- **Type:** FIX | **Severity:** SIGNIFICANT | **Status:** FIXED (corrected-release, commit 21e5e0e)
- Added `Q_HID_T2 <- 0.66` to all 4 config files.
- Replaced `0.66` with `Q_HID_T2` in STAGE_1 and 3STAGE/STAGE_1.

### Hardcoded weight sensitivity sequences
- **Type:** FIX | **Severity:** SIGNIFICANT | **Status:** FIXED (corrected-release)
- `seq(0.3, 0.7, 0.1)` etc. replaced with `SENS_W_CLIMATE_RANGE`, `SENS_W_ROBUST_RANGE`, `SENS_W_VERIFY_RANGE`, `SENS_W_STEP` in STAGE_4 and 3STAGE/STAGE_3.

### Float tolerance in 3STAGE/STAGE_3 weight grid filter
- **Type:** FIX | **Severity:** ROBUSTNESS | **Status:** FIXED (corrected-release, commit 21e5e0e)
- `abs(w_climate + w_robust - 1) < 1e-9` → `< 1e-6`.

### Output interpretation guidance (16 items)
- **Type:** DOCUMENTATION | **Severity:** DOCS | **Status:** FIXED (corrected-release, commit 21e5e0e)
- Created `PIPELINE_OUTPUTS_GUIDE.md` with benchmarks for all key output columns.
- Added Section 12 result quality synthesis warning to STAGE_4.
- Added Section 8 result quality synthesis warning to 3STAGE/STAGE_3.

---

## SESSION 2 — Full review of corrected-release (v2 content)

**Date:** 2026-04-03
**Branch:** corrected-release (working branch: claude/review-pipeline-structure-TVCqH)
**Commit at start of session:** 21e5e0e
**Scope:** All scripts reviewed end-to-end using 7-stage methodology.
**Findings → target branch for fixes: v3-corrected**

---

### FINDING 2.1 — CRITICAL
**File:** `STAGE_2_ecological_segmentation.R`
**Location:** `fit_seg1` lines 192–197; `fit_seg2` lines 251–257
**Type:** BUG | **Severity:** CRITICAL | **Status:** FIXED (v3-corrected)

`null_result` in both `fit_seg1` and `fit_seg2` does not contain `davies_p` at the top level.
`map_dbl(res, "davies_p")` at line 381 crashes with a length-0 coercion error whenever
any driver has < `MIN_MONTHS_FOR_SEG` months of overlap or triggers the near-constant response path.
Fix: add `davies_p = NA_real_` to both null_result lists.

---

### FINDING 2.2 — CRITICAL
**File:** `STAGE_3_season_validation.R`
**Location:** lines 234–251 (posthoc_tbl), line 444–447 (write.csv)
**Type:** BUG | **Severity:** CRITICAL | **Status:** FIXED (v3-corrected)

`posthoc_tbl %>% unnest(tukey)` when all Tukey results are NULL produces a tibble with only
grouping columns. The subsequent `dplyr::select(..., comparison, diff, lwr, upr, p_adj = \`p adj\`)`
crashes because those columns don't exist.
Trigger conditions: no k=3 candidates, or all k=3 groups too small for TukeyHSD.
Fix: add column existence guard before the select, or initialise an empty scaffold.

---

### FINDING 2.3 — CRITICAL
**File:** `STAGE_4_decision_ranking.R`
**Location:** lines 216, 427
**Type:** BUG | **Severity:** CRITICAL | **Status:** FIXED (v3-corrected)

`stage2_near_constant = is.finite(pmax2) && pmax2 > 0.95` uses hardcoded 0.95 in two places.
`S4_NEAR_CONSTANT_THRESHOLD <- 0.95` is defined in all full-pipeline config files but never used.
Fix: replace both 0.95 with `S4_NEAR_CONSTANT_THRESHOLD`.

---

### FINDING 2.4 — SIGNIFICANT
**File:** `STAGE_1_season_candidates.R`
**Location:** `assign_2season()` lines 94–100
**Type:** BUG | **Severity:** SIGNIFICANT | **Status:** FIXED (v3-corrected)

`assign_2season` in main STAGE_1 lacks the `if (!is.finite(t)) return(rep(NA_character_, length(x)))`
guard present in 3STAGE/STAGE_1. When `t = NA_real_` (baseline too short), `case_when` evaluates
`x <= NA_real_` as NA → treated as FALSE → all finite x assigned to "high" bin instead of NA.
Caught downstream by `n_levels_used < k` filter, but semantically wrong intermediate state.
Fix: add the finite-threshold guard to main STAGE_1's assign_2season.

---

### FINDING 2.5 — SIGNIFICANT
**File:** `STAGE_4_decision_ranking.R`
**Location:** line 64–69 (after base_tbl construction)
**Type:** ROBUSTNESS | **Severity:** SIGNIFICANT | **Status:** FIXED (v3-corrected)

No guard for empty `base_tbl` when all candidates are dropped by Stage 3.
Script runs 300 bootstrap iterations producing empty results, then Section 12 accesses
`winner_row$p_top1` etc. on a zero-row tibble.
Fix: `if (nrow(base_tbl) == 0) stop(...)` immediately after base_tbl construction.

---

### FINDING 2.6 — SIGNIFICANT
**File:** `FINAL_season_assignment.R`
**Location:** lines 64, 86–93
**Type:** ROBUSTNESS | **Severity:** SIGNIFICANT | **Status:** FIXED (v3-corrected)

No guard for `winner_id = NA` (from empty boot_summary) or empty `season_final`.
`min(season_final$Year)` crashes on empty tibble.
Fix: validate winner_id is non-NA and season_final is non-empty.

---

### FINDING 2.7 — SIGNIFICANT
**File:** `3STAGE/STAGE_1_climate_only_candidates.R`, `3STAGE/STAGE_2_climate_only_validation.R`, `3STAGE/STAGE_3_climate_only_ranking.R`
**Location:** line 27 in each (CONFIG_FILE default)
**Type:** ROBUSTNESS | **Severity:** SIGNIFICANT | **Status:** FIXED (v3-corrected)

Default `Sys.getenv("SEASON_CONFIG", unset = "config_climate_only.R")` without directory prefix
fails when scripts are run from the project root directory (not from inside 3STAGE/).
Fix: change unset to `"3STAGE/config_climate_only.R"` in all three 3STAGE scripts.

---

### FINDING 2.8 — ROBUSTNESS
**File:** `STAGE_4_decision_ranking.R`
**Location:** line 618
**Type:** STYLE | **Severity:** MINOR | **Status:** FIXED (v3-corrected)

`n_weight_combos <- nrow(weight_sensitivity)` assigned but never referenced. Dead variable.
Fix: remove.

---

### FINDING 2.9 — ROBUSTNESS
**File:** `STAGE_4_decision_ranking.R`
**Location:** bootstrap `boot_once()`, lines 443–471; `nce_ssa` extraction line 447
**Type:** LOGIC | **Severity:** ROBUSTNESS | **Status:** FIXED (v3-corrected, documentation only)

`nce_ssa` is taken from the original `decision_set` (fixed) while `bsa_min_ssa` is resampled.
Both contribute to `tier_verify`. The asymmetry slightly understates bootstrap variance of
tier_verify. The design choice (nce_ssa is structural, not year-dependent) is valid but undocumented.
Fix: add explanatory comment; no code change needed.

---

### FINDING 2.10 — DOCS
**File:** `STAGE_1_season_candidates.R`
**Location:** line 199
**Type:** DOCUMENTATION | **Severity:** MINOR | **Status:** FIXED (v3-corrected)

Comment says "0.66 value is a fixed scientific choice" but code uses `Q_HID_T2`.
Fix: update comment to reference `Q_HID_T2`.

---

### FINDING 2.11 — DOCS
**File:** `CHANGELOG.md`
**Type:** DOCUMENTATION | **Severity:** DOCS | **Status:** FIXED (v3-corrected)

Latest commit (21e5e0e) — Q_HID_T2, synthesis warnings, float fix, PIPELINE_OUTPUTS_GUIDE.md —
not documented in CHANGELOG.

---

### FINDING 2.12 — DOCS
**File:** `README.md`
**Type:** DOCUMENTATION | **Severity:** DOCS | **Status:** FIXED (v3-corrected)

- No mention of PIPELINE_OUTPUTS_GUIDE.md
- No description of season_assignment_final.csv output format

---

### FINDING 2.13 — DOCS
**File:** `PIPELINE_OUTPUTS_GUIDE.md`
**Type:** DOCUMENTATION | **Severity:** DOCS | **Status:** FIXED (v3-corrected)

Missing coverage:
- `kappa_std_quant`, `kappa_ssa`
- `stage2_pmax`
- `entropy_norm`
- `med_run`
- `block_stability.csv`
- `prop_healthy`, `n_collapsed`
- Climate-only pipeline output differences (no Tier 3 columns)
Benchmark inconsistency: `bsa_min_ssa` quick-reference table says "Investigate < 0.30"
but narrative says "< 0.40 weak" — contradictory.

---

### DEFERRED / DOCUMENTED ONLY (not code-changed in v3)

**2.D1** — Package version checks are comments only, not enforced (acceptable: adding
`stopifnot(packageVersion("dplyr") >= "1.1.0")` would be overly strict; in-code comments suffice).

**2.D2** — `sys.frame(1)$ofile` path detection fragile under Rscript (existing fallback + getwd()
is standard R idiom; no better cross-platform solution without adding a package dependency).

**2.D3** — `assign_2season`/`assign_3season` return type inconsistency within 3STAGE vs full pipeline
(intentional self-containment design; each stage is standalone).

**2.D4** — Per-driver re-seeding in STAGE_2 (documented in existing comment; design choice).

**2.D5** — Duplication of helper functions between STAGE_4 and 3STAGE/STAGE_3 (self-containment design choice).

**2.D6** — `posthoc_tbl` `unnest` producing zero-row tibble with no Tukey columns is guarded in v3 fix.

---

## BRANCH / COMMIT REFERENCE

| Branch | Content |
|--------|---------|
| `main` | Original code |
| `corrected-release` | All Session 1 fixes; corresponds to v2 |
| `v3-corrected` | All Session 2 fixes; corresponds to v3 |

---

## ALWAYS CHECK BEFORE STARTING WORK

1. Read this entire log.
2. Run `git log --oneline -10` to confirm current state.
3. Run `git status` to confirm clean working tree.
4. Confirm which branch you are on matches the task.
