resource "aws_dynamodb_table" "card_table_error" {
  name         = "card-table-error"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "uuid"

  attribute {
    name = "uuid"
    type = "S"
  }

  attribute {
    name = "createdAt"
    type = "S"
  }

  global_secondary_index {
    name            = "createdAt-index"
    hash_key        = "createdAt"
    projection_type = "ALL"
  }
}
