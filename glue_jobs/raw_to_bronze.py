import sys
from datetime import datetime

from awsglue.utils import getResolvedOptions
from awsglue.context import GlueContext
from awsglue.job import Job

from pyspark.context import SparkContext
from pyspark.sql.functions import (
    input_file_name,
    current_timestamp,
    lit,
    regexp_extract
)

# -------------------------------------------------------------------
# Expected job arguments
# -------------------------------------------------------------------
# Required:
# --JOB_NAME
# --BRONZE_ORDERS_TARGET_PATH
# --BRONZE_PRODUCTS_TARGET_PATH
# --PIPELINE_RUN_ID
# --LOAD_DATE_MODE
# --SOURCE_FILE_PATH
# --ENTITY_TYPE
# --FILE_TYPE
#
# Optional:
# --LOAD_DATE_VALUE   -> used only when LOAD_DATE_MODE = STATIC


args = getResolvedOptions(
    sys.argv,
    [
        "JOB_NAME",
        "SOURCE_FILE_PATH",
        "BRONZE_ORDERS_TARGET_PATH",
        "BRONZE_PRODUCTS_TARGET_PATH",
        "PIPELINE_RUN_ID",
        "LOAD_DATE_MODE",
        "FILE_TYPE",
        "ENTITY_TYPE"
    ]
)

# Optional argument handling
load_date_value = None
if "--LOAD_DATE_VALUE" in sys.argv:
    extra_args = getResolvedOptions(sys.argv, ["LOAD_DATE_VALUE"])
    load_date_value = extra_args["LOAD_DATE_VALUE"]

sc = SparkContext()
glue_context = GlueContext(sc)
spark = glue_context.spark_session
job = Job(glue_context)
job.init(args["JOB_NAME"], args)

source_file_path = args["SOURCE_FILE_PATH"]
bronze_orders_target_path = args["BRONZE_ORDERS_TARGET_PATH"]
bronze_products_target_path = args["BRONZE_PRODUCTS_TARGET_PATH"]
pipeline_run_id = args["PIPELINE_RUN_ID"]
load_date_mode = args["LOAD_DATE_MODE"]
entity_type = args["ENTITY_TYPE"]
file_type = args["FILE_TYPE"]


def add_metadata_columns(raw_df):
    df = (
        raw_df.withColumn(
            "source_file_name",
            regexp_extract(input_file_name(), r"([^/]+$)", 1)
        )
        .withColumn("ingestion_timestamp", current_timestamp())
        .withColumn("pipeline_run_id", lit(pipeline_run_id))
    )

    if load_date_mode == "FROM_PATH":
        df = df.withColumn(
            "load_date",
            regexp_extract(
                input_file_name(),
                r"load_date=([0-9]{4}-[0-9]{2}-[0-9]{2})",
                1
            )
        )

    elif load_date_mode == "STATIC":
        if not load_date_value:
            raise ValueError("LOAD_DATE_VALUE is required when LOAD_DATE_MODE = STATIC")
        df = df.withColumn("load_date", lit(load_date_value))

    elif load_date_mode == "CURRENT_DATE":
        current_date_str = datetime.now().strftime("%Y-%m-%d")
        df = df.withColumn("load_date", lit(current_date_str))

    else:
        raise ValueError("LOAD_DATE_MODE must be one of: FROM_PATH, STATIC, CURRENT_DATE")

    return df


# -------------------------------------------------------------------
# Read raw JSON
# -------------------------------------------------------------------

source_file_path = args["SOURCE_FILE_PATH"]
entity_type = args["ENTITY_TYPE"]
file_type = args["FILE_TYPE"]

if file_type.lower() == "json":
    try:
        raw_df = spark.read.json(source_file_path)
        if raw_df.count() == 0:
            raise Exception()
    except:
        raw_df = spark.read \
            .option("multiLine", "true") \
            .json(source_file_path)
            
elif file_type.lower() == "csv":

    raw_df = spark.read \
        .option("header", "true") \
        .option("inferSchema", "true") \
        .csv(source_file_path)

else:
    raise Exception(f"Unsupported file type: {file_type}")
    
bronze_df = add_metadata_columns(raw_df)

# -------------------------------------------------------------------
# Write Bronze as Parquet
# -------------------------------------------------------------------
if entity_type == "orders":

    bronze_df.write \
        .mode("append") \
        .format("parquet") \
        .partitionBy("load_date") \
        .save(bronze_orders_target_path)

elif entity_type == "products":

    bronze_df.write \
        .mode("append") \
        .format("parquet") \
        .partitionBy("load_date") \
        .save(bronze_products_target_path)

else:
    raise ValueError(f"Unsupported entity type: {entity_type}")

job.commit()