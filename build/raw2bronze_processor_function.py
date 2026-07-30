import hashlib
import json

import boto3
from botocore.exceptions import ClientError

sfn = boto3.client("stepfunctions")

STATE_MACHINE_ARN = "arn:aws:states:us-east-1:168918694591:stateMachine:VeeraHealthStateMachine"


def lambda_handler(event, context):

    for record in event["Records"]:

        try:

            payload = json.loads(record["body"])

            source_file_path = payload["source_file_path"]

            # Create deterministic execution name
            execution_name = hashlib.md5(
                (payload["source_file_path"] + payload["pipeline_run_id"]).encode("utf-8")
            ).hexdigest()

            print(f"Starting Step Function execution " f"for file: {source_file_path}")

            response = sfn.start_execution(
                stateMachineArn=STATE_MACHINE_ARN, name=execution_name, input=json.dumps(payload)
            )

            print(f"Execution started successfully: " f"{response['executionArn']}")

        except ClientError as e:

            error_code = e.response["Error"]["Code"]

            # Handle duplicate execution gracefully
            if error_code == "ExecutionAlreadyExists":

                print(f"Execution already exists for " f"{source_file_path}")

                # Treat as success
                continue

            print(f"AWS Error: {str(e)}")

            # Re-raise so SQS retries and eventually DLQ
            # raise

        except Exception as e:

            print(f"Unexpected Error: {str(e)}")

            # Re-raise so SQS retries and eventually DLQ
            # raise

    return {"statusCode": 200, "message": "All messages processed"}
