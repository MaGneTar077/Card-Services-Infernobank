# ==============================
# DynamoDB: Referencias a tablas
# ==============================

# Tabla existente de tarjetas
data "aws_dynamodb_table" "card_table" {
  name = var.card_table_name
}

# Tabla existente de transacciones
data "aws_dynamodb_table" "transaction_table" {
  name = var.transactions_table_name
}

# ==============================
# API Gateway
# ==============================

resource "aws_api_gateway_rest_api" "CardApi" {
  name        = "card-api"
  description = "API Gateway para operaciones con tarjetas (activate, save transaction, paid, etc.)"
}