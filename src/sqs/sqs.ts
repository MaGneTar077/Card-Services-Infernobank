import { SQSClient, SendMessageCommand } from "@aws-sdk/client-sqs";

export class SQSService {
  private readonly client = new SQSClient({});
  private readonly queueUrl =
    "https://sqs.us-east-1.amazonaws.com/872112794115/notification-email-sqs"; // ✅ URL fija

  async sendTransactionNotification(message: any) {
    try {
      const command = new SendMessageCommand({
        QueueUrl: this.queueUrl,
        MessageBody: JSON.stringify(message),
      });

      await this.client.send(command);
      console.log("✅ Mensaje enviado a SQS:", message);
    } catch (error) {
      console.error("❌ Error enviando mensaje a SQS:", error);
      throw error;
    }
  }
}
