# Rol para Lambda Card Purchase
resource "aws_iam_role" "iam_for_lambda_purchase" {
  name = "ExecutionLambdaCardPurchase"

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


# =======================
# Política IAM
# =======================
resource "aws_iam_role_policy" "lambda_policy_for_purchase" {
  name = "lambda-card-purchase-policy"
  role = aws_iam_role.iam_for_lambda_purchase.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["dynamodb:*"]
        Resource = [
          data.aws_dynamodb_table.card_table.arn,
          aws_dynamodb_table.transaction_table.arn
        ]
      },
      {
        Effect   = "Allow"
        Action   = ["sqs:SendMessage"]
        Resource = data.aws_sqs_queue.notification_queue.arn
      },
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}