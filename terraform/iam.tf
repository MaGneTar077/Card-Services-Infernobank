# =====================================
# Rol para Lambda Card Transaction Save
# =====================================
resource "aws_iam_role" "iam_for_lambda_transaction_save" {
  name = "ExecutionLambdaCardTransactionSave"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = { Service = "lambda.amazonaws.com" }
        Action    = "sts:AssumeRole"
      }
    ]
  })
}

# =====================================
# Política IAM para la Lambda
# =====================================
resource "aws_iam_role_policy" "lambda_policy_for_transaction_save" {
  name = "lambda-card-transaction-save-policy"
  role = aws_iam_role.iam_for_lambda_transaction_save.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # Permisos sobre DynamoDB
      {
        Effect   = "Allow"
        Action   = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:Query"
        ]
        Resource = [
          data.aws_dynamodb_table.card_table.arn,
          data.aws_dynamodb_table.transaction_table.arn
        ]
      },
      # Permisos de logs
      {
        Effect   = "Allow"
        Action   = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}
