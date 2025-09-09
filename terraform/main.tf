locals {
  api_id = var.api_id
}

# Obtener el account_id dinámicamente
data "aws_caller_identity" "current" {}

# IAM Role para Lambda
resource "aws_iam_role" "lambda_paid_role" {
  name = "${var.lambda_name_paid}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# Policy inline para Lambda (logs, dynamodb, sqs)
resource "aws_iam_role_policy" "lambda_paid_policy" {
  name = "${var.lambda_name_paid}-policy"
  role = aws_iam_role.lambda_paid_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:Query",
          "dynamodb:GetItem",
          "dynamodb:UpdateItem",
          "dynamodb:PutItem",
          "dynamodb:Query"
        ]
        Resource = [
          var.card_table_arn,
          var.transaction_table_arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "sqs:SendMessage"
        ]
        Resource = var.notification_sqs_arn
      }
    ]
  })
}

# CloudWatch log group for lambda
resource "aws_cloudwatch_log_group" "lambda_paid_log" {
  name              = "/aws/lambda/${var.lambda_name_paid}"
  retention_in_days = 14
  tags = {
    Project = "card-paid"
    Stage   = var.stage_name
  }
}

# Lambda function
resource "aws_lambda_function" "card_paid_fn" {
  function_name = var.lambda_name_paid
  filename      = abspath("${path.module}/../card-paid-credit-card-lambda/target/${var.file_name_paid}")
  handler       = "org.example.CardPaidCreditCardLambda::handleRequest"
  runtime       = var.lambda_runtime
  timeout       = var.lambda_timeout
  memory_size   = var.lambda_memory
  role          = aws_iam_role.lambda_paid_role.arn

  source_code_hash = filebase64sha256(
    abspath("${path.module}/../card-paid-credit-card-lambda/target/${var.file_name_paid}")
  )

  environment {
    variables = {
      CARD_TABLE                 = var.card_table_name
      TRANSACTION_TABLE          = var.transaction_table_name
      SQS_QUEUE_URL_NOTIFICATION = var.notification_sqs_url
      REGION                     = var.region
    }
  }

  depends_on = [
    aws_iam_role_policy.lambda_paid_policy,
    aws_cloudwatch_log_group.lambda_paid_log
  ]
}

# API Gateway existente
data "aws_api_gateway_rest_api" "card_api" {
  name = "card-api"
}

# Usar el recurso /card ya existente
data "aws_api_gateway_resource" "existing_card_resource" {
  rest_api_id = local.api_id
  path        = "/card"
}

# /card/{card_id}
data "aws_api_gateway_resource" "existing_card_id_resource" {
  rest_api_id = local.api_id
  path        = "/card/{card_id}"
}

# /paid
resource "aws_api_gateway_resource" "paid_resource" {
  rest_api_id = local.api_id
  parent_id   = data.aws_api_gateway_rest_api.card_api.root_resource_id # <-- ahora raíz, no /card
  path_part   = "paid"
}

# /paid/{card_id}
resource "aws_api_gateway_resource" "paid_card_id_resource" {
  rest_api_id = local.api_id
  parent_id   = aws_api_gateway_resource.paid_resource.id
  path_part   = "{card_id}"
}

# Method: POST
resource "aws_api_gateway_method" "card_paid_post" {
  rest_api_id   = local.api_id
  resource_id   = aws_api_gateway_resource.paid_card_id_resource.id
  http_method   = "POST"
  authorization = "NONE"

  request_parameters = {
    "method.request.path.card_id" = true
  }
}

# Integration with Lambda
resource "aws_api_gateway_integration" "card_paid_integration" {
  rest_api_id             = local.api_id
  resource_id             = aws_api_gateway_resource.paid_card_id_resource.id
  http_method             = aws_api_gateway_method.card_paid_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.card_paid_fn.invoke_arn
  passthrough_behavior    = "WHEN_NO_MATCH"

  request_parameters = {
    "integration.request.path.card_id" = "method.request.path.card_id"
  }
}

# Lambda permission (CORREGIDO)
resource "aws_lambda_permission" "allow_apigw_invoke_paid" {
  statement_id  = "AllowAPIGatewayInvokeCardPaid"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.card_paid_fn.function_name
  principal     = "apigateway.amazonaws.com"

  # Permitir todas las rutas y métodos de este API en este stage
  source_arn = "arn:aws:execute-api:${var.region}:${data.aws_caller_identity.current.account_id}:${local.api_id}/*/*/*"
}

# Deployment
resource "aws_api_gateway_deployment" "card_api_deployment_paid" {
  rest_api_id = local.api_id

  triggers = {
    redeploy = sha1(join("", [
      aws_api_gateway_integration.card_paid_integration.id,
      aws_api_gateway_method.card_paid_post.id,
      aws_lambda_function.card_paid_fn.source_code_hash,
      timestamp()
    ]))
  }

  depends_on = [
    aws_api_gateway_integration.card_paid_integration,
    aws_lambda_permission.allow_apigw_invoke_paid
  ]
}

resource "aws_api_gateway_stage" "dev_card_paid_stage" {
  stage_name    = var.stage_name
  rest_api_id   = local.api_id
  deployment_id = aws_api_gateway_deployment.card_api_deployment_paid.id
}

# Output endpoint
output "card_paid_endpoint" {
  value       = "https://${local.api_id}.execute-api.${var.region}.amazonaws.com/${var.stage_name}/paid/{card_id}"
  description = "POST endpoint to pay credit card: /paid/{card_id}"
}
