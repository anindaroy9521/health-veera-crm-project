###############################################################
# KMS Key for SNS Encryption
###############################################################

resource "aws_kms_key" "sns" {

  description             = "KMS key for SNS topic encryption"

  deletion_window_in_days = 7

  enable_key_rotation     = true

  tags = local.common_tags

}

resource "aws_kms_alias" "sns" {

  name          = "alias/veera-sns"

  target_key_id = aws_kms_key.sns.key_id

}

###############################################################
# SNS Topic
###############################################################

resource "aws_sns_topic" "alerts" {

  name = "veera-pipeline-alerts"

  kms_master_key_id = aws_kms_key.sns.arn

  tags = merge(
    local.common_tags,
    {
      Name = "veera-pipeline-alerts"
    }
  )

}

###############################################################
# Email Subscription
###############################################################

resource "aws_sns_topic_subscription" "email" {

  topic_arn = aws_sns_topic.alerts.arn

  protocol = "email"

  endpoint = var.notification_email

}

###############################################################
# SNS Topic Policy
###############################################################

data "aws_iam_policy_document" "sns_topic_policy" {

  statement {

    sid = "AllowCloudWatch"

    effect = "Allow"

    principals {

      type = "Service"

      identifiers = [
        "cloudwatch.amazonaws.com"
      ]

    }

    actions = [

      "SNS:Publish"

    ]

    resources = [

      aws_sns_topic.alerts.arn

    ]

  }

  statement {

    sid = "AllowStepFunctions"

    effect = "Allow"

    principals {

      type = "Service"

      identifiers = [
        "states.amazonaws.com"
      ]

    }

    actions = [

      "SNS:Publish"

    ]

    resources = [

      aws_sns_topic.alerts.arn

    ]

  }

}
resource "aws_sns_topic_policy" "alerts" {

  arn = aws_sns_topic.alerts.arn

  policy = data.aws_iam_policy_document.sns_topic_policy.json

}