###############################################################
# S3 Bucket
###############################################################

resource "aws_s3_bucket" "data_lake" {

  bucket = var.bucket_name

  tags = merge(
    local.common_tags,
    {
      Name = var.bucket_name
    }
  )
}

###############################################################
# Versioning
###############################################################

resource "aws_s3_bucket_versioning" "versioning" {

  bucket = aws_s3_bucket.data_lake.id

  versioning_configuration {
    status = "Enabled"
  }

}

###############################################################
# Server Side Encryption
###############################################################

resource "aws_s3_bucket_server_side_encryption_configuration" "encryption" {

  bucket = aws_s3_bucket.data_lake.id

  rule {

    apply_server_side_encryption_by_default {

      sse_algorithm = "AES256"

    }

  }

}

###############################################################
# Public Access Block
###############################################################

resource "aws_s3_bucket_public_access_block" "public_access" {

  bucket = aws_s3_bucket.data_lake.id

  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true

}

###############################################################
# Bucket Lifecycle
###############################################################

resource "aws_s3_bucket_lifecycle_configuration" "lifecycle" {

  bucket = aws_s3_bucket.data_lake.id

  rule {

    id = "ArchiveOldRawFiles"

    status = "Enabled"

    filter {
      prefix = "raw/"
    }

    transition {

      days          = 90
      storage_class = "STANDARD_IA"

    }

    expiration {

      days = 365

    }

  }

}

###############################################################
# Folder Structure
###############################################################

resource "aws_s3_object" "folders" {

  for_each = toset([

    "raw/",

    "bronze/",

    "bronze/orders/",

    "bronze/products/",

    "silver/",

    "silver/orders_curated/",

    "silver/rejected_orders/",

    "silver/rejected_products/",

    "gold/",

    "gold/category_sales/",

    "gold/daily_product_sales/",

    "gold/star_schema/",

    "gold/audit_json/",

    "gold/ai_pipeline_analysis/"

  ])

  bucket = aws_s3_bucket.data_lake.id

  key = each.value

  content = ""

}

###############################################################
# Bucket Policy
###############################################################

data "aws_iam_policy_document" "bucket_policy" {

  statement {

    sid = "DenyInsecureTransport"

    effect = "Deny"

    principals {

      type = "*"

      identifiers = ["*"]

    }

    actions = [
      "s3:*"
    ]

    resources = [

      aws_s3_bucket.data_lake.arn,

      "${aws_s3_bucket.data_lake.arn}/*"

    ]

    condition {

      test = "Bool"

      variable = "aws:SecureTransport"

      values = [
        "false"
      ]

    }

  }

}

resource "aws_s3_bucket_policy" "policy" {

  bucket = aws_s3_bucket.data_lake.id

  policy = data.aws_iam_policy_document.bucket_policy.json

}