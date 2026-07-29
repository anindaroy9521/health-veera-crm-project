import json
import logging
import os

import boto3
from botocore.exceptions import ClientError

# -------------------------------------------------------------
# Logging
# -------------------------------------------------------------
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# -------------------------------------------------------------
# AWS Clients
# -------------------------------------------------------------
s3 = boto3.client("s3")

bedrock = boto3.client(
    service_name="bedrock-runtime", region_name=os.environ.get("AWS_REGION", "us-east-1")
)

# -------------------------------------------------------------
# Configuration
# -------------------------------------------------------------
BUCKET_NAME = "veera-crm-healthcare-pipeline"

AUDIT_PREFIX = "gold/audit_json/"

OUTPUT_PREFIX = "gold/ai_pipeline_analysis/"

MODEL_ID = "anthropic.claude-3-5-sonnet-20240620-v1:0"


# -------------------------------------------------------------
# Read Audit JSON
# -------------------------------------------------------------
def read_audit_json(bucket, key):

    response = s3.get_object(Bucket=bucket, Key=key)

    return json.loads(response["Body"].read().decode("utf-8"))


# -------------------------------------------------------------
# Build Prompt
# -------------------------------------------------------------
def build_prompt(audit):

    return f"""
You are a Senior Data Engineer responsible for monitoring
enterprise ETL pipelines.

Analyze the following pipeline execution.

Pipeline Run ID:
{audit["pipeline_run_id"]}

Raw Records:
{audit["raw_orders_count"]}

Valid Records:
{audit["valid_orders_count"]}

Rejected Records:
{audit["rejected_orders_count"]}

Duplicate Orders:
{audit["duplicate_orders_count"]}

DQ Score:
{audit["dq_score"]}

Top Rejection Reason:
{audit["top_rejection_reason"]}

Return ONLY valid JSON.

Use the following schema.

{{
 "summary":"",
 "root_cause":"",
 "business_impact":"",
 "recommendation":"",
 "priority":"Low|Medium|High"
}}

Do not include markdown.
"""


# -------------------------------------------------------------
# Invoke Bedrock
# -------------------------------------------------------------
def invoke_bedrock(prompt):

    body = {
        "anthropic_version": "bedrock-2023-05-31",
        "max_tokens": 700,
        "messages": [{"role": "user", "content": [{"type": "text", "text": prompt}]}],
    }

    response = bedrock.invoke_model(
        modelId=MODEL_ID,
        body=json.dumps(body),
        contentType="application/json",
        accept="application/json",
    )

    response_body = json.loads(response["body"].read())

    text = response_body["content"][0]["text"]

    return json.loads(text)


# -------------------------------------------------------------
# Save AI Report
# -------------------------------------------------------------
def save_ai_report(bucket, pipeline_run_id, report):

    key = f"{OUTPUT_PREFIX}{pipeline_run_id}.json"

    s3.put_object(
        Bucket=bucket, Key=key, Body=json.dumps(report, indent=4), ContentType="application/json"
    )

    logger.info(f"Saved AI report to {key}")

    return key


# -------------------------------------------------------------
# Lambda Handler
# -------------------------------------------------------------
def lambda_handler(event, context):

    logger.info(event)

    try:

        pipeline_run_id = event["pipeline_run_id"]

        audit_key = event.get("audit_json_key", f"{AUDIT_PREFIX}{pipeline_run_id}.json")

        logger.info(f"Reading {audit_key}")

        audit = read_audit_json(BUCKET_NAME, audit_key)

        prompt = build_prompt(audit)

        ai_result = invoke_bedrock(prompt)

        report = {
            "pipeline_run_id": pipeline_run_id,
            "dq_score": audit["dq_score"],
            "raw_orders_count": audit["raw_orders_count"],
            "valid_orders_count": audit["valid_orders_count"],
            "rejected_orders_count": audit["rejected_orders_count"],
            "duplicate_orders_count": audit["duplicate_orders_count"],
            "top_rejection_reason": audit["top_rejection_reason"],
            "summary": ai_result["summary"],
            "root_cause": ai_result["root_cause"],
            "business_impact": ai_result["business_impact"],
            "recommendation": ai_result["recommendation"],
            "priority": ai_result["priority"],
        }

        report_key = save_ai_report(BUCKET_NAME, pipeline_run_id, report)

        return {
            "statusCode": 200,
            "pipeline_run_id": pipeline_run_id,
            "ai_report_path": f"s3://{BUCKET_NAME}/{report_key}",
            "recommendation": report["recommendation"],
            "priority": report["priority"],
        }

    except ClientError as e:

        logger.exception(e)

        raise

    except Exception as e:

        logger.exception(e)

        raise
