variable "lambda_name_purchase" {
  type    = string
  default = "card-purchase-lambda"
}

variable "file_name_purchase" {
  type    = string
  default = "card-purchase-lmb"
}

variable "stage" {
  type    = string
  default = "dev"
}

# Cola de notificaciones (SQS)
variable "notification_queue_name" {
  type    = string
  default = "notification-email-queue"
}

# Tabla DynamoDB de tarjetas
variable "card_table_name" {
  type    = string
  default = "card-table"
}

# Tabla DynamoDB de transacciones (para guardar las compras)
variable "transactions_table_name" {
  type    = string
  default = "transactions-table"
}

variable "region" {
  type    = string
  default = "us-east-1"
}
