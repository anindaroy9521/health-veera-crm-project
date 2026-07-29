variable "project_name" {

  type = string

  default = "veera-healthcare"

}

variable "environment" {

  type = string

  default = "dev"

}

variable "aws_region" {

  type = string

  default = "us-east-1"

}

variable "bucket_name" {

  type = string

  default = "veera-crm-healthcare-pipeline"

}

variable "lambda_runtime" {

  type = string

  default = "python3.12"

}

variable "glue_version" {

  type = string

  default = "5.0"

}

variable "notification_email" {

  type = string

}