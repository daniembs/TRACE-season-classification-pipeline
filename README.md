# Season classification pipeline

Reproducible R pipeline for climate-based season classification in weakly seasonal ecosystems, with optional ecological breakpoint verification.

This repository contains the code used to classify season definitions at the TRACE site in the Luquillo Experimental Forest, Puerto Rico, and includes both:

- a **4-stage pipeline** for climate-based season classification with independent ecological verification
- a **3-stage climate-only pipeline** for study systems where no ecological response time series is available

## Overview

Season boundaries in humid tropical forests are often weak, irregular, and difficult to define using calendar conventions or ad hoc rainfall cutoffs. This pipeline provides an auditable and reproducible framework for selecting a season definition from a predefined candidate set using climate structure, internal robustness, and, when available, independent ecological corroboration.

### 4-stage pipeline
1. **Stage 1**: Generate candidate season definitions from climate data and screen them for structural stability
2. **Stage 2**: Fit segmented regressions to an ecological response variable and evaluate breakpoint support
3. **Stage 3**: Stress-test surviving candidates within the ecological measurement window
4. **Stage 4**: Rank candidates using a tiered composite score, bootstrap rank stability, and weight sensitivity analysis

### 3-stage climate-only pipeline
1. **Stage 1**: Generate candidate season definitions from climate data and screen them for structural stability
2. **Stage 2**: Stress-test surviving candidates within a validation window
3. **Stage 3**: Rank candidates using climate structure, internal robustness, bootstrap rank stability, and weight sensitivity analysis

## Repository contents

### Full 4-stage pipeline
- `config.R`
- `STAGE_1_season_candidates.R`
- `STAGE_2_ecological_segmentation.R`
- `STAGE_3_season_validation.R`
- `STAGE_4_decision_ranking.R`
- `FINAL_season_assignment.R`

### Climate-only 3-stage pipeline
- `config_climate_only.R`
- `STAGE_1_climate_only_candidates.R`
- `STAGE_2_climate_only_validation.R`
- `STAGE_3_climate_only_ranking.R`

### Documentation
- `SOP_Season_Pipeline.docx`
- `TableS1_Pipeline_Metrics.docx`

## Input requirements

### Full 4-stage pipeline
Two input tables are required:

1. **Climate data**
   - one row per `Year`–`Month`
   - monthly time step
   - required columns defined in `config.R`
   - should include the selected climate drivers or the variables needed to derive them

2. **Ecological response data**
   - one row per `Year`–`Month`
   - must contain `Year`, `Month`, and the response column specified in `RESPONSE_COL`
   - should already be aggregated to monthly scale before running the pipeline

### Climate-only 3-stage pipeline
One climate data input table is required:
- required columns defined in `config_climate_only.R`

## Configuration

All user settings are defined in the configuration file.

### Full pipeline
Edit `config.R` to specify:
- project directory and file paths
- climate drivers and polarity
- standard thresholds
- baseline period
- ecological response column and related settings
- scoring weights and bootstrap settings

### Climate-only pipeline
Edit `config_climate_only.R` to specify:
- project directory and file paths
- climate drivers and polarity
- standard thresholds
- baseline period
- scoring weights and bootstrap settings

## Running the pipeline

### Full 4-stage version
Run the scripts in this order:

1. `STAGE_1_season_candidates.R`
2. `STAGE_2_ecological_segmentation.R`
3. `STAGE_3_season_validation.R`
4. `STAGE_4_decision_ranking.R`
5. `FINAL_season_assignment.R`

### Climate-only 3-stage version
Run the scripts in this order:

1. `STAGE_1_climate_only_candidates.R`
2. `STAGE_2_climate_only_validation.R`
3. `STAGE_3_climate_only_ranking.R`
4. `FINAL_season_assignment.R`

## Outputs

Depending on pipeline version, outputs include:
- retained candidate tables
- threshold tables
- season assignments by month
- structural screening and validation summaries
- decision tables and ranking outputs
- bootstrap rank summaries
- weight sensitivity summaries
- final season assignment table

## Reproducibility notes

- All season definitions are derived from a predefined candidate set specified in the configuration file.
- The ecological tier is used only as an independent verification line and is weighted below climatological structure to avoid circularity in downstream analysis.
- The climate-only version is intended for cases where no ecological response time series is available for Stage 2 segmentation.
- The pipeline is applicable to any weakly seasonal ecosystem.

## Software

The pipeline was developed in **R**.  
Package requirements are loaded within the scripts.

## Code availability

This repository contains the code accompanying the manuscript:

**A Four-Stage Pipeline for Objective Season Classification in Humid Tropical Forests: Case study in the Luquillo Experimental Forest, Puerto Rico **  
Daniel Minikaev, Debjani Sihi, Sahsa C. Reed, Tana E. Wood 
Submitted to *Agricultural and Forest Meteorology*

## Citation

If you use this code, please cite the manuscript and this repository release.

Manuscript citation:
> [Authors]. [Year]. [Title]. [Journal / status].

Repository citation:
> [Authors]. [Year]. Tropical season classification pipeline (Version 1.0.0) [Computer software]. GitHub.

## License

This repository is released under the [LICENSE NAME] license. See `LICENSE` for details.