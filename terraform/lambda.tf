resource "aws_lambda_function" "CardActivateLambda" {
  function_name    = "card-activate-lambda"
  filename         = "${path.module}/../lambda.zip"
  handler          = "dist/Card_Activate/handler.handler"
  runtime          = "nodejs20.x"
  role             = aws_iam_role.lambda_exec_role.arn
  source_code_hash = filebase64sha256("${path.module}/../lambda.zip")

  environment {
  variables = {
    CARD_TABLE         = data.aws_dynamodb_table.card_table.name
    USER_TABLE         = data.aws_dynamodb_table.user_table.name
    REGION_NAME        = var.aws_region
  }
}

}
