variable "region" {
  type    = string
  default = "us-east-1"
}

variable "stage_name" {
  type    = string
  default = "dev-card-paid"
}

variable "api_id" {
  type    = string
  default = "j9busqzanh"
}

variable "lambda_name_paid" {
  type    = string
  default = "card-paid-credit-card-lambda"
}

variable "file_name_paid" {
  type    = string
  default = "card-paid-credit-card-lambda-1.0-SNAPSHOT.jar"
}

variable "card_table_arn" {
  type    = string
  default = "arn:aws:dynamodb:us-east-1:872112794115:table/card-table"
}
variable "card_table_name" {
  type    = string
  default = "card-table"
}

variable "transaction_table_arn" {
  type    = string
  default = "arn:aws:dynamodb:us-east-1:872112794115:table/transaction-table"
}
variable "transaction_table_name" {
  type    = string
  default = "transaction-table"
}

variable "notification_sqs_url" {
  type    = string
  default = "https://sqs.us-east-1.amazonaws.com/872112794115/notification-email-sqs"
}
variable "notification_sqs_arn" {
  type    = string
  default = "arn:aws:sqs:us-east-1:872112794115:notification-email-sqs"
}

variable "lambda_runtime" {
  type    = string
  default = "java17"
}

variable "lambda_timeout" {
  type    = number
  default = 30
}

variable "lambda_memory" {
  type    = number
  default = 512
}
