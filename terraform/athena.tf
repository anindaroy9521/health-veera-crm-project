###############################################################
# Athena Query Results Bucket
###############################################################

resource "aws_s3_bucket" "athena_results" {

  bucket = "${var.project_name}-${var.environment}-athena-results"

  tags = merge(
    local.common_tags,
    {
      Name = "Athena Query Results"
    }
  )
}

resource "aws_s3_bucket_server_side_encryption_configuration" "athena_results" {

  bucket = aws_s3_bucket.athena_results.id

  rule {

    apply_server_side_encryption_by_default {

      sse_algorithm = "AES256"

    }

  }

}

resource "aws_s3_bucket_public_access_block" "athena_results" {

  bucket = aws_s3_bucket.athena_results.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

}

###############################################################
# Athena Workgroup
###############################################################

resource "aws_athena_workgroup" "analytics" {

  name = "veera-analytics"

  state = "ENABLED"

  force_destroy = true

  configuration {

    enforce_workgroup_configuration = true

    publish_cloudwatch_metrics_enabled = true

    bytes_scanned_cutoff_per_query = 10737418240   # 10 GB

    result_configuration {

      output_location = "s3://${aws_s3_bucket.athena_results.bucket}/results/"

      encryption_configuration {

        encryption_option = "SSE_KMS"

        kms_key_arn = aws_kms_key.analytics.arn

      }

    }

  }

}

###############################################################
# Daily Sales Query
###############################################################

resource "aws_athena_named_query" "daily_sales" {

  name = "Daily Product Sales"

  database = aws_glue_catalog_database.medallion.name

  workgroup = aws_athena_workgroup.analytics.name

  query = <<EOF

SELECT
    sale_date,
    product_name,
    SUM(total_amount) AS revenue
FROM daily_product_sales
GROUP BY sale_date, product_name
ORDER BY sale_date DESC;

EOF

}

resource "aws_athena_named_query" "top_customers" {

  name = "Top Customers"

  database = aws_glue_catalog_database.medallion.name

  workgroup = aws_athena_workgroup.analytics.name

  query = <<EOF

SELECT
customer_id,
SUM(total_amount) revenue
FROM fact_orders
GROUP BY customer_id
ORDER BY revenue DESC
LIMIT 20;

EOF

}

output "athena_workgroup" {

  value = aws_athena_workgroup.analytics.name

}

output "athena_results_bucket" {

  value = aws_s3_bucket.athena_results.bucket

}