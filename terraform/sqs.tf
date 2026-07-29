###############################################################
# Dead Letter Queue
###############################################################

resource "aws_sqs_queue" "ingestion_dlq" {

  name = "veera-ingestion-dlq"

  message_retention_seconds = 1209600   # 14 Days

  visibility_timeout_seconds = 60

  receive_wait_time_seconds = 20

  sqs_managed_sse_enabled = true

  tags = merge(
    local.common_tags,
    {
      Name = "veera-ingestion-dlq"
    }
  )
}

###############################################################
# Main Queue
###############################################################

resource "aws_sqs_queue" "ingestion_queue" {

  name = "veera-ingestion-queue"

  visibility_timeout_seconds = 300

  message_retention_seconds = 345600    # 4 Days

  receive_wait_time_seconds = 20

  delay_seconds = 0

  max_message_size = 262144

  sqs_managed_sse_enabled = true

  redrive_policy = jsonencode({

    deadLetterTargetArn = aws_sqs_queue.ingestion_dlq.arn

    maxReceiveCount = 5

  })

  tags = merge(
    local.common_tags,
    {
      Name = "veera-ingestion-queue"
    }
  )

}

###############################################################
# Queue Policy
###############################################################

data "aws_iam_policy_document" "queue_policy" {

  statement {

    sid = "AllowProducerLambda"

    effect = "Allow"

    principals {

      type = "AWS"

      identifiers = [
        aws_iam_role.producer_lambda_role.arn
      ]

    }

    actions = [

      "sqs:SendMessage"

    ]

    resources = [

      aws_sqs_queue.ingestion_queue.arn

    ]

  }

}
resource "aws_sqs_queue_policy" "queue_policy" {

  queue_url = aws_sqs_queue.ingestion_queue.id

  policy = data.aws_iam_policy_document.queue_policy.json

}

###############################################################
# Queue Depth Alarm
###############################################################

resource "aws_cloudwatch_metric_alarm" "queue_depth_alarm" {

  alarm_name = "veera-sqs-queue-depth"

  comparison_operator = "GreaterThanThreshold"

  evaluation_periods = 1

  metric_name = "ApproximateNumberOfMessagesVisible"

  namespace = "AWS/SQS"

  period = 300

  statistic = "Average"

  threshold = 100

  alarm_description = "Too many messages waiting in SQS."

  dimensions = {

    QueueName = aws_sqs_queue.ingestion_queue.name

  }

  alarm_actions = [

    aws_sns_topic.alerts.arn

  ]

}

###############################################################
# DLQ Alarm
###############################################################

resource "aws_cloudwatch_metric_alarm" "dlq_alarm" {

  alarm_name = "veera-dlq-alarm"

  comparison_operator = "GreaterThanThreshold"

  evaluation_periods = 1

  metric_name = "ApproximateNumberOfMessagesVisible"

  namespace = "AWS/SQS"

  period = 300

  statistic = "Average"

  threshold = 1

  alarm_description = "Messages detected in Dead Letter Queue."

  dimensions = {

    QueueName = aws_sqs_queue.ingestion_dlq.name

  }

  alarm_actions = [

    aws_sns_topic.alerts.arn

  ]

}