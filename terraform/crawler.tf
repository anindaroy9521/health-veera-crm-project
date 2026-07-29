###############################################################
# Bronze Crawler
###############################################################

resource "aws_glue_crawler" "bronze" {

  name          = "veera-bronze-crawler"
  role          = aws_iam_role.glue_role.arn
  database_name = aws_glue_catalog_database.medallion.name

  s3_target {
    path = "s3://${aws_s3_bucket.data_lake.bucket}/bronze/"
  }

  table_prefix = "bronze_"

  schema_change_policy {
    update_behavior = "UPDATE_IN_DATABASE"
    delete_behavior = "LOG"
  }

  recrawl_policy {
    recrawl_behavior = "CRAWL_NEW_FOLDERS_ONLY"
  }

  configuration = jsonencode({
    Version = 1.0
    CrawlerOutput = {
      Partitions = {
        AddOrUpdateBehavior = "InheritFromTable"
      }
    }
  })

  tags = local.common_tags
}

###############################################################
# Silver Crawler
###############################################################

resource "aws_glue_crawler" "silver" {

  name          = "veera-silver-crawler"
  role          = aws_iam_role.glue_role.arn
  database_name = aws_glue_catalog_database.medallion.name

  s3_target {
    path = "s3://${aws_s3_bucket.data_lake.bucket}/silver/"
  }

  table_prefix = "silver_"

  schema_change_policy {
    update_behavior = "UPDATE_IN_DATABASE"
    delete_behavior = "LOG"
  }

  recrawl_policy {
    recrawl_behavior = "CRAWL_NEW_FOLDERS_ONLY"
  }

  configuration = jsonencode({
    Version = 1.0
    CrawlerOutput = {
      Partitions = {
        AddOrUpdateBehavior = "InheritFromTable"
      }
    }
  })

  tags = local.common_tags
}

s3_target {

  path = "s3://${aws_s3_bucket.data_lake.bucket}/silver/"

  exclusions = [

    "**/_temporary/**",

    "**/_SUCCESS",

    "**/*.crc"

  ]
}

schedule = "cron(0 * * * ? *)"