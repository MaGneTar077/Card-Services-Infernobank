# ==========================
# Recurso /card
# ==========================
resource "aws_api_gateway_resource" "Card" {
  rest_api_id = aws_api_gateway_rest_api.CardApi.id
  parent_id   = aws_api_gateway_rest_api.CardApi.root_resource_id
  path_part   = "Card"
}

# ==========================
# Recurso /card/activate
# ==========================
resource "aws_api_gateway_resource" "card_activate" {
  rest_api_id = aws_api_gateway_rest_api.CardApi.id
  parent_id   = aws_api_gateway_resource.Card.id
  path_part   = "activate"
}

# ==========================
# Método POST
# ==========================
resource "aws_api_gateway_method" "card_activate_post" {
  rest_api_id   = aws_api_gateway_rest_api.CardApi.id
  resource_id   = aws_api_gateway_resource.card_activate.id
  http_method   = "POST"
  authorization = "NONE"
}

# ==========================
# Integración con Lambda
# ==========================
resource "aws_api_gateway_integration" "card_activate_integration" {
  rest_api_id             = aws_api_gateway_rest_api.CardApi.id
  resource_id             = aws_api_gateway_resource.card_activate.id
  http_method             = aws_api_gateway_method.card_activate_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.CardActivateLambda.invoke_arn
}

# ==========================
# Permisos Lambda
# ==========================
resource "aws_lambda_permission" "card_activate_permission" {
  statement_id  = "AllowExecutionFromAPIGatewayCardActivate"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.CardActivateLambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.CardApi.execution_arn}/*/*"
}




# ==========================
# Output con URL final
# ==========================
output "cardActivateApiUrl" {
  description = "Endpoint para activar tarjetas al completar 10 transacciones"
  value       = "https://${aws_api_gateway_rest_api.CardApi.id}.execute-api.${var.aws_region}.amazonaws.com/${var.stage}/card/activate"
}


# ==========================
# Deployment
# ==========================
resource "aws_api_gateway_deployment" "card_activate_deployment" {
  rest_api_id = aws_api_gateway_rest_api.CardApi.id

  depends_on = [
    aws_api_gateway_integration.card_activate_integration,
    aws_lambda_permission.card_activate_permission
  ]
}

# ==========================
# Stage (nuevo)
# ==========================
resource "aws_api_gateway_stage" "card_stage" {
  stage_name    = var.stage
  rest_api_id   = aws_api_gateway_rest_api.CardApi.id
  deployment_id = aws_api_gateway_deployment.card_activate_deployment.id


  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.apigw_card_activate.arn
    format          = jsonencode({
      requestId          = "$context.requestId"
      ip                 = "$context.identity.sourceIp"
      caller             = "$context.identity.caller"
      user               = "$context.identity.user"
      requestTime        = "$context.requestTime"
      httpMethod         = "$context.httpMethod"
      resourcePath       = "$context.resourcePath"
      status             = "$context.status"
      protocol           = "$context.protocol"
      responseLength     = "$context.responseLength"
      integrationStatus  = "$context.integration.status"
      errorMessage       = "$context.error.message"
    })
  }

  depends_on = [
    aws_api_gateway_account.account
  ]
}
