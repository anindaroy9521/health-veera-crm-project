output "ingestion_queue_url" {

  value = aws_sqs_queue.ingestion_queue.url

}

output "ingestion_queue_arn" {

  value = aws_sqs_queue.ingestion_queue.arn

}

output "dlq_url" {

  value = aws_sqs_queue.ingestion_dlq.url

}