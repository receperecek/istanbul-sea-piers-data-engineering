-- Databricks notebook source
-- MAGIC %md
-- MAGIC # İBB Deniz İskeleleri Yolcu Sayıları — 2025
-- MAGIC
-- MAGIC ## Amaç
-- MAGIC İBB'nin 2025 deniz iskeleleri yolcu verisini Databricks üzerinde
-- MAGIC kaynağından alıp temizleyerek analiz edilebilir aylık tablolara dönüştürmek.
-- MAGIC
-- MAGIC ## Veri akışı
-- MAGIC - **Kaynak:** İBB CSV dosyası, Databricks Volume içinde saklanıyor.
-- MAGIC - **Bronze:** CSV satırları ve kaynak dosya yolu Delta tablosuna alınıyor.
-- MAGIC - **Silver:** Yıl ve ay tamsayıya, yolcu sayıları BIGINT'e çevriliyor;
-- MAGIC   istasyon adındaki baş ve son boşluklar temizleniyor.
-- MAGIC - **Gold:** Silver verisinden ay bazında ve ay–otorite bazında
-- MAGIC   iki özet tablo üretiliyor.
-- MAGIC
-- MAGIC ## Kontroller ve bulgular
-- MAGIC - Bronze ve Silver: 958 satır.
-- MAGIC - Silver yolcu sayısı toplamı: 70.513.663.
-- MAGIC - İstasyon adı boş olan 29 satır korunuyor; bu satırların yolcu
-- MAGIC   sayısı toplamı 322.004.
-- MAGIC - Aylık Gold: 12 ay. Ay–otorite Gold: 93 kombinasyon.
-- MAGIC - Bir otoritenin ekim, kasım ve aralık kayıtları kaynakta bulunmuyor.
-- MAGIC   Bu durumun nedeni yalnızca bu veriyle belirlenemez.
-- MAGIC
-- MAGIC ## Yenileme
-- MAGIC Tablolar `CREATE OR REPLACE TABLE` ile kaynak → Bronze → Silver → Gold
-- MAGIC sırasıyla yeniden üretilebilir. Kaynak CSV değişmediyse yeniden
-- MAGIC çalıştırmak analitik sonucu değiştirmez.
-- MAGIC
-- MAGIC ## Yorum sınırı
-- MAGIC `tekil_yolcu_sayisi` alanını aylar boyunca toplayıp yıllık benzersiz
-- MAGIC kişi sayısı olarak yorumlamıyoruz; kaynağın bu metriği nasıl tanımladığı
-- MAGIC ayrıca doğrulanmalı.
-- MAGIC
-- MAGIC ## Çalıştırma notu
-- MAGIC Aşağıdaki hücreler kaynak kontrolü → Bronze → Silver → Gold → analiz sırasındadır.
-- MAGIC Kaynak CSV önce belirtilen Volume yoluna yüklenmiş olmalıdır.
-- MAGIC `CREATE OR REPLACE TABLE` her çalıştırmada Delta tablolara yeni yazma işlemi yapar.


-- COMMAND ----------

SELECT *
FROM read_files(
  '/Volumes/workspace/default/ibb_raw/2025-yl-istanbul-deniz-iskeleleri-yolcu-saylar.csv',
  format => 'csv',
  header => true,
  sep => ';',
  inferColumnTypes => false
)
LIMIT 10;

-- COMMAND ----------

SELECT
  COUNT(*) AS satir_sayisi,
  COUNT(DISTINCT ay) AS ay_sayisi
 FROM read_files(
    '/Volumes/workspace/default/ibb_raw/2025-yl-istanbul-deniz-iskeleleri-yolcu-saylar.csv',
    format => 'csv',
    header => true,
    sep => ';',
    inferColumnTypes => false
 );

-- COMMAND ----------

CREATE OR REPLACE TABLE workspace.default.ibb_deniz_iskeleleri_bronze
USING DELTA
AS
SELECT
  yil,
  ay,
  otorite_adi,
  istasyon_adi,
  tekil_yolcu_sayisi,
  yolcu_sayisi,
  _metadata.file_path AS kaynak_dosya
FROM read_files(
  '/Volumes/workspace/default/ibb_raw/2025-yl-istanbul-deniz-iskeleleri-yolcu-saylar.csv',
  format => 'csv',
  header => true,
  sep => ';',
  inferColumnTypes => false
);

-- COMMAND ----------

SELECT
  COUNT(*) AS bronze_satir_sayisi,
  COUNT(DISTINCT kaynak_dosya) AS kaynak_dosya_sayisi
FROM workspace.default.ibb_deniz_iskeleleri_bronze;

-- COMMAND ----------

DESCRIBE TABLE workspace.default.ibb_deniz_iskeleleri_bronze;

-- COMMAND ----------

SELECT
  COUNT_IF(istasyon_adi IS NULL OR TRIM(istasyon_adi) = '') AS bos_istasyon_adi,
  COUNT_IF(TRY_CAST(tekil_yolcu_sayisi AS BIGINT) IS NULL) AS gecersiz_tekil_sayi,
  COUNT_IF(TRY_CAST(yolcu_sayisi AS BIGINT) IS NULL) AS gecersiz_yolcu_sayisi
FROM workspace.default.ibb_deniz_iskeleleri_bronze;

-- COMMAND ----------

SELECT
  otorite_adi,
  COUNT(*) AS bos_istasyon_satiri,
  SUM(TRY_CAST(yolcu_sayisi AS BIGINT)) AS yolcu_sayisi_toplami
