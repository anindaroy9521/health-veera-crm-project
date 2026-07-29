###############################################################
# Glue IAM Role
###############################################################

data "aws_iam_policy_document" "glue_assume_role" {

  statement {

    actions = ["sts:AssumeRole"]

    principals {

      type = "Service"

      identifiers = [
        "glue.amazonaws.com"
      ]

    }

  }

}

resource "aws_iam_role" "glue_role" {

  name = "veera-glue-role"

  assume_role_policy = data.aws_iam_policy_document.glue_assume_role.json

  tags = local.common_tags

}

resource "aws_iam_policy" "glue_policy" {

  name = "veera-glue-policy"

  policy = jsonencode({

    Version = "2012-10-17"

    Statement = [

      {

        Effect = "Allow"

        Action = [

          "s3:*"

        ]

        Resource = [

          aws_s3_bucket.data_lake.arn,

          "${aws_s3_bucket.data_lake.arn}/*"

        ]

      },

      {

        Effect = "Allow"

        Action = [

          "logs:*"

        ]

        Resource = "*"

      },

      {

        Effect = "Allow"

        Action = [

          "glue:*"

        ]

        Resource = "*"

      },

      {

        Effect = "Allow"

        Action = [

          "sns:Publish"

        ]

        Resource = "*"

      }

    ]

  })

}

resource "aws_iam_role_policy_attachment" "glue_attach" {

  role = aws_iam_role.glue_role.name

  policy_arn = aws_iam_policy.glue_policy.arn

}

###############################################################
# Producer Lambda Role
###############################################################

data "aws_iam_policy_document" "lambda_assume_role" {

  statement {

    actions = ["sts:AssumeRole"]

    principals {

      type = "Service"

      identifiers = [
        "lambda.amazonaws.com"
      ]

    }

  }

}

resource "aws_iam_role" "producer_lambda_role" {

  name = "producer-lambda-role"

  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json

}

resource "aws_iam_policy" "producer_policy" {

  name = "producer-lambda-policy"

  policy = jsonencode({

    Version = "2012-10-17"

    Statement = [

      {

        Effect = "Allow"

        Action = [

          "s3:GetObject",

          "s3:PutObject"

        ]

        Resource = [

          "${aws_s3_bucket.data_lake.arn}/*"

        ]

      },

      {

        Effect = "Allow"

        Action = [

          "sqs:SendMessage"

        ]

        Resource = "*"

      },

      {

        Effect = "Allow"

        Action = [

          "logs:*"

        ]

        Resource = "*"

      }

    ]

  })

}

resource "aws_iam_role_policy_attachment" "producer_attach" {

  role = aws_iam_role.producer_lambda_role.name

  policy_arn = aws_iam_policy.producer_policy.arn

}

resource "aws_iam_role" "consumer_lambda_role" {

  name = "consumer-lambda-role"

  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json

}

resource "aws_iam_policy" "consumer_policy" {

  name = "consumer-policy"

  policy = jsonencode({

    Version = "2012-10-17"

    Statement = [

      {

        Effect = "Allow"

        Action = [

          "states:StartExecution"

        ]

        Resource = "*"

      },

      {

        Effect = "Allow"

        Action = [

          "sqs:ReceiveMessage",

          "sqs:DeleteMessage",

          "sqs:GetQueueAttributes"

        ]

        Resource = "*"

      },

      {

        Effect = "Allow"

        Action = [

          "logs:*"

        ]

        Resource = "*"

      }

    ]

  })

}

resource "aws_iam_role_policy_attachment" "consumer_attach" {

  role = aws_iam_role.consumer_lambda_role.name

  policy_arn = aws_iam_policy.consumer_policy.arn

}

resource "aws_iam_role" "bedrock_lambda_role" {

  name = "bedrock-lambda-role"

  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json

}


resource "aws_iam_policy" "bedrock_policy" {

  name = "bedrock-policy"

  policy = jsonencode({

    Version = "2012-10-17"

    Statement = [

      {

        Effect = "Allow"

        Action = [

          "bedrock:InvokeModel"

        ]

        Resource = "*"

      },

      {

        Effect = "Allow"

        Action = [

          "s3:GetObject",

          "s3:PutObject"

        ]

        Resource = [

          "${aws_s3_bucket.data_lake.arn}/*"

        ]

      },

      {

        Effect = "Allow"

        Action = [

          "logs:*"

        ]

        Resource = "*"

      }

    ]

  })

}

resource "aws_iam_role_policy_attachment" "bedrock_attach" {

  role = aws_iam_role.bedrock_lambda_role.name

  policy_arn = aws_iam_policy.bedrock_policy.arn

}

data "aws_iam_policy_document" "stepfunctions_assume_role" {

  statement {

    actions = ["sts:AssumeRole"]

    principals {

      type = "Service"

      identifiers = [
        "states.amazonaws.com"
      ]

    }

  }

}

resource "aws_iam_role" "stepfunctions_role" {

  name = "veera-stepfunctions-role"

  assume_role_policy = data.aws_iam_policy_document.stepfunctions_assume_role.json

}

resource "aws_iam_policy" "stepfunctions_policy" {

  name = "stepfunctions-policy"

  policy = jsonencode({

    Version = "2012-10-17"

    Statement = [

      {

        Effect = "Allow"

        Action = [

          "glue:StartJobRun",

          "glue:GetJobRun",

          "glue:GetJobRuns"

        ]

        Resource = "*"

      },

      {

        Effect = "Allow"

        Action = [

          "lambda:InvokeFunction"

        ]

        Resource = "*"

      },

      {

        Effect = "Allow"

        Action = [

          "sns:Publish"

        ]

        Resource = "*"

      }

    ]

  })

}

resource "aws_iam_role_policy_attachment" "stepfunctions_attach" {

  role = aws_iam_role.stepfunctions_role.name

  policy_arn = aws_iam_policy.stepfunctions_policy.arn

}