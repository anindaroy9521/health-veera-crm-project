###############################################################
# Dashboard
###############################################################

resource "aws_cloudwatch_dashboard" "pipeline_dashboard" {

  dashboard_name = "veera-medallion-dashboard"

  dashboard_body = jsonencode({

    widgets = [

      {
        type = "metric"

        width = 12

        height = 6

        properties = {

          title = "Lambda Invocations"

          metrics = [

            [
              "AWS/Lambda",
              "Invocations",
              "FunctionName",
              aws_lambda_function.producer.function_name
            ],

            [
              ".",
              "Invocations",
              "FunctionName",
              aws_lambda_function.consumer.function_name
            ],

            [
              ".",
              "Invocations",
              "FunctionName",
              aws_lambda_function.bedrock.function_name
            ]

          ]

          period = 300

          stat = "Sum"

        }

      }

    ]

  })

}

resource "aws_cloudwatch_metric_alarm" "lambda_errors" {

  alarm_name = "Producer-Lambda-Errors"

  namespace = "AWS/Lambda"

  metric_name = "Errors"

  statistic = "Sum"

  period = 300

  evaluation_periods = 1

  threshold = 1

  comparison_operator = "GreaterThanOrEqualToThreshold"

  dimensions = {

      FunctionName = aws_lambda_function.producer.function_name

  }

  alarm_actions = [

      aws_sns_topic.alerts.arn

  ]

}

resource "aws_cloudwatch_metric_alarm" "lambda_duration" {

  alarm_name = "Consumer-Lambda-Duration"

  namespace = "AWS/Lambda"

  metric_name = "Duration"

  statistic = "Average"

  period = 300

  threshold = 90000

  comparison_operator = "GreaterThanThreshold"

  evaluation_periods = 1

  dimensions = {

      FunctionName = aws_lambda_function.consumer.function_name

  }

  alarm_actions = [

      aws_sns_topic.alerts.arn

  ]

}

resource "aws_cloudwatch_metric_alarm" "step_function_failures" {

  alarm_name = "StepFunctionFailures"

  namespace = "AWS/States"

  metric_name = "ExecutionsFailed"

  statistic = "Sum"

  period = 300

  threshold = 1

  evaluation_periods = 1

  comparison_operator = "GreaterThanOrEqualToThreshold"

  dimensions = {

      StateMachineArn = aws_sfn_state_machine.medallion_pipeline.arn

  }

  alarm_actions = [

      aws_sns_topic.alerts.arn

  ]

}

resource "aws_cloudwatch_metric_alarm" "step_timeout" {

  alarm_name = "PipelineTimeout"

  namespace = "AWS/States"

  metric_name = "ExecutionsTimedOut"

  statistic = "Sum"

  period = 300

  threshold = 1

  evaluation_periods = 1

  comparison_operator = "GreaterThanOrEqualToThreshold"

  dimensions = {

      StateMachineArn = aws_sfn_state_machine.medallion_pipeline.arn

  }

  alarm_actions = [

      aws_sns_topic.alerts.arn

  ]

}

resource "aws_cloudwatch_metric_alarm" "glue_failures" {

  alarm_name = "GlueJobFailures"

  namespace = "AWS/Glue"

  metric_name = "glue.driver.aggregate.numFailedTasks"

  statistic = "Sum"

  period = 300

  threshold = 1

  evaluation_periods = 1

  comparison_operator = "GreaterThanOrEqualToThreshold"

  alarm_actions = [

      aws_sns_topic.alerts.arn

  ]

}

resource "aws_cloudwatch_metric_alarm" "glue_runtime" {

  alarm_name = "GlueJobRuntime"

  namespace = "Glue"

  metric_name = "ExecutionTime"

  statistic = "Average"

  period = 300

  threshold = 7200

  evaluation_periods = 1

  comparison_operator = "GreaterThanThreshold"

  alarm_actions = [

      aws_sns_topic.alerts.arn

  ]

}

resource "aws_cloudwatch_log_metric_filter" "bedrock_errors" {

  name = "BedrockErrors"

  log_group_name = aws_cloudwatch_log_group.bedrock_logs.name

  pattern = "ERROR"

  metric_transformation {

      name = "BedrockErrors"

      namespace = "Custom/Pipeline"

      value = "1"

  }

}