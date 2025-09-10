# Nombre de la Lambda
variable "lambda_name_transaction_save" {
  type    = string
  default = "card-transaction-save-lambda"
}

# Nombre del archivo ZIP con el código de la lambda
variable "file_name_transaction_save" {
  type    = string
  default = "card-transaction-save-lmb"
}

# Entorno/stage (dev, prod, etc.)
variable "stage" {
  type    = string
  default = "Card"
}

# Tabla DynamoDB de tarjetas
variable "card_table_name" {
  type    = string
  default = "card-table"
}

# Tabla DynamoDB de transacciones
variable "transactions_table_name" {
  type    = string
  default = "transaction-table"
}

# Región AWS
variable "region" {
  type    = string
  default = "us-east-1"
}
