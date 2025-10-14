import { APIGatewayProxyEvent, APIGatewayProxyResult } from "aws-lambda";
import middy from "@middy/core";
import httpErrorHandler from "@middy/http-error-handler";
import httpJsonBodyParser from "@middy/http-json-body-parser";
import createHttpError from "http-errors";
import { schemaMiddleware } from "../middleware/schema.middleware.js";
import Joi from "joi";
import { DynamoService } from "../database/dynamodb.js";

// 📌 Schema para este endpoint
const saveTransactionSchema = Joi.object({
  merchant: Joi.string().required(),
  amount: Joi.number().positive().required(),
});

const dynamo = new DynamoService();

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization",
};

const cardTransactionSaveHandler = async (
  event: APIGatewayProxyEvent
): Promise<APIGatewayProxyResult> => {

   if (event.httpMethod === "OPTIONS") {
    return {
      statusCode: 200,
      headers: corsHeaders,
      body: JSON.stringify({ message: "CORS preflight OK" }),
    };
  }


  const { card_id } = event.pathParameters || {};
  if (!card_id) {
    throw new createHttpError.BadRequest("Missing card_id in path");
  }

  const { merchant, amount } = event.body as any;

  // 1️⃣ Obtener la tarjeta
  const card = await dynamo.getCardById(card_id);
  if (!card) {
    throw new createHttpError.NotFound("Card not found");
  }

  if (card.type !== "DEBIT") {
    throw new createHttpError.BadRequest("Only DEBIT cards can be recharged");
  }

  // 2️⃣ Actualizar balance
  const newBalance = (card.balance || 0) + amount;
  const updatedCard = await dynamo.updateCardBalance(card_id, newBalance);

  // 3️⃣ Guardar transacción
  const transaction = await dynamo.saveTransaction({
    cardId: card_id,
    merchant,
    amount,
    type: "DEBIT", // porque estamos cargando saldo
  });

  // 4️⃣ Respuesta
  return {
    statusCode: 201,
    headers: corsHeaders,
    body: JSON.stringify({
      message: "Balance added successfully",
      card: updatedCard,
      transaction,
    }),
  };
};

// 📌 Export con Middy
export const handler = middy(cardTransactionSaveHandler)
  .use(httpJsonBodyParser())
  .use(schemaMiddleware(saveTransactionSchema))
  .use(httpErrorHandler());
