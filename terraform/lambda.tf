###############################################################
# Producer Lambda
###############################################################

resource "aws_lambda_function" "producer" {

  function_name = "producer-lambda"

  role = aws_iam_role.producer_lambda_role.arn

  runtime = var.lambda_runtime

  handler = "producer_lambda.lambda_handler"

  filename = "${path.module}/build/producer.zip"

  source_code_hash = filebase64sha256("${path.module}/build/producer.zip")

  timeout = 60

  memory_size = 256

  environment {

    variables = {

      QUEUE_URL = aws_sqs_queue.ingestion_queue.url

    }

  }

  tags = local.common_tags

}

###############################################################
# Consumer Lambda
###############################################################

resource "aws_lambda_function" "consumer" {

  function_name = "consumer-lambda"

  role = aws_iam_role.consumer_lambda_role.arn

  runtime = var.lambda_runtime

  handler = "consumer_lambda.lambda_handler"

  filename = "${path.module}/build/consumer.zip"

  source_code_hash = filebase64sha256("${path.module}/build/consumer.zip")

  timeout = 120

  memory_size = 512

  environment {

    variables = {

      STEP_FUNCTION_ARN = aws_sfn_state_machine.medallion_pipeline.arn

    }

  }

  tags = local.common_tags

}

###############################################################
# Bedrock AI Lambda
###############################################################

resource "aws_lambda_function" "bedrock" {

  function_name = "bedrock-dq-analyzer"

  role = aws_iam_role.bedrock_lambda_role.arn

  runtime = var.lambda_runtime

  handler = "bedrock_dq_analyzer.lambda_handler"

  filename = "${path.module}/build/bedrock.zip"

  source_code_hash = filebase64sha256("${path.module}/build/bedrock.zip")

  timeout = 300

  memory_size = 1024

  environment {

    variables = {

      BUCKET_NAME = aws_s3_bucket.data_lake.bucket

      MODEL_ID = "anthropic.claude-3-5-sonnet-20240620-v1:0"

      OUTPUT_PREFIX = "gold/ai_pipeline_analysis/"

    }

  }

  tags = local.common_tags

}

resource "aws_cloudwatch_log_group" "producer_logs" {

  name = "/aws/lambda/producer-lambda"

  retention_in_days = 30

}

resource "aws_cloudwatch_log_group" "consumer_logs" {

  name = "/aws/lambda/consumer-lambda"

  retention_in_days = 30

}

resource "aws_cloudwatch_log_group" "bedrock_logs" {

  name = "/aws/lambda/bedrock-dq-analyzer"

  retention_in_days = 30

}

resource "aws_lambda_event_source_mapping" "consumer_trigger" {

  event_source_arn = aws_sqs_queue.ingestion_queue.arn

  function_name = aws_lambda_function.consumer.arn

  batch_size = 10

  enabled = true

}

resource "aws_lambda_permission" "allow_s3" {

  statement_id = "AllowExecutionFromS3"

  action = "lambda:InvokeFunction"

  function_name = aws_lambda_function.producer.function_name

  principal = "s3.amazonaws.com"

  source_arn = aws_s3_bucket.data_lake.arn

}