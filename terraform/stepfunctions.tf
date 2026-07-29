###############################################################
# Step Function Logs
###############################################################

resource "aws_cloudwatch_log_group" "stepfunctions" {

  name              = "/aws/vendedlogs/states/veera-medallion"

  retention_in_days = 30

}

locals {

  step_function_definition = templatefile(
    "${path.module}/statemachine/medallion_pipeline.asl.json",
    {

      raw_to_bronze_job = aws_glue_job.raw_to_bronze.name

      bronze_to_silver_job = aws_glue_job.bronze_to_silver.name

      silver_to_gold_job = aws_glue_job.silver_to_gold.name

      ai_lambda = aws_lambda_alias.bedrock_prod.arn

      sns_topic = aws_sns_topic.alerts.arn

    }
  )

}

resource "aws_sfn_state_machine" "medallion_pipeline" {

  name = "veera-medallion"

  role_arn = aws_iam_role.stepfunctions_role.arn

  definition = local.step_function_definition

  publish = true

  logging_configuration {

      level = "ALL"

      include_execution_data = true

      log_destination = "${aws_cloudwatch_log_group.stepfunctions.arn}:*"

  }

  tracing_configuration {

      enabled = true

  }

  tags = local.common_tags

}

resource "aws_sfn_alias" "prod" {

  name = "prod"

  routing_configuration {

      state_machine_version_arn = aws_sfn_state_machine.medallion_pipeline.state_machine_version_arn

      weight = 100

  }

}

tracing_configuration {

    enabled = true

}