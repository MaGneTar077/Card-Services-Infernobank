# ==============================
# Variables
# ==============================
variable "lambda_name" {
  description = "Nombre de la función Lambda (se usará para el log group)"
  type        = string
  default     = "card-transaction-save-lambda"
}

variable "retention_in_days" {
  description = "Días de retención de logs en CloudWatch"
  type        = number
  default     = 14
}

# ==============================
# CloudWatch Log Groups
# ==============================

# Log Group para Lambda
resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${var.lambda_name}"
  retention_in_days = var.retention_in_days
}

# Log Group para API Gateway (ajustado a la API real)
resource "aws_cloudwatch_log_group" "apigw" {
  name              = "/aws/apigateway/card-api/${var.stage}"
  retention_in_days = var.retention_in_days
}

# ==============================
# Outputs
# ==============================
output "lambda_log_group_name" {
  value = aws_cloudwatch_log_group.lambda.name
}

output "lambda_log_group_arn" {
  value = aws_cloudwatch_log_group.lambda.arn
}

output "apigw_log_group_name" {
  value = aws_cloudwatch_log_group.apigw.name
}

output "apigw_log_group_arn" {
  value = aws_cloudwatch_log_group.apigw.arn
}

# ==============================
# API Gateway Method Settings
# ==============================
# Habilitar logs y métricas en el API Gateway
resource "aws_api_gateway_method_settings" "card_transaction_save_stage_all" {
  rest_api_id = aws_api_gateway_rest_api.CardApi.id
  stage_name  = aws_api_gateway_stage.card_transaction_save_stage.stage_name

  method_path = "*/*"

  settings {
    metrics_enabled    = true
    logging_level      = "INFO"
    data_trace_enabled = true
  }

  depends_on = [aws_api_gateway_account.account]
}
