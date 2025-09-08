import { SQSEvent } from "aws-lambda";
import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import { DynamoDBDocumentClient, PutCommand } from "@aws-sdk/lib-dynamodb";
import { v4 as uuidv4 } from "uuid";

const dynamo = DynamoDBDocumentClient.from(new DynamoDBClient({}));
const errorTable = process.env.ERROR_TABLE || "card-table-error";

export const handler = async (event: SQSEvent) => {
  for (const record of event.Records) {
    try {
      const body = JSON.parse(record.body);

      console.log("📥 Mensaje fallido recibido:", body);

      const errorItem = {
        uuid: uuidv4(),
        originalMessage: body,
        errorDetail: record.messageAttributes || {},
        createdAt: new Date().toISOString(),
      };

      await dynamo.send(
        new PutCommand({
          TableName: errorTable,
          Item: errorItem,
        })
      );

      console.log("✅ Error guardado en card-table-error");
    } catch (err) {
      console.error("❌ Error procesando mensaje fallido:", err);
    }
  }

  return {
    statusCode: 200,
    body: JSON.stringify({ message: "Failed messages processed successfully" }),
  };
};
