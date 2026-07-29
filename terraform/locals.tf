locals {

  common_tags = {

    Project     = var.project_name
    Environment = var.environment
    Owner       = "Aninda Roy"

  }

  raw_prefix = "raw/"

  bronze_prefix = "bronze/"

  silver_prefix = "silver/"

  gold_prefix = "gold/"

  audit_prefix = "gold/audit_json/"

  ai_prefix = "gold/ai_pipeline_analysis/"

}