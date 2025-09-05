terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  required_version = ">= 1.3.0"
}

# IAM Role para Lambda
resource "aws_iam_role" "iam_for_lambda" {
  name               = "execution_role_create_request_card_lambda"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

# Attach policy básica de ejecución
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.iam_for_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Attach policy custom
resource "aws_iam_role_policy" "iam_policy_for_lambda" {
  name   = "lambda_card_dynamodb_sqs_policy"
  role   = aws_iam_role.iam_for_lambda.id
  policy = data.aws_iam_policy_document.lambda_execution.json
}

# DynamoDB
resource "aws_dynamodb_table" "card_table" {
  name         = "card-table"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "uuid"
  range_key    = "createdAt"

  attribute {
    name = "uuid"
    type = "S"
  }

  attribute {
    name = "createdAt"
    type = "S"
  }
}

# SQS Queues
resource "aws_sqs_queue" "notification_sqs" {
  name                       = var.sqs_notification_name
  visibility_timeout_seconds = 30
}

resource "aws_sqs_queue" "card_dlq" {
  name                       = var.sqs_card_dlq_name
  visibility_timeout_seconds = 30
}

resource "aws_sqs_queue" "card_sqs" {
  name                       = var.sqs_card_name
  visibility_timeout_seconds = 30

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.card_dlq.arn
    maxReceiveCount     = 3
  })
}

# Lambda
resource "aws_lambda_function" "create_request_card_lambda" {
  function_name = var.lambda_name
  filename      = abspath("${path.module}/../create-request-card-lambda/target/${var.file_name}")
  handler       = "org.example.CreateRequestCardLambda::handleRequest"
  runtime       = "java17"
  timeout       = 15
  memory_size   = 512
  role          = aws_iam_role.iam_for_lambda.arn

  # Verificación cambios en el JAR
  source_code_hash = filebase64sha256(abspath("${path.module}/../create-request-card-lambda/target/${var.file_name}"))

  environment {
    variables = {
      SQS_QUEUE_URL_NOTIFICATION = aws_sqs_queue.notification_sqs.url
      SQS_DLQ_URL                = aws_sqs_queue.card_dlq.url
    }
  }
}

# Vincular SQS con Lambda (trigger event source mapping)
resource "aws_lambda_event_source_mapping" "sqs_trigger" {
  event_source_arn = aws_sqs_queue.card_sqs.arn
  function_name    = aws_lambda_function.create_request_card_lambda.arn
  batch_size       = 10
}

# Outputs
output "card_sqs_url" {
  value = aws_sqs_queue.card_sqs.url
}

output "card_dlq_url" {
  value = aws_sqs_queue.card_dlq.url
}

output "notification_sqs_url" {
  value = aws_sqs_queue.notification_sqs.url
}

output "card_table_name" {
  value = aws_dynamodb_table.card_table.name
}

