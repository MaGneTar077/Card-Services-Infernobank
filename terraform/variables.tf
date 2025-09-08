# Nombre de la Lambda
variable "lambda_name_failed" {
  type    = string
  default = "card-request-failed-lambda"
}

# Archivo zip que subes a Lambda
variable "file_name_failed" {
  type    = string
  default = "card-request-failed-lmb"
}

# Entorno (dev, qa, prod)
variable "stage" {
  type    = string
  default = "dev"
}

# Nombre de la cola principal
variable "card_request_queue_name" {
  type    = string
  default = "card-request-queue"
}

# Nombre de la Dead Letter Queue (DLQ)
variable "card_request_dlq_name" {
  type    = string
  default = "card-request-dlq"
}

# Tabla DynamoDB (para almacenar los errores de requests fallidos)
variable "card_error_table_name" {
  type    = string
  default = "card-error-table"
}

# Región de AWS
variable "region" {
  type    = string
  default = "us-east-1"
}
