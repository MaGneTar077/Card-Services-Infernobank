variable "aws_region" {
  description = "Región de AWS"
  type        = string
  default     = "us-east-1"
}

variable "card_table_name" {
  description = "Nombre de la tabla DynamoDB de tarjetas"
  type        = string
  default     = "card-table"
}

variable "user_table_name" {
  description = "Nombre de la tabla DynamoDB de usuarios"
  type        = string
  default     = "user-table"
}


variable "stage" {
  type    = string
  default = "Credit"
}