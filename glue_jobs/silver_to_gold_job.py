import sys

from awsglue.context import GlueContext
from awsglue.job import Job
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from pyspark.sql import functions as F

# -------------------------------------------------------------------
# Expected job arguments
# -------------------------------------------------------------------
# Required:
# --JOB_NAME
# --SILVER_CURATED_PATH
# --GOLD_DAILY_PRODUCT_SALES_PATH
# --GOLD_CATEGORY_SALES_PATH
# --PIPELINE_RUN_ID
#
# Example:
# --SILVER_CURATED_PATH s3://demo-medallion-etl-pipeline/silver/orders_curated/
# --GOLD_DAILY_PRODUCT_SALES_PATH s3://demo-medallion-etl-pipeline/gold/daily_product_sales/
# --GOLD_CATEGORY_SALES_PATH s3://demo-medallion-etl-pipeline/gold/category_sales/
# --PIPELINE_RUN_ID run_20260321_03

args = getResolvedOptions(
    sys.argv,
    [
        "JOB_NAME",
        "SILVER_CURATED_PATH",
        "GOLD_DAILY_PRODUCT_SALES_PATH",
        "GOLD_CATEGORY_SALES_PATH",
        "PIPELINE_RUN_ID",
    ],
)

# -------------------------------------------------------------------
# Initialize Spark / Glue contexts
# -------------------------------------------------------------------
sc = SparkContext()
glue_context = GlueContext(sc)
spark = glue_context.spark_session
job = Job(glue_context)
job.init(args["JOB_NAME"], args)

silver_curated_path = args["SILVER_CURATED_PATH"]
gold_daily_product_sales_path = args["GOLD_DAILY_PRODUCT_SALES_PATH"]
gold_category_sales_path = args["GOLD_CATEGORY_SALES_PATH"]
pipeline_run_id = args["PIPELINE_RUN_ID"]

# -------------------------------------------------------------------
# Important setting:
# Use dynamic partition overwrite so that when a partition
# (for example order_date=2026-03-20) is reprocessed,
# only that partition is refreshed instead of replacing all data.
# -------------------------------------------------------------------
spark.conf.set("spark.sql.sources.partitionOverwriteMode", "dynamic")

# ---------------------------------------------------------------
# ICEBERG CONFIGURATION
# ---------------------------------------------------------------
spark.conf.set("spark.sql.catalog.glue_catalog", "org.apache.iceberg.spark.SparkCatalog")

spark.conf.set(
    "spark.sql.catalog.glue_catalog.catalog-impl", "org.apache.iceberg.aws.glue.GlueCatalog"
)

spark.conf.set(
    "spark.sql.catalog.glue_catalog.warehouse", "s3://veera-crm-healthcare-pipeline/gold/iceberg/"
)

spark.conf.set("spark.sql.catalog.glue_catalog.io-impl", "org.apache.iceberg.aws.s3.S3FileIO")
# -------------------------------------------------------------------
# STEP 1: Read Silver Curated Orders
# -------------------------------------------------------------------
# This dataset already contains:
# - cleaned order data
# - standardized status
# - derived order_amount
# - enriched product attributes
# -------------------------------------------------------------------
orders_curated_df = spark.read.parquet(silver_curated_path)

# -------------------------------------------------------------------
# STEP 2: Apply safety filters before Gold aggregation
# -------------------------------------------------------------------
# Silver is already curated, but we still apply a few safeguards
# before creating business aggregates.
#
# What we check here:
# - order_id must not be null
# - order_date must not be null
# - quantity must not be null
# - unit_price must not be null
# - order_amount must not be null
#
# This protects Gold from accidental bad rows.
# -------------------------------------------------------------------
gold_base_df = (
    orders_curated_df.filter(F.col("order_id").isNotNull())
    .filter(F.col("order_date").isNotNull())
    .filter(F.col("quantity").isNotNull())
    .filter(F.col("unit_price").isNotNull())
    .filter(F.col("order_amount").isNotNull())
)

# -------------------------------------------------------------------
# STEP 3: Build Gold Table - Daily Product Sales
# -------------------------------------------------------------------
# Aggregation level:
# - one row per order_date + product_id + product_name + category
#
# Measures:
# - total_orders   -> distinct order count
# - total_quantity -> total quantity sold
# - total_sales    -> total order_amount
#
# This table is useful for:
# - daily product-wise reporting
# - product trend analysis
# - dashboarding
# -------------------------------------------------------------------
daily_product_sales_df = gold_base_df.groupBy(
    F.col("order_date"), F.col("product_id"), F.col("product_name"), F.col("category")
).agg(
    F.countDistinct("order_id").cast("int").alias("total_orders"),
    F.sum("quantity").cast("int").alias("total_quantity"),
    F.round(F.sum("order_amount"), 2).cast("double").alias("total_sales"),
)

daily_product_sales_df = daily_product_sales_df.withColumn(
    "pipeline_run_id", F.lit(pipeline_run_id)
)

# -------------------------------------------------------------------
# Build Gold Fact Table - Fact Sales
# Star-Schema implentation
# -------------------------------------------------------------------
fact_sales_df = gold_base_df.select(
    "order_id", "customer_id", "product_id", "order_date", "quantity", "unit_price", "order_amount"
)
# -------------------------------------------------------------------
# Build Gold Dimension Table - Dimension Product
# -------------------------------------------------------------------
try:
    current_dim_product_df = spark.table("glue_catalog.veeradb_iceberg.dim_product")
except:
    current_dim_product_df = None

if current_dim_product_df is None:
    dim_product_df = (
        gold_base_df.select("product_id", "product_name", "category", "brand")
        .dropDuplicates()
        .withColumn("effective_date", F.current_date())
        .withColumn("end_date", F.lit("9999-12-31"))
        .withColumn("is_current", F.lit(True))
    )

    # First load
    new_product_dim_versions_df = dim_product_df

else:

    incoming_products_df = gold_base_df.select(
        "product_id", "product_name", "category", "brand"
    ).dropDuplicates()

    changed_products_df = (
        incoming_products_df.alias("new")
        .join(current_dim_product_df.filter(F.col("is_current") == True).alias("old"), "product_id")
        .filter(
            (F.col("new.category") != F.col("old.category"))
            | (F.col("new.brand") != F.col("old.brand"))
            | (F.col("new.product_name") != F.col("old.product_name"))
        )
    )

    changed_product_ids = [
        row.product_id for row in changed_products_df.select("product_id").distinct().collect()
    ]

    for pid in changed_product_ids:

        spark.sql(f"""
            UPDATE glue_catalog.veeradb_iceberg.dim_product
            SET
                end_date = current_date(),
                is_current = false
            WHERE
                product_id = '{pid}'
                AND is_current = true
        """)

    new_product_dim_versions_df = (
        changed_products_df.select(
            "new.product_id", "new.product_name", "new.category", "new.brand"
        )
        .withColumn("effective_date", F.current_date())
        .withColumn("end_date", F.lit("9999-12-31"))
        .withColumn("is_current", F.lit(True))
    )
# -------------------------------------------------------------------
# Build Gold Dimension Table - Dimension Date
# -------------------------------------------------------------------
dim_date_df = (
    gold_base_df.select("order_date")
    .dropDuplicates()
    .withColumn("year", F.year("order_date"))
    .withColumn("month", F.month("order_date"))
    .withColumn("quarter", F.quarter("order_date"))
)

# -------------------------------------------------------------------
# STEP 4: Build Gold Table - Category Sales
# -------------------------------------------------------------------
# Aggregation level:
# - one row per order_date + category
#
# Measures:
# - total_orders
# - total_quantity
# - total_sales
#
# This table is useful for:
# - daily category-wise reporting
# - management summary
# - comparing category performance
# -------------------------------------------------------------------
category_sales_df = gold_base_df.groupBy(F.col("order_date"), F.col("category")).agg(
    F.countDistinct("order_id").cast("int").alias("total_orders"),
    F.sum("quantity").cast("int").alias("total_quantity"),
    F.round(F.sum("order_amount"), 2).cast("double").alias("total_sales"),
)

category_sales_df = category_sales_df.withColumn("pipeline_run_id", F.lit(pipeline_run_id))

# ---------------------------------------------------------------
# CREATE ICEBERG TABLES IF THEY DO NOT EXIST And WRITE INTO
# ---------------------------------------------------------------

try:
    daily_product_sales_df.writeTo("glue_catalog.veeradb_iceberg.daily_product_sales").using(
        "iceberg"
    ).create()
except:
    daily_product_sales_df.writeTo("glue_catalog.veeradb_iceberg.daily_product_sales").append()

try:
    category_sales_df.writeTo("glue_catalog.veeradb_iceberg.category_sales").using(
        "iceberg"
    ).create()
except:
    category_sales_df.writeTo("glue_catalog.veeradb_iceberg.category_sales").append()

try:
    fact_sales_df.writeTo("glue_catalog.veeradb_iceberg.fact_sales").using("iceberg").create()
except:
    fact_sales_df.writeTo("glue_catalog.veeradb_iceberg.fact_sales").append()

try:
    new_product_dim_versions_df.writeTo("glue_catalog.veeradb_iceberg.dim_product").using(
        "iceberg"
    ).create()
except:
    new_product_dim_versions_df.writeTo("glue_catalog.veeradb_iceberg.dim_product").append()

try:
    dim_date_df.writeTo("glue_catalog.veeradb_iceberg.dim_date").using("iceberg").create()
except:
    dim_date_df.writeTo("glue_catalog.veeradb_iceberg.dim_date").append()
# -------------------------------------------------------------------
# STEP 5: Write Gold Daily Product Sales
# -------------------------------------------------------------------
# Output path:
# s3://.../gold/daily_product_sales/
# We partition by order_date because Gold is a reporting layer,
# and date-wise partitioning makes the data easier to query and refresh.
# Overwrite mode + dynamic partition overwrite:
# only affected partitions get refreshed.
# -------------------------------------------------------------------
daily_product_sales_df.write.mode("overwrite").format("parquet").partitionBy("order_date").save(
    gold_daily_product_sales_path
)

# -------------------------------------------------------------------
# STEP 6: Write Gold Category Sales
# -------------------------------------------------------------------
# Output path:
# s3://.../gold/category_sales/
# -------------------------------------------------------------------
category_sales_df.write.mode("overwrite").format("parquet").partitionBy("order_date").save(
    gold_category_sales_path
)

# -------------------------------------------------------------------
# Write Gold Fact Sales, Dimension Product ,Dimension Date
# -------------------------------------------------------------------
fact_sales_df.write.mode("overwrite").partitionBy("order_date").parquet(
    "s3://veera-crm-healthcare-pipeline/gold/star/fact_sales/"
)

if current_dim_product_df is None:
    dim_product_df.write.mode("overwrite").parquet(
        "s3://veera-crm-healthcare-pipeline/gold/star/dim_product/"
    )
else:
    current_snapshot_df = spark.table("glue_catalog.veeradb_iceberg.dim_product").filter(
        F.col("is_current") == True
    )
    current_snapshot_df.write.mode("overwrite").parquet(
        "s3://veera-crm-healthcare-pipeline/gold/star/dim_product/"
    )

dim_date_df.write.mode("overwrite").parquet(
    "s3://veera-crm-healthcare-pipeline/gold/star/dim_date/"
)

# -------------------------------------------------------------------
# Commit Glue job
# -------------------------------------------------------------------
job.commit()
