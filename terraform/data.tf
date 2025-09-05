# Política de confianza para Lambda
data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

# Policy: permisos de Lambda en DynamoDB y SQS
data "aws_iam_policy_document" "lambda_execution" {
  statement {
    effect = "Allow"
    actions = [
      "dynamodb:PutItem",
      "dynamodb:GetItem",
      "dynamodb:Scan"
    ]
    resources = [aws_dynamodb_table.card_table.arn]
  }

  statement {
    effect = "Allow"
    actions = ["sqs:SendMessage", "sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes"]
    resources = [
      aws_sqs_queue.card_sqs.arn,
      aws_sqs_queue.card_dlq.arn,
      aws_sqs_queue.notification_sqs.arn
    ]
  }
}

