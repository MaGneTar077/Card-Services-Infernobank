
# ==========================
# Recurso /transactions
# ==========================
resource "aws_api_gateway_resource" "transactions" {
  rest_api_id = aws_api_gateway_rest_api.CardApi.id
  parent_id   = aws_api_gateway_rest_api.CardApi.root_resource_id
  path_part   = "transactions"
}

# ==========================
# Recurso /transactions/purchase
# ==========================
resource "aws_api_gateway_resource" "transactions_purchase" {
  rest_api_id = aws_api_gateway_rest_api.CardApi.id
  parent_id   = aws_api_gateway_resource.transactions.id
  path_part   = "purchase"
}

# ==========================
# Método POST
# ==========================
resource "aws_api_gateway_method" "transactions_purchase_post" {
  resource_id   = aws_api_gateway_resource.transactions_purchase.id
  rest_api_id   = aws_api_gateway_rest_api.CardApi.id
  http_method   = "POST"
  authorization = "NONE"
}

# ==========================
# Integración Lambda
# ==========================
resource "aws_api_gateway_integration" "transactions_purchase_integration" {
  rest_api_id             = aws_api_gateway_rest_api.CardApi.id
  resource_id             = aws_api_gateway_resource.transactions_purchase.id
  http_method             = aws_api_gateway_method.transactions_purchase_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.CardPurchaseLmb.invoke_arn
}

# ==========================
# Permisos Lambda para API Gateway
# ==========================
resource "aws_lambda_permission" "transactions_purchase_permission" {
  statement_id  = "AllowExecutionFromAPIGatewayTransactionsPurchase"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.CardPurchaseLmb.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.CardApi.execution_arn}/*/*"
}

# ==========================
# Deployment y Stage
# ==========================
resource "aws_api_gateway_deployment" "transactions_purchase_deployment" {
  rest_api_id = aws_api_gateway_rest_api.CardApi.id
  depends_on = [
    aws_api_gateway_method.transactions_purchase_post,
    aws_api_gateway_integration.transactions_purchase_integration,
    aws_lambda_permission.transactions_purchase_permission
  ]
}

resource "aws_api_gateway_stage" "card_purchase_stage" {
  rest_api_id   = aws_api_gateway_rest_api.CardApi.id
  deployment_id = aws_api_gateway_deployment.transactions_purchase_deployment.id
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
output "cardPurchaseApiUrl" {
  value = "https://${aws_api_gateway_rest_api.CardApi.id}.execute-api.${var.region}.amazonaws.com/${var.stage}${aws_api_gateway_resource.transactions_purchase.path}"
}

# ==========================
# Lookup del rol existente
# ==========================
data "aws_iam_role" "apigw_cloudwatch" {
  name = "apigateway-cloudwatch-role"
}

# ==========================
# Adjuntar política al rol
# ==========================
resource "aws_iam_role_policy_attachment" "apigw_cloudwatch_attach" {
  role       = data.aws_iam_role.apigw_cloudwatch.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonAPIGatewayPushToCloudWatchLogs"
}

# ==========================
# Configuración de API Gateway Account
# ==========================
resource "aws_api_gateway_account" "account" {
  cloudwatch_role_arn = data.aws_iam_role.apigw_cloudwatch.arn
}
