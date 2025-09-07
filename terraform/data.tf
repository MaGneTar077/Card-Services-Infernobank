# DynamoDB: Referencia a tabla existente de tarjetas
data "aws_dynamodb_table" "card_table" {
  name = var.card_table_name
}

# DynamoDB: Crear tabla de transacciones
# transaction_table.tf
resource "aws_dynamodb_table" "transaction_table" {
  name         = "transaction-table"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "uuid"
  range_key    = "createdAt"

  attribute {
    name = "uuid"
    type = "S"
  }

  attribute {
    name = "createdAt"
    type = "S"
  }
}



# API Gateway: Nueva API para tarjetas
resource "aws_api_gateway_rest_api" "CardApi" {
  name        = "card-api"
  description = "API Gateway para operaciones con tarjetas (purchase, etc.)"
}
