# =======================
# Lambda Function
# =======================
resource "aws_lambda_function" "CardTransactionSaveLmb" {
  filename         = "${path.module}/../lambda.zip"
  function_name    = var.lambda_name_transaction_save
  handler          = "dist/handler/cardTransactionSave.handler"
  runtime          = "nodejs20.x"
  timeout          = 900
  memory_size      = 256
  role             = aws_iam_role.iam_for_lambda_transaction_save.arn
  source_code_hash = filebase64sha256("${path.module}/../lambda.zip")

  environment {
    variables = {
      CARD_TABLE         = data.aws_dynamodb_table.card_table.name
      TRANSACTIONS_TABLE = data.aws_dynamodb_table.transaction_table.name
    }
  }

  depends_on = [
    aws_iam_role_policy.lambda_policy_for_transaction_save
  ]
}
