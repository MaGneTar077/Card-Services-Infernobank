import {
  APIGatewayProxyHandler,
  APIGatewayProxyEvent,
  APIGatewayProxyResult,
} from "aws-lambda";
import { getUserCard, updateCardStatus } from "../Database/Dynamo.js";
import { schemaMiddleware } from "../Middleware/schema.middleware.js";

export const handler: APIGatewayProxyHandler = schemaMiddleware(
  async (event: APIGatewayProxyEvent): Promise<APIGatewayProxyResult> => {
    try {
      const body = event.body ? JSON.parse(event.body) : {};
      const { userId } = body;

      if (!userId) {
        return {
          statusCode: 400,
          body: JSON.stringify({ message: "userId is required" }),
        };
      }

      // 1️⃣ Obtener la tarjeta del usuario
      const card = await getUserCard(userId, "CREDIT");

      if (!card) {
        return {
          statusCode: 404,
          body: JSON.stringify({ message: "Card not found for this user" }),
        };
      }

      // 2️⃣ Verificar si ya está activada
      if (card.status === "ACTIVATED") {
        return {
          statusCode: 200,
          body: JSON.stringify({
            message: "Card is already activated",
            card,
          }),
        };
      }

      // 3️⃣ Activar la tarjeta
      const updatedCard = await updateCardStatus(card.uuid, card.createdAt, "ACTIVATED");


      return {
        statusCode: 200,
        body: JSON.stringify({
          message: "Card successfully activated!",
          card: updatedCard,
        }),
      };
    } catch (error: any) {
      console.error("Error activating card:", error);
      return {
        statusCode: 500,
        body: JSON.stringify({
          message: "Internal server error",
          error: error.message || "Unknown error",
        }),
      };
    }
  }
);
