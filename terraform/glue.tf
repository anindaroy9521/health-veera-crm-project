###############################################################
# Glue Catalog Database
###############################################################

resource "aws_glue_catalog_database" "medallion" {

  name = "veera_medallion"

}

###############################################################
# Raw -> Bronze Script
###############################################################

resource "aws_s3_object" "raw_to_bronze_script" {

  bucket = aws_s3_bucket.data_lake.id

  key = "glue/scripts/raw_to_bronze.py"

  source = "${path.module}/../glue_scripts/raw_to_bronze.py"

  etag = filemd5("${path.module}/../glue_scripts/raw_to_bronze.py")

}

###############################################################
# Bronze -> Silver
###############################################################

resource "aws_s3_object" "bronze_to_silver_script" {

  bucket = aws_s3_bucket.data_lake.id

  key = "glue/scripts/bronze_to_silver.py"

  source = "${path.module}/../glue_scripts/bronze_to_silver.py"

  etag = filemd5("${path.module}/../glue_scripts/bronze_to_silver.py")

}

###############################################################
# Silver -> Gold
###############################################################

resource "aws_s3_object" "silver_to_gold_script" {

  bucket = aws_s3_bucket.data_lake.id

  key = "glue/scripts/silver_to_gold.py"

  source = "${path.module}/../glue_scripts/silver_to_gold.py"

  etag = filemd5("${path.module}/../glue_scripts/silver_to_gold.py")

}

resource "aws_glue_job" "raw_to_bronze" {

  name = "raw-to-bronze"

  role_arn = aws_iam_role.glue_role.arn

  glue_version = "5.0"

  worker_type = "G.1X"

  number_of_workers = 2

  timeout = 60

  max_retries = 1

  command {

    script_location = "s3://${aws_s3_bucket.data_lake.bucket}/${aws_s3_object.raw_to_bronze_script.key}"

    python_version = "3"

  }

  execution_property {

    max_concurrent_runs = 3

  }

  default_arguments = {

    "--job-language" = "python"

    "--enable-job-insights" = "true"

    "--enable-metrics" = "true"

    "--enable-observability-metrics" = "true"

    "--enable-continuous-cloudwatch-log" = "true"

    "--job-bookmark-option" = "job-bookmark-enable"

    "--TempDir" = "s3://${aws_s3_bucket.data_lake.bucket}/temp/"

  }

}

resource "aws_glue_job" "bronze_to_silver" {

  name = "bronze-to-silver"

  role_arn = aws_iam_role.glue_role.arn

  glue_version = "5.0"

  worker_type = "G.2X"

  number_of_workers = 4

  timeout = 90

  command {

      script_location = "s3://${aws_s3_bucket.data_lake.bucket}/${aws_s3_object.bronze_to_silver_script.key}"

      python_version = "3"

  }

  default_arguments = {

      "--job-bookmark-option" = "job-bookmark-enable"

      "--enable-job-insights" = "true"

      "--enable-metrics" = "true"

      "--enable-observability-metrics" = "true"

      "--enable-continuous-cloudwatch-log" = "true"

      "--TempDir" = "s3://${aws_s3_bucket.data_lake.bucket}/temp/"

  }

}

resource "aws_glue_job" "silver_to_gold" {

  name = "silver-to-gold"

  role_arn = aws_iam_role.glue_role.arn

  glue_version = "5.0"

  worker_type = "G.2X"

  number_of_workers = 5

  timeout = 120

  command {

      script_location = "s3://${aws_s3_bucket.data_lake.bucket}/${aws_s3_object.silver_to_gold_script.key}"

      python_version = "3"

  }

  default_arguments = {

      "--enable-job-insights" = "true"

      "--enable-metrics" = "true"

      "--enable-observability-metrics" = "true"

      "--enable-continuous-cloudwatch-log" = "true"

      "--job-bookmark-option" = "job-bookmark-enable"

      "--TempDir" = "s3://${aws_s3_bucket.data_lake.bucket}/temp/"

  }

}

resource "aws_glue_security_configuration" "glue_security" {

  name = "veera-glue-security"

  encryption_configuration {

    cloudwatch_encryption {

      cloudwatch_encryption_mode = "SSE-KMS"

      kms_key_arn = aws_kms_key.sns.arn

    }

    s3_encryption {

      s3_encryption_mode = "SSE-KMS"

      kms_key_arn = aws_kms_key.sns.arn

    }

  }

}
security_configuration = aws_glue_security_configuration.glue_security.name

default_arguments = {

  "--datalake-formats" = "iceberg"

  "--conf" = join(" ", [
    "spark.sql.extensions=org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions",
    "spark.sql.catalog.glue_catalog=org.apache.iceberg.spark.SparkCatalog",
    "spark.sql.catalog.glue_catalog.catalog-impl=org.apache.iceberg.aws.glue.GlueCatalog",
    "spark.sql.catalog.glue_catalog.io-impl=org.apache.iceberg.aws.s3.S3FileIO",
    "spark.sql.catalog.glue_catalog.warehouse=s3://${aws_s3_bucket.data_lake.bucket}/gold/"
  ])

}

"--enable-job-insights"             = "true"
"--enable-metrics"                  = "true"
"--enable-observability-metrics"    = "true"
"--enable-spark-ui"                 = "true"
"--spark-event-logs-path"           = "s3://${aws_s3_bucket.data_lake.bucket}/spark-history/"