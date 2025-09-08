# sqs.tf
resource "aws_sqs_queue" "error_create_request_card_queue" {
  name = "error-create-request-card-sqs"
}