FROM workspace.default.ibb_deniz_iskeleleri_bronze
WHERE istasyon_adi IS NULL OR TRIM(istasyon_adi) = ''
GROUP BY otorite_adi
ORDER BY yolcu_sayisi_toplami DESC;

-- COMMAND ----------

CREATE OR REPLACE TABLE workspace.default.ibb_deniz_iskeleleri_silver
USING DELTA
AS
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
  COUNT(*) AS satir_sayisi,
  COUNT_IF(istasyon_adi IS NULL) AS bos_istasyon_sayisi,
  SUM(yolcu_sayisi) AS toplam_yolcu_sayisi
FROM workspace.default.ibb_deniz_iskeleleri_silver;

-- COMMAND ----------

SELECT
  yil,
  ay,
  otorite_adi,
  istasyon_adi,
  COUNT(*) AS tekrar_sayisi
FROM workspace.default.ibb_deniz_iskeleleri_silver
GROUP BY yil, ay, otorite_adi, istasyon_adi
HAVING COUNT(*) > 1;

-- COMMAND ----------

CREATE OR REPLACE TABLE workspace.default.ibb_deniz_iskeleleri_gold_aylik
USING DELTA
AS
SELECT
  yil,
  ay,
  SUM(yolcu_sayisi) AS yolcu_sayisi_toplami,
  COUNT(*) AS kaynak_satir_sayisi,
  COUNT_IF(istasyon_adi IS NULL) AS istasyonu_bilinmeyen_satir
FROM workspace.default.ibb_deniz_iskeleleri_silver
GROUP BY yil, ay;

-- COMMAND ----------

SELECT
  yil,
  ay,
  yolcu_sayisi_toplami,
  kaynak_satir_sayisi,
  istasyonu_bilinmeyen_satir
FROM workspace.default.ibb_deniz_iskeleleri_gold_aylik
ORDER BY yil, ay;

-- COMMAND ----------

WITH aylik AS (
  SELECT
    yil,
    ay,
    yolcu_sayisi_toplami,
    LAG(yolcu_sayisi_toplami) OVER (
      PARTITION BY yil
      ORDER BY ay
    ) AS onceki_ay_toplami
  FROM workspace.default.ibb_deniz_iskeleleri_gold_aylik
)
SELECT
  yil,
  ay,
  yolcu_sayisi_toplami,
  onceki_ay_toplami,
  yolcu_sayisi_toplami - onceki_ay_toplami AS aylik_fark,
  ROUND(
    100.0 * (yolcu_sayisi_toplami - onceki_ay_toplami)
    / NULLIF(onceki_ay_toplami, 0),
    2
  ) AS aylik_degisim_yuzdesi
FROM aylik
ORDER BY yil, ay;

-- COMMAND ----------

CREATE OR REPLACE TABLE workspace.default.ibb_deniz_iskeleleri_gold_aylik_otorite
USING DELTA
AS
SELECT
  yil,
  ay,
  otorite_adi,
  SUM(yolcu_sayisi) AS yolcu_sayisi_toplami,
  COUNT(*) AS kaynak_satir_sayisi
FROM workspace.default.ibb_deniz_iskeleleri_silver
GROUP BY yil, ay, otorite_adi;

-- COMMAND ----------

SELECT
  COUNT(*) AS ay_otorite_satiri,
  COUNT(DISTINCT ay) AS ay_sayisi,
  COUNT(DISTINCT otorite_adi) AS otorite_sayisi,
  SUM(kaynak_satir_sayisi) AS kaynak_satir_toplami,
  SUM(yolcu_sayisi_toplami) AS yolcu_sayisi_genel_toplami
FROM workspace.default.ibb_deniz_iskeleleri_gold_aylik_otorite;

-- COMMAND ----------

SELECT
  otorite_adi,
  COUNT(*) AS kaynak_satir_sayisi,
  SUM(yolcu_sayisi) AS yolcu_sayisi_toplami
FROM workspace.default.ibb_deniz_iskeleleri_silver
GROUP BY otorite_adi
ORDER BY yolcu_sayisi_toplami DESC;

-- COMMAND ----------

WITH ocak_subat AS (
  SELECT
    otorite_adi,
    MAX(CASE WHEN ay = 1 THEN yolcu_sayisi_toplami END) AS ocak,
    MAX(CASE WHEN ay = 2 THEN yolcu_sayisi_toplami END) AS subat
  FROM workspace.default.ibb_deniz_iskeleleri_gold_aylik_otorite
  WHERE yil = 2025
    AND ay IN (1, 2)
  GROUP BY otorite_adi
)
SELECT
  otorite_adi,
  ocak,
  subat,
  subat - ocak AS fark
FROM ocak_subat
ORDER BY fark;

-- COMMAND ----------

SELECT
  otorite_adi,
  COUNT(*) AS kaydi_olan_ay_sayisi,
  SORT_ARRAY(COLLECT_LIST(ay)) AS kaydi_olan_aylar
FROM workspace.default.ibb_deniz_iskeleleri_gold_aylik_otorite
GROUP BY otorite_adi
HAVING COUNT(*) < 12;

-- COMMAND ----------

DESCRIBE HISTORY workspace.default.ibb_deniz_iskeleleri_silver;

-- COMMAND ----------

SELECT
  COUNT(*) AS satir_sayisi,
  SUM(yolcu_sayisi) AS toplam_yolcu,
  SUM(CASE WHEN istasyon_adi IS NULL THEN 1 ELSE 0 END) AS istasyon_adi_bos_satir
FROM workspace.default.ibb_deniz_iskeleleri_silver;
