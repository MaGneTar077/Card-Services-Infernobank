# S3 Bucket para reportes
resource "aws_s3_bucket" "reports_bucket" {
  bucket = var.reports_bucket_name

  tags = {
    Environment = var.stage
    Project     = "card-reports"
  }
}

# IAM Role para Lambda
resource "aws_iam_role" "iam_for_lambda_report" {
  name = "${var.lambda_name_report}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# Políticas de Lambda (logs, DynamoDB, S3, SQS)
resource "aws_iam_role_policy" "lambda_policy_for_report" {
  name = "${var.lambda_name_report}-policy"
  role = aws_iam_role.iam_for_lambda_report.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Effect   = "Allow"
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Action = [
          "dynamodb:GetItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Effect   = "Allow"
        Resource = data.aws_dynamodb_table.transaction_table.arn
      },
      {
        Action = [
          "s3:PutObject",
          "s3:GetObject"
        ]
        Effect   = "Allow"
        Resource = "${aws_s3_bucket.reports_bucket.arn}/*"
      },
      {
        Action = [
          "sqs:SendMessage"
        ]
        Effect   = "Allow"
        Resource = data.aws_sqs_queue.notification_queue.arn
      }
    ]
  })
}

# CloudWatch Logs
resource "aws_cloudwatch_log_group" "lambda_log_group" {
  name              = "/aws/lambda/${var.lambda_name_report}"
  retention_in_days = 7

  tags = {
    Environment = var.stage
  }
}

# Lambda Function
resource "aws_lambda_function" "CardReportLmb" {
  function_name = var.lambda_name_report
  filename      = abspath("${path.module}/../card-get-report-lambda/target/${var.file_name_report}")
  handler       = "org.example.CardGetReportLambda::handleRequest"
  runtime       = "java17"
  timeout       = 900
  memory_size   = 512
  role          = aws_iam_role.iam_for_lambda_report.arn

  source_code_hash = filebase64sha256(
    abspath("${path.module}/../card-get-report-lambda/target/${var.file_name_report}")
  )

  environment {
    variables = {
      TRANSACTIONS_TABLE         = data.aws_dynamodb_table.transaction_table.name
      REPORTS_BUCKET             = aws_s3_bucket.reports_bucket.bucket
      SQS_QUEUE_URL_NOTIFICATION = data.aws_sqs_queue.notification_queue.url
    }
  }

  depends_on = [
    aws_iam_role_policy.lambda_policy_for_report,
    aws_cloudwatch_log_group.lambda_log_group
  ]
}

# API Gateway Resources
resource "aws_api_gateway_resource" "card_resource" {
  rest_api_id = data.aws_api_gateway_rest_api.card_api.id
  parent_id   = data.aws_api_gateway_rest_api.card_api.root_resource_id
  path_part   = "card"
}

# /card/{card_id}
resource "aws_api_gateway_resource" "card_id_resource" {
  rest_api_id = data.aws_api_gateway_rest_api.card_api.id
  parent_id   = aws_api_gateway_resource.card_resource.id
  path_part   = "{card_id}"
}

# GET /card/{card_id}?start&end
resource "aws_api_gateway_method" "report_card_get" {
  rest_api_id   = data.aws_api_gateway_rest_api.card_api.id
  resource_id   = aws_api_gateway_resource.card_id_resource.id
  http_method   = "GET"
  authorization = "NONE"

  request_parameters = {
    "method.request.path.card_id"         = true
    "method.request.querystring.start"    = true
    "method.request.querystring.end"      = true
  }
}

resource "aws_api_gateway_integration" "report_card_integration" {
  rest_api_id             = data.aws_api_gateway_rest_api.card_api.id
  resource_id             = aws_api_gateway_resource.card_id_resource.id
  http_method             = aws_api_gateway_method.report_card_get.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.CardReportLmb.invoke_arn
  passthrough_behavior    = "WHEN_NO_MATCH"

  request_parameters = {
    "integration.request.path.card_id"      = "method.request.path.card_id"
    "integration.request.querystring.start" = "method.request.querystring.start"
    "integration.request.querystring.end"   = "method.request.querystring.end"
  }
}

# Permiso para API Gateway invocar Lambda
resource "aws_lambda_permission" "apigw_lambda_card_invoke" {
  statement_id  = "AllowAPIGatewayInvokeCardReport"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.CardReportLmb.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${data.aws_api_gateway_rest_api.card_api.execution_arn}/*/*"
}

# Deployment
resource "aws_api_gateway_deployment" "card_api_deployment_report" {
  rest_api_id = data.aws_api_gateway_rest_api.card_api.id

  triggers = {
    redeploy = sha1(join("", [
      aws_api_gateway_integration.report_card_integration.id,
      aws_lambda_function.CardReportLmb.source_code_hash
    ]))
  }

  depends_on = [
    aws_api_gateway_integration.report_card_integration,
    aws_lambda_permission.apigw_lambda_card_invoke
  ]
}

# Stage exclusivo para tu endpoint de reportes
resource "aws_api_gateway_stage" "dev_report_transaction_stage" {
  stage_name    = "dev-report-transaction"
  rest_api_id   = data.aws_api_gateway_rest_api.card_api.id
  deployment_id = aws_api_gateway_deployment.card_api_deployment_report.id

  tags = {
    Environment = "dev-report-transaction"
    Project     = "card-reports"
  }
}

# Output
output "card_report_api_endpoint_report_stage" {
  description = "Endpoint de reportes en el stage dev-report-transaction"
  value       = "https://${data.aws_api_gateway_rest_api.card_api.id}.execute-api.${var.region}.amazonaws.com/dev-report-transaction/card/{card_id}?start=YYYY-MM-DDTHH:mm:ssZ&end=YYYY-MM-DDTHH:mm:ssZ"
}
