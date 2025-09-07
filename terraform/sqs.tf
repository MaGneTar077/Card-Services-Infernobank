# ==========================
# Cola principal existente
# ==========================
data "aws_sqs_queue" "notification_queue" {
  name = "notification-email-sqs" # 👈 nombre exacto de la cola ya creada
}

# Si también tienes una DLQ existente:
# data "aws_sqs_queue" "notification_dlq" {
#   name = "notification-email-sqs-dlq"
# }

# ==========================
# Outputs
# ==========================
output "notification_queue_url" {
  value = data.aws_sqs_queue.notification_queue.id
}

output "notification_queue_arn" {
  value = data.aws_sqs_queue.notification_queue.arn
}

#output "notification_dlq_url" {
#  value = aws_sqs_queue.notification_dlq.id
#}

#output "notification_dlq_arn" {
#  value = aws_sqs_queue.notification_dlq.arn
#}

resource "aws_iam_role_policy" "lambda_policy_for_sqs" {
  name = "lambda-policy-for-sqs"
  role = aws_iam_role.iam_for_lambda_purchase.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = [
          "sqs:SendMessage",
          "sqs:GetQueueUrl"
        ]
        Resource = "arn:aws:sqs:us-east-1:872112794115:notification-email-sqs" # ✅ cola existente
      }
    ]
  })
}
