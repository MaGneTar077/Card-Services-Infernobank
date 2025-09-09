# DynamoDB existente
data "aws_dynamodb_table" "transaction_table" {
  name = var.transaction_table_name
}

# Cola SQS existente
data "aws_sqs_queue" "notification_queue" {
  name = var.notification_queue_name
}

# API Gateway existente
data "aws_api_gateway_rest_api" "card_api" {
  name = var.card_api_name
}
