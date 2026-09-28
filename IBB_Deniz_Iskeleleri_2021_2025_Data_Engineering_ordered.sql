-- Databricks notebook source
-- MAGIC %md
-- MAGIC # IBB Deniz Iskeleleri (2021–2025)
-- MAGIC Run the 2025 notebook first to create `workspace.default.ibb_deniz_iskeleleri_bronze`.
-- MAGIC Upload all five CSVs to `/Volumes/workspace/default/ibb_raw/`.
-- MAGIC This source export keeps the SQL and text cells; see the .ipynb for saved results and chart definitions.

-- COMMAND ----------

SELECT *
FROM read_files(
  '/Volumes/workspace/default/ibb_raw/2021-yl-istanbul-deniz-iskeleleri-yolcu-saylar.csv',
  format => 'csv',
  header => true,
  sep => ',',
  inferColumnTypes => false
)
LIMIT 5;

-- COMMAND ----------

SELECT
  yil,
  COUNT(*) AS kayit_sayisi,
  COUNT(DISTINCT ay) AS ay_sayisi,
  SUM(CAST(toplam_yolculuk_sayisi AS BIGINT)) AS toplam_yolculuk
FROM read_files(
  '/Volumes/workspace/default/ibb_raw/202[1-4]-yl-istanbul-deniz-iskeleleri-yolcu-saylar.csv',
  format => 'csv',
  header => true,
  sep => ',',
  inferColumnTypes => false
)
GROUP BY yil
ORDER BY yil;

-- COMMAND ----------

CREATE OR REPLACE TABLE workspace.default.ibb_deniz_iskeleleri_bronze_2021_2024
USING DELTA AS
SELECT
  yil,
  ay,
  otorite_adi,
  istasyon_adi,
  tekil_yolcu_sayisi,
  toplam_yolculuk_sayisi,
  _metadata.file_path AS kaynak_dosya
FROM read_files(
  '/Volumes/workspace/default/ibb_raw/202[1-4]-yl-istanbul-deniz-iskeleleri-yolcu-saylar.csv',
  format => 'csv',
  header => true,
  sep => ',',
  inferColumnTypes => false
);

-- COMMAND ----------

SELECT
  yil,
  COUNT(*) AS kayit_sayisi,
  COUNT(DISTINCT ay) AS ay_sayisi,
  COUNT(DISTINCT kaynak_dosya) AS dosya_sayisi
FROM workspace.default.ibb_deniz_iskeleleri_bronze_2021_2024
GROUP BY yil
ORDER BY yil;

-- COMMAND ----------

CREATE OR REPLACE TABLE workspace.default.ibb_deniz_iskeleleri_silver_2021_2025
USING DELTA AS

SELECT
  CAST(yil AS INT) AS yil,
  CAST(ay AS INT) AS ay,
  otorite_adi,
  NULLIF(TRIM(istasyon_adi), '') AS istasyon_adi,
  CAST(tekil_yolcu_sayisi AS BIGINT) AS tekil_yolcu_sayisi,
  CAST(toplam_yolculuk_sayisi AS BIGINT) AS yolcu_sayisi,
  kaynak_dosya
FROM workspace.default.ibb_deniz_iskeleleri_bronze_2021_2024

UNION ALL

SELECT
  CAST(yil AS INT) AS yil,
  CAST(ay AS INT) AS ay,
  otorite_adi,
  NULLIF(TRIM(istasyon_adi), '') AS istasyon_adi,
  CAST(tekil_yolcu_sayisi AS BIGINT) AS tekil_yolcu_sayisi,
  CAST(yolcu_sayisi AS BIGINT) AS yolcu_sayisi,
  kaynak_dosya
FROM workspace.default.ibb_deniz_iskeleleri_bronze;

-- COMMAND ----------

SELECT
  yil,
  COUNT(*) AS kayit_sayisi,
  COUNT(DISTINCT ay) AS ay_sayisi,
  COUNT_IF(istasyon_adi IS NULL) AS bos_istasyon_sayisi,
  SUM(yolcu_sayisi) AS toplam_yolculuk
FROM workspace.default.ibb_deniz_iskeleleri_silver_2021_2025
GROUP BY yil
ORDER BY yil;

-- COMMAND ----------

SELECT
  yil,
  ay,
  otorite_adi,
  istasyon_adi,
  COUNT(*) AS tekrar_sayisi
FROM workspace.default.ibb_deniz_iskeleleri_silver_2021_2025
GROUP BY yil, ay, otorite_adi, istasyon_adi
HAVING COUNT(*) > 1
ORDER BY tekrar_sayisi DESC;

-- COMMAND ----------

CREATE OR REPLACE TABLE workspace.default.ibb_deniz_iskeleleri_gold_aylik_2021_2025
USING DELTA AS
SELECT
  yil,
  ay,
  SUM(yolcu_sayisi) AS yolcu_sayisi_toplami,
  COUNT(*) AS kaynak_satir_sayisi,
  COUNT_IF(istasyon_adi IS NULL) AS istasyonu_bilinmeyen_satir
FROM workspace.default.ibb_deniz_iskeleleri_silver_2021_2025
GROUP BY yil, ay;

-- COMMAND ----------

SELECT
  yil,
  COUNT(*) AS ay_sayisi,
  SUM(kaynak_satir_sayisi) AS kaynak_satir_toplami,
  SUM(yolcu_sayisi_toplami) AS yillik_yolculuk
FROM workspace.default.ibb_deniz_iskeleleri_gold_aylik_2021_2025
GROUP BY yil
ORDER BY yil;

-- COMMAND ----------

WITH yillik AS (
  SELECT
    yil,
    SUM(yolcu_sayisi_toplami) AS yolculuk
  FROM workspace.default.ibb_deniz_iskeleleri_gold_aylik_2021_2025
  GROUP BY yil
),
karsilastirma AS (
  SELECT
    yil,
    yolculuk,
    LAG(yolculuk) OVER (ORDER BY yil) AS onceki_yil
  FROM yillik
)
SELECT
  yil,
  yolculuk,
  onceki_yil,
  yolculuk - onceki_yil AS yillik_fark,
  ROUND(
    100.0 * (yolculuk - onceki_yil) / NULLIF(onceki_yil, 0),
    2
  ) AS yillik_degisim_yuzde
FROM karsilastirma
ORDER BY yil;

-- COMMAND ----------

CREATE OR REPLACE TABLE workspace.default.ibb_deniz_iskeleleri_gold_yillik_2021_2025
USING DELTA AS
WITH yillik AS (
  SELECT
    yil,
    SUM(yolcu_sayisi_toplami) AS yolculuk
  FROM workspace.default.ibb_deniz_iskeleleri_gold_aylik_2021_2025
  GROUP BY yil
),
karsilastirma AS (
  SELECT
    yil,
    yolculuk,
    LAG(yolculuk) OVER (ORDER BY yil) AS onceki_yil
  FROM yillik
)
SELECT
  yil,
  yolculuk,
  onceki_yil,
  yolculuk - onceki_yil AS yillik_fark,
  ROUND(
    100.0 * (yolculuk - onceki_yil) / NULLIF(onceki_yil, 0),
    2
  ) AS yillik_degisim_yuzde
FROM karsilastirma;

-- COMMAND ----------

SELECT
  ay,
  yil,
  yolcu_sayisi_toplami
FROM workspace.default.ibb_deniz_iskeleleri_gold_aylik_2021_2025
ORDER BY ay, yil;

-- COMMAND ----------

SELECT
  g25.ay,
  g24.yolcu_sayisi_toplami AS yolculuk_2024,
  g25.yolcu_sayisi_toplami AS yolculuk_2025,
  g25.yolcu_sayisi_toplami - g24.yolcu_sayisi_toplami AS fark,
  ROUND(
    100.0 * (g25.yolcu_sayisi_toplami - g24.yolcu_sayisi_toplami)
    / NULLIF(g24.yolcu_sayisi_toplami, 0),
    2
  ) AS degisim_yuzde
FROM workspace.default.ibb_deniz_iskeleleri_gold_aylik_2021_2025 AS g24
JOIN workspace.default.ibb_deniz_iskeleleri_gold_aylik_2021_2025 AS g25
  ON g24.ay = g25.ay
WHERE g24.yil = 2024
  AND g25.yil = 2025
ORDER BY g25.ay;

-- COMMAND ----------

SELECT
  yil,
  ay,
  COUNT(DISTINCT otorite_adi) AS otorite_sayisi,
  COUNT(*) AS kayit_sayisi
FROM workspace.default.ibb_deniz_iskeleleri_silver_2021_2025
WHERE yil IN (2024, 2025)
GROUP BY yil, ay
ORDER BY ay, yil;

-- COMMAND ----------

WITH otoriteler_2024 AS (
  SELECT DISTINCT ay, otorite_adi
  FROM workspace.default.ibb_deniz_iskeleleri_silver_2021_2025
  WHERE yil = 2024
),
otoriteler_2025 AS (
  SELECT DISTINCT ay, otorite_adi
  FROM workspace.default.ibb_deniz_iskeleleri_silver_2021_2025
  WHERE yil = 2025
)
SELECT
  a.ay,
  a.otorite_adi
