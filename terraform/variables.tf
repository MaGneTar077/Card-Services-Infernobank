variable "lambda_name" {
  description = "Nombre de la funcion Lambda"
  type        = string
  default     = "create-request-card-lambda"
}

variable "file_name" {
  description = "Nombre del archivo JAR de la Lambda"
  type        = string
  default     = "create-request-card-lambda-1.0-SNAPSHOT.jar"
}

variable "sqs_card_name" {
  description = "Nombre de la cola SQS para solicitudes de tarjeta"
  type        = string
  default     = "create-request-card-sqs"
}

variable "sqs_card_dlq_name" {
  description = "Nombre de la cola DLQ para errores en solicitudes de tarjeta"
  type        = string
  default     = "error-create-request-card-sqs"
}

variable "sqs_notification_name" {
  description = "Nombre de la cola SQS para notificaciones"
  type        = string
  default     = "notification-email-sqs"
}
