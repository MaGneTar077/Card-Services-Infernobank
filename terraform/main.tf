terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  required_version = ">= 1.3.0"
}

# S3 Bucket para reportes
resource "aws_s3_bucket" "reports_bucket" {
  bucket = var.reports_bucket_name

  tags = {
    Name        = "transactions-report-bucket"
    Environment = var.stage
  }
}

# IAM Role para Lambda
resource "aws_iam_role" "iam_for_lambda_report" {
  name = "ExecutionLambdaCardReport"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

# Políticas para la Lambda
resource "aws_iam_role_policy" "lambda_policy_for_report" {
  name = "lambda-card-report-policy"
  role = aws_iam_role.iam_for_lambda_report.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["dynamodb:Scan", "dynamodb:Query"]
        Resource = data.aws_dynamodb_table.transaction_table.arn
      },
      {
        Effect   = "Allow"
        Action   = ["s3:PutObject", "s3:GetObject"]
        Resource = "${aws_s3_bucket.reports_bucket.arn}/*"
      },
      {
        Effect   = "Allow"
        Action   = ["sqs:SendMessage", "sqs:GetQueueUrl"]
        Resource = data.aws_sqs_queue.notification_queue.arn
      },
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
      TRANSACTIONS_TABLE        = data.aws_dynamodb_table.transaction_table.name
      REPORTS_BUCKET            = aws_s3_bucket.reports_bucket.bucket
      SQS_QUEUE_URL_NOTIFICATION = data.aws_sqs_queue.notification_queue.url
    }
  }

  depends_on = [
    aws_iam_role_policy.lambda_policy_for_report
  ]
}

# API Gateway Resource /report
resource "aws_api_gateway_resource" "transactions_report" {
  rest_api_id = data.aws_api_gateway_rest_api.card_api.id
  parent_id   = data.aws_api_gateway_rest_api.card_api.root_resource_id
  path_part   = "report"
}

# method GET
resource "aws_api_gateway_method" "transactions_report_get" {
  resource_id   = aws_api_gateway_resource.transactions_report.id
  rest_api_id   = data.aws_api_gateway_rest_api.card_api.id
  http_method   = "GET"
  authorization = "NONE"
}

# Integración Lambda
resource "aws_api_gateway_integration" "transactions_report_integration" {
  rest_api_id             = data.aws_api_gateway_rest_api.card_api.id
  resource_id             = aws_api_gateway_resource.transactions_report.id
  http_method             = aws_api_gateway_method.transactions_report_get.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.CardReportLmb.invoke_arn
}

# Permisos Lambda para API Gateway
resource "aws_lambda_permission" "transactions_report_permission" {
  statement_id  = "AllowExecutionFromAPIGatewayTransactionsReport"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.CardReportLmb.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${data.aws_api_gateway_rest_api.card_api.execution_arn}/*/*"
}

# Deployment y Stage
resource "aws_api_gateway_deployment" "transactions_report_deployment" {
  rest_api_id = data.aws_api_gateway_rest_api.card_api.id
  depends_on = [
    aws_api_gateway_method.transactions_report_get,
    aws_api_gateway_integration.transactions_report_integration,
    aws_lambda_permission.transactions_report_permission
  ]
}

resource "aws_api_gateway_stage" "transactions_report_stage" {
  rest_api_id   = data.aws_api_gateway_rest_api.card_api.id
  deployment_id = aws_api_gateway_deployment.transactions_report_deployment.id
  stage_name    = var.stage
}

# Output con URL final
output "cardReportApiUrl" {
  value = "https://${data.aws_api_gateway_rest_api.card_api.id}.execute-api.${var.region}.amazonaws.com/${var.stage}${aws_api_gateway_resource.transactions_report.path}"
}