FROM otoriteler_2024 AS a
LEFT JOIN otoriteler_2025 AS b
  ON a.ay = b.ay
 AND a.otorite_adi = b.otorite_adi
WHERE b.otorite_adi IS NULL
ORDER BY a.ay;

-- COMMAND ----------

CREATE OR REPLACE TABLE workspace.default.ibb_deniz_iskeleleri_gold_aylik_otorite_2021_2025
USING DELTA AS
SELECT
  yil,
  ay,
  otorite_adi,
  SUM(yolcu_sayisi) AS yolcu_sayisi_toplami,
  COUNT(*) AS kaynak_satir_sayisi
FROM workspace.default.ibb_deniz_iskeleleri_silver_2021_2025
GROUP BY yil, ay, otorite_adi;

-- COMMAND ----------

SELECT
  yil,
  COUNT(*) AS ay_otorite_satiri,
  COUNT(DISTINCT ay) AS ay_sayisi,
  SUM(kaynak_satir_sayisi) AS kaynak_satir_toplami,
  SUM(yolcu_sayisi_toplami) AS yillik_yolculuk
FROM workspace.default.ibb_deniz_iskeleleri_gold_aylik_otorite_2021_2025
GROUP BY yil
ORDER BY yil;

-- COMMAND ----------

CREATE OR REPLACE TABLE workspace.default.ibb_deniz_iskeleleri_gold_karsilastirma_2024_2025
USING DELTA AS
WITH otorite_sayilari AS (
  SELECT
    yil,
    ay,
    COUNT(*) AS otorite_sayisi
  FROM workspace.default.ibb_deniz_iskeleleri_gold_aylik_otorite_2021_2025
  WHERE yil IN (2024, 2025)
  GROUP BY yil, ay
)
SELECT
  eski.ay,
  eski.yolcu_sayisi_toplami AS yolculuk_2024,
  yeni.yolcu_sayisi_toplami AS yolculuk_2025,
  yeni.yolcu_sayisi_toplami - eski.yolcu_sayisi_toplami AS fark,
  ROUND(
    100.0 * (yeni.yolcu_sayisi_toplami - eski.yolcu_sayisi_toplami)
    / NULLIF(eski.yolcu_sayisi_toplami, 0),
    2
  ) AS degisim_yuzde,
  otorite_2024.otorite_sayisi AS otorite_sayisi_2024,
  otorite_2025.otorite_sayisi AS otorite_sayisi_2025
FROM workspace.default.ibb_deniz_iskeleleri_gold_aylik_2021_2025 AS eski
JOIN workspace.default.ibb_deniz_iskeleleri_gold_aylik_2021_2025 AS yeni
  ON eski.ay = yeni.ay
JOIN otorite_sayilari AS otorite_2024
  ON otorite_2024.yil = 2024 AND otorite_2024.ay = eski.ay
JOIN otorite_sayilari AS otorite_2025
  ON otorite_2025.yil = 2025 AND otorite_2025.ay = yeni.ay
WHERE eski.yil = 2024
  AND yeni.yil = 2025;

-- COMMAND ----------

SELECT
  ay,
  yolculuk_2024,
  yolculuk_2025,
  fark,
  degisim_yuzde,
  otorite_sayisi_2024,
  otorite_sayisi_2025
FROM workspace.default.ibb_deniz_iskeleleri_gold_karsilastirma_2024_2025
ORDER BY ay;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC **Veri kapsamı notu:** Ekim–Aralık 2025 kaynak verisinde `ISTANBUL SEHIR HATLARI TUR. SAN. VE TIC. AS.` için kayıt bulunmuyor. Bu aylardaki 2024–2025 farkları yayımlanan kayıtların farkıdır; eksik kaydı sıfır yolculuk olarak yorumlamıyoruz.

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ### Proje özeti
-- MAGIC 
-- MAGIC İBB deniz iskeleleri yolculuk verilerinin 2021–2025 dönemindeki 4.885 kaynak satırı incelendi. Farklı yıllardaki CSV şemaları Silver katmanında ortak alanlara dönüştürüldü; Gold katmanında aylık, yıllık ve otorite bazlı özetler oluşturuldu. Her yıl 12 ay içeriyor ve Gold toplamları Silver toplamlarıyla uyuşuyor.
-- MAGIC 
-- MAGIC 2024–2025 karşılaştırmasında yayımlanan yıllık yolculuk toplamı 70.283.867'den 70.513.663'e çıktı (+229.796; yaklaşık %0,33). Ekim–Aralık 2025'te bir otoriteye ait kayıt bulunmadığından yıllık ve bu aylara ilişkin farklar kaynak kapsamı dikkate alınarak yorumlanmalıdır.
