import boto3
import json
from datetime import datetime
from urllib.parse import unquote_plus

sqs = boto3.client('sqs')

QUEUE_URL = "https://sqs.us-east-1.amazonaws.com/168918694591/veera-healthcare-ingestion-queue"

def lambda_handler(event, context):

    bucket = event['Records'][0]['s3']['bucket']['name']
    key = unquote_plus(event['Records'][0]['s3']['object']['key'])

    print(f"Received S3 event for: {key}")

    # Ignore folder creation events
    if key.endswith('/'):
        return {
            'statusCode': 200,
            'message': 'Folder event ignored'
        }

    # Process only JSON and CSV
    if not (key.lower().endswith('.json') or key.lower().endswith('.csv')):
        return {
            'statusCode': 200,
            'message': 'Unsupported file type ignored'
        }

    source_file_path = f"s3://{bucket}/{key}"

    if '/orders/' in key:
        entity_type = 'orders'
    elif '/products/' in key:
        entity_type = 'products'
    else:
        return {
            'statusCode': 400,
            'message': f'Unsupported entity path: {key}'
        }

    file_type = key.split('.')[-1].lower()

    payload = {
        'source_file_path': source_file_path,
        'entity_type': entity_type,
        'file_type': file_type,
        'pipeline_run_id': f"run_{datetime.now().strftime('%Y%m%d_%H%M%S_%f')}"
    }

    sqs.send_message(
        QueueUrl=QUEUE_URL,
        MessageBody=json.dumps(payload)
    )

    print(f"Message sent to SQS: {payload}")

    return {
        'statusCode': 200,
        'message': 'Message sent to SQS'
    }