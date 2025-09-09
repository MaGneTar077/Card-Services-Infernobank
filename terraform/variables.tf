variable "lambda_name_report" {
  description = "Nombre de la funcion Lambda para reportes"
  type        = string
  default     = "card-report-lambda"
}

variable "file_name_report" {
  description = "Nombre del archivo JAR de la Lambda de reportes"
  type        = string
  default     = "card-get-report-lambda-1.0-SNAPSHOT.jar"
}

variable "stage" {
  type    = string
  default = "dev-report-transaction"
}

variable "region" {
  type    = string
  default = "us-east-1"
}

# DynamoDB table
variable "transaction_table_name" {
  type    = string
  default = "transaction-table"
}

# Cola SQS existente
variable "notification_queue_name" {
  type    = string
  default = "notification-email-sqs"
}

# API Gateway existente
variable "card_api_name" {
  type    = string
  default = "card-api"
}

# S3 Bucket para guardar los reportes
variable "reports_bucket_name" {
  type    = string
  default = "transactions-report-bucket"
}
