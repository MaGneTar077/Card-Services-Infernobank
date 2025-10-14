import { APIGatewayProxyHandler } from "aws-lambda";
import middy from "@middy/core";
import { schemaMiddleware } from "../middleware/schema.middleware.js";
import { DynamoService } from "../database/dynamodb.js";
import { SQSService } from "../sqs/sqs.js";
import { v4 as uuidv4 } from "uuid";

const dynamoService = new DynamoService();
const sqsService = new SQSService();

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization",
};

const cardPurchaseHandler: APIGatewayProxyHandler = async (event) => {
  try {

    if (event.httpMethod === "OPTIONS") {
      return {
        statusCode: 200,
        headers: corsHeaders,
        body: JSON.stringify({ message: "CORS preflight OK" }),
      };
    }
    const body =
      typeof event.body === "string" ? JSON.parse(event.body) : event.body || {};

    const { merchant, cardId, amount } = body;

    if (!cardId || !amount || !merchant) {
      return {
        statusCode: 400,
        headers: corsHeaders,
        body: JSON.stringify({
          message: "merchant, cardId y amount son requeridos",
        }),
      };
    }

    // 🔎 Buscar tarjeta SOLO por uuid
    const card = await dynamoService.getCardById(cardId);
    if (!card) {
      return {
        statusCode: 404,
        headers: corsHeaders,
        body: JSON.stringify({ message: "Card not found" }),
      };
    }

    // 💳 Validaciones
    if (card.type === "DEBIT") {
      if (card.balance < amount) {
        return {
          statusCode: 400,
          headers: corsHeaders,
          body: JSON.stringify({ message: "Insufficient balance" }),
        };
      }
      await dynamoService.updateCardBalance(card.uuid, card.balance - amount);
    } else if (card.type === "CREDIT") {
      const used = card.used || 0;
      if (used + amount > card.limit) {
        return {
          statusCode: 400,
          headers: corsHeaders,
          body: JSON.stringify({ message: "Credit limit exceeded" }),
        };
      }
      await dynamoService.updateCardUsed(card.uuid, used + amount);
    }

    // 📝 Guardar transacción
    const transaction = {
      transactionId: uuidv4(),
      cardId,
      merchant,
      amount,
      date: new Date().toISOString(),
    };
    await dynamoService.saveTransaction(transaction);

    // 📤 Enviar a SQS
    await sqsService.sendTransactionNotification({
      type: "TRANSACTION.PURCHASE",
      data: transaction,
    });

    return {
      statusCode: 200,
      headers: corsHeaders,
      body: JSON.stringify({
        message: "Transaction successful",
        transaction,
      }),
    };
  } catch (error) {
    console.error("❌ Error en cardPurchaseHandler:", error);
    return {
      statusCode: 500,
      headers: corsHeaders,
      body: JSON.stringify({ message: "Internal Server Error" }),
    };
  }
};

export const handler = middy(cardPurchaseHandler).use(schemaMiddleware());
