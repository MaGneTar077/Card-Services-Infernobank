# ==========================
# Habilitar envío de logs de API Gateway a CloudWatch
# ==========================
resource "aws_iam_role" "api_gateway_cloudwatch_role" {
  name = "APIGatewayCloudWatchLogsRole"

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

resource "aws_iam_role_policy_attachment" "api_gateway_cloudwatch_policy" {
  role       = aws_iam_role.api_gateway_cloudwatch_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonAPIGatewayPushToCloudWatchLogs"
}

resource "aws_api_gateway_account" "account" {
  cloudwatch_role_arn = aws_iam_role.api_gateway_cloudwatch_role.arn
}




# ==========================
# Variables
# ==========================
variable "lambda_name" {
  description = "Nombre de la función Lambda (se usará para el log group)"
  type        = string
  default     = "card-activate-lambda"
}

variable "retention_in_days" {
  description = "Días de retención de logs en CloudWatch"
  type        = number
  default     = 14
}

# ==========================
# Log Group para Lambda
# ==========================
resource "aws_cloudwatch_log_group" "lambda_card_activate" {
  name              = "/aws/lambda/${var.lambda_name}"
  retention_in_days = var.retention_in_days
}

# ==========================
# Log Group para API Gateway
# ==========================
resource "aws_cloudwatch_log_group" "apigw_card_activate" {
  name              = "/aws/apigateway/card-api/${var.stage}"
  retention_in_days = var.retention_in_days
}

# ==========================
# Salidas (Outputs)
# ==========================
output "lambda_card_activate_log_group_name" {
  value = aws_cloudwatch_log_group.lambda_card_activate.name
}

output "lambda_card_activate_log_group_arn" {
  value = aws_cloudwatch_log_group.lambda_card_activate.arn
}

output "apigw_card_activate_log_group_name" {
  value = aws_cloudwatch_log_group.apigw_card_activate.name
}

output "apigw_card_activate_log_group_arn" {
  value = aws_cloudwatch_log_group.apigw_card_activate.arn
}

# ==========================
# Habilitar logs y métricas en API Gateway (para card/activate)
# ==========================
resource "aws_api_gateway_method_settings" "card_activate_stage_all" {
  rest_api_id = aws_api_gateway_rest_api.CardApi.id
  stage_name  = aws_api_gateway_stage.card_stage.stage_name  # <- CORREGIDO

  method_path = "*/*"

  settings {
    metrics_enabled    = true
    logging_level      = "INFO"
    data_trace_enabled = true
  }

  depends_on = [
    aws_api_gateway_account.account,
    aws_cloudwatch_log_group.apigw_card_activate
  ]
}


  
