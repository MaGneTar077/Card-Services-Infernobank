# ==========================
# Recurso /transactions
# ==========================
resource "aws_api_gateway_resource" "transactions" {
  rest_api_id = aws_api_gateway_rest_api.CardApi.id
  parent_id   = aws_api_gateway_rest_api.CardApi.root_resource_id
  path_part   = "transaction"
}

# ==========================
# Recurso /transactions/save
# ==========================
resource "aws_api_gateway_resource" "transactions_save" {
  rest_api_id = aws_api_gateway_rest_api.CardApi.id
  parent_id   = aws_api_gateway_resource.transactions.id
  path_part   = "save"
}

# ==========================
# Recurso /transactions/save/{card_id}
# ==========================
resource "aws_api_gateway_resource" "transactions_save_card_id" {
  rest_api_id = aws_api_gateway_rest_api.CardApi.id
  parent_id   = aws_api_gateway_resource.transactions_save.id
  path_part   = "{card_id}"
}

# ==========================
# Método POST
# ==========================
resource "aws_api_gateway_method" "transactions_save_post" {
  resource_id   = aws_api_gateway_resource.transactions_save_card_id.id
  rest_api_id   = aws_api_gateway_rest_api.CardApi.id
  http_method   = "POST"
  authorization = "NONE"
}

# ==========================
# Integración Lambda
# ==========================
resource "aws_api_gateway_integration" "transactions_save_integration" {
  rest_api_id             = aws_api_gateway_rest_api.CardApi.id
  resource_id             = aws_api_gateway_resource.transactions_save_card_id.id
  http_method             = aws_api_gateway_method.transactions_save_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.CardTransactionSaveLmb.invoke_arn
}

# ==========================
# Permisos Lambda para API Gateway
# ==========================
resource "aws_lambda_permission" "transactions_save_permission" {
  statement_id  = "AllowExecutionFromAPIGatewayTransactionsSave"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.CardTransactionSaveLmb.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.CardApi.execution_arn}/*/*"
}

# ==========================
# Deployment y Stage
# ==========================
resource "aws_api_gateway_deployment" "transactions_save_deployment" {
  rest_api_id = aws_api_gateway_rest_api.CardApi.id
  depends_on = [
    aws_api_gateway_method.transactions_save_post,
    aws_api_gateway_integration.transactions_save_integration,
    aws_lambda_permission.transactions_save_permission
  ]
}

resource "aws_api_gateway_stage" "card_transaction_save_stage" {
  rest_api_id   = aws_api_gateway_rest_api.CardApi.id
  deployment_id = aws_api_gateway_deployment.transactions_save_deployment.id
  stage_name    = var.stage

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.apigw.arn
    format = jsonencode({
      requestId      = "$context.requestId"
      ip             = "$context.identity.sourceIp"
      caller         = "$context.identity.caller"
      user           = "$context.identity.user"
      requestTime    = "$context.requestTime"
      httpMethod     = "$context.httpMethod"
      resourcePath   = "$context.resourcePath"
      status         = "$context.status"
      protocol       = "$context.protocol"
      responseLength = "$context.responseLength"
    })
  }

  depends_on = [aws_api_gateway_account.account]
}

# ==========================
# Output con URL final
# ==========================
output "cardTransactionSaveApiUrl" {
  description = "Endpoint para guardar transacciones en una tarjeta"
  value       = "https://${aws_api_gateway_rest_api.CardApi.id}.execute-api.${var.region}.amazonaws.com/${var.stage}/transactions/save/{card_id}"
}


# Vincular API Gateway con CloudWatch Logs
resource "aws_api_gateway_account" "account" {
  cloudwatch_role_arn = aws_iam_role.api_gateway_cloudwatch.arn
}

# Rol para que API Gateway pueda escribir logs en CloudWatch
resource "aws_iam_role" "api_gateway_cloudwatch" {
  name = "api-gateway-cloudwatch-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "apigateway.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "api_gateway_cloudwatch_policy" {
  role = aws_iam_role.api_gateway_cloudwatch.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams",
          "logs:PutLogEvents",
          "logs:GetLogEvents",
          "logs:FilterLogEvents"
        ],
        Resource = "*"
      }
    ]
  })
}
