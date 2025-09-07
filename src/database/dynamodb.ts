import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import {
  DynamoDBDocumentClient,
  UpdateCommand,
  PutCommand,
  QueryCommand,
} from "@aws-sdk/lib-dynamodb";
import { v4 as uuidv4 } from "uuid";

export class DynamoService {
  private readonly client = DynamoDBDocumentClient.from(
    new DynamoDBClient({}),
    {
      marshallOptions: {
        convertClassInstanceToMap: true,
        removeUndefinedValues: true,
      },
    }
  );

  private readonly cardTable = "card-table";
  private readonly transactionTable = "transaction-table";

  /**
   * Obtiene todas las tarjetas por uuid
   */
  async getCardsByUuid(uuid: string) {
    try {
      const response = await this.client.send(
        new QueryCommand({
          TableName: this.cardTable,
          KeyConditionExpression: "#uuid = :uuid",
          ExpressionAttributeNames: { "#uuid": "uuid" },
          ExpressionAttributeValues: { ":uuid": uuid },
        })
      );
      return response.Items || [];
    } catch (error) {
      console.error("❌ Error al consultar tarjetas por uuid:", error);
      throw error;
    }
  }

  /**
   * Obtiene la tarjeta más reciente por uuid
   */
  async getCardById(uuid: string) {
    try {
      const cards = await this.getCardsByUuid(uuid);
      if (!cards.length) return null;

      cards.sort((a, b) => (a.createdAt < b.createdAt ? 1 : -1));
      return cards[0];
    } catch (error) {
      console.error("❌ Error al obtener tarjeta más reciente por uuid:", error);
      throw error;
    }
  }

  /**
   * Actualiza balance (DEBIT)
   */
  async updateCardBalance(uuid: string, newBalance: number) {
    try {
      const card = await this.getCardById(uuid);
      if (!card) return null;

      const response = await this.client.send(
        new UpdateCommand({
          TableName: this.cardTable,
          Key: { uuid: card.uuid, createdAt: card.createdAt },
          UpdateExpression: "SET balance = :balance",
          ExpressionAttributeValues: { ":balance": newBalance },
          ReturnValues: "ALL_NEW",
        })
      );
      return response.Attributes;
    } catch (error) {
      console.error("❌ Error al actualizar balance:", error);
      throw error;
    }
  }

  /**
   * Actualiza usado (CREDIT)
   */
  async updateCardUsed(uuid: string, newUsed: number) {
    try {
      const card = await this.getCardById(uuid);
      if (!card) return null;

      const response = await this.client.send(
        new UpdateCommand({
          TableName: this.cardTable,
          Key: { uuid: card.uuid, createdAt: card.createdAt },
          UpdateExpression: "SET used = :used",
          ExpressionAttributeValues: { ":used": newUsed },
          ReturnValues: "ALL_NEW",
        })
      );
      return response.Attributes;
    } catch (error) {
      console.error("❌ Error al actualizar used:", error);
      throw error;
    }
  }

  /**
   * Guarda transacción
   */
 async saveTransaction(transaction: any) {
  try {
    const item = {
      uuid: uuidv4(), // 👈 UUID único de la transacción
      createdAt: new Date().toISOString(), // 👈 obligatorio porque es sort key
      ...transaction,
    };

    await this.client.send(
      new PutCommand({
        TableName: this.transactionTable,
        Item: item,
      })
    );

    return item;
  } catch (error) {
    console.error("❌ Error al guardar transacción:", error);
    throw error;
  }
}
}
