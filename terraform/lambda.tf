resource "aws_lambda_function" "card_request_failed_lambda" {
  function_name = "card-request-failed"
  handler       = "dist/handler/card-request-failed.handler"
  runtime       = "nodejs20.x"

  filename         = "${path.module}/../lambda.zip"
  source_code_hash = filebase64sha256("${path.module}/../lambda.zip")

  role = aws_iam_role.lambda_exec.arn

  environment {
    variables = {
      ERROR_TABLE = aws_dynamodb_table.card_table_error.name
    }
  }
}

resource "aws_lambda_event_source_mapping" "card_request_failed_mapping" {
  event_source_arn = aws_sqs_queue.error_create_request_card_queue.arn
  function_name    = aws_lambda_function.card_request_failed_lambda.arn
}
