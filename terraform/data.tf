# ==========================
# API Gateway: CardApi
# ==========================
resource "aws_api_gateway_rest_api" "CardApi" {
  name        = "card-api"
  description = "API para registrar transacciones y activar tarjeta cuando llega a 10 transacciones"
}


data "aws_dynamodb_table" "card_table" {
  name = var.card_table_name
}

data "aws_dynamodb_table" "user_table" {
  name = var.user_table_name
}
