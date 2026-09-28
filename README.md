# Istanbul Sea Piers Passenger Data (2025) — Databricks Fundamentals

An introductory data engineering project using a 2025 passenger-count CSV from the [Istanbul Metropolitan Municipality Open Data Portal](https://data.ibb.gov.tr/dataset). The Databricks SQL notebook loads the source into Delta tables, checks data quality, and builds two analysis-ready monthly summaries.

## Pipeline

| Layer | Table | Purpose |
| --- | --- | --- |
| Raw | CSV in a Unity Catalog Volume | Retain the uploaded source file. |
| Bronze | `workspace.default.ibb_deniz_iskeleleri_bronze` | Ingest source columns as text and retain `_metadata.file_path` as `kaynak_dosya`. |
| Silver | `workspace.default.ibb_deniz_iskeleleri_silver` | Convert year/month to integers and passenger counts to `BIGINT`; trim station names and turn empty names into `NULL`. |
| Gold | `workspace.default.ibb_deniz_iskeleleri_gold_aylik` | Aggregate by year and month. |
| Gold | `workspace.default.ibb_deniz_iskeleleri_gold_aylik_otorite` | Aggregate by year, month, and authority. |

The notebook source is [IBB_Deniz_Iskeleleri_2025_Data_Engineering_ordered.sql](IBB_Deniz_Iskeleleri_2025_Data_Engineering_ordered.sql). Its cells are ordered from source inspection through Bronze, Silver, Gold, and final checks.

## Validated results

- 958 source, Bronze, and Silver rows; 12 months in the monthly Gold table.
- `SUM(yolcu_sayisi)` in Silver: **70,513,663**. This is the sum of the dataset's passenger-count field, not a count of distinct annual people.
- 29 Silver rows have an unknown station name. They are retained and account for 322,004 in `yolcu_sayisi`.
- The authority-month Gold table has 93 rows covering 8 authorities. One authority has records for January–September only. Missing October–December combinations should not be presented as zero demand.
- A check for repeated `(yil, ay, otorite_adi, istasyon_adi)` keys returned no rows in this snapshot.

## Run in Databricks

1. Upload the source CSV to a Unity Catalog Volume at the path referenced in the notebook: `/Volumes/workspace/default/ibb_raw/2025-yl-istanbul-deniz-iskeleleri-yolcu-saylar.csv`. Change the two `read_files` paths if your location differs.
2. Import the `.sql` source as a Databricks notebook and attach available SQL/serverless compute.
3. Run the notebook from top to bottom. The `CREATE OR REPLACE TABLE` statements rewrite the four Delta tables in dependency order. Repeated runs create new Delta history entries, so run it when rebuilding the snapshot is needed.
4. Review the final checks, including 958 Silver rows, 70,513,663 passenger counts, and 29 rows with unknown stations.

The raw CSV and Delta table data are not bundled in this repository. The notebook uses workspace-specific catalog, schema, and Volume names; adjust them for another workspace. The source-format notebook contains code and Markdown, while Databricks chart settings and rendered outputs are not embedded in the `.sql` export.

## Interpretation limits

The meaning of `tekil_yolcu_sayisi` needs confirmation from source documentation before treating sums across months as a yearly distinct-person count. The reason for the three missing authority-month combinations is unknown from this dataset alone. This project rebuilds a small, fixed CSV snapshot; it does not implement incremental ingestion or an automated schedule.
