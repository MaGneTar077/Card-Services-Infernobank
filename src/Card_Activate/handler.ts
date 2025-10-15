import {
  APIGatewayProxyHandler,
  APIGatewayProxyEvent,
  APIGatewayProxyResult,
} from "aws-lambda";
import { getUserCard, updateCardStatus } from "../Database/Dynamo.js";
import { schemaMiddleware } from "../Middleware/schema.middleware.js";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization",
};

export const handler: APIGatewayProxyHandler = schemaMiddleware(
  async (event: APIGatewayProxyEvent): Promise<APIGatewayProxyResult> => {
    try {

      if (event.httpMethod === "OPTIONS") {
        return {
          statusCode: 200,
          headers: corsHeaders,
          body: JSON.stringify({ message: "CORS preflight OK" }),
        };
      }

      const body = event.body ? JSON.parse(event.body) : {};
      const { userId } = body;

      if (!userId) {
        return {
          statusCode: 400,
          headers: corsHeaders,
          body: JSON.stringify({ message: "userId is required" }),
        };
      }

      const card = await getUserCard(userId, "CREDIT");

      if (!card) {
        return {
          statusCode: 404,
          headers: corsHeaders,
          body: JSON.stringify({ message: "Card not found for this user" }),
        };
      }

      if (card.status === "ACTIVATED") {
        return {
          statusCode: 200,
          headers: corsHeaders,
          body: JSON.stringify({
            message: "Card is already activated",
            card,
          }),
        };
      }
 
      const updatedCard = await updateCardStatus(card.uuid, card.createdAt, "ACTIVATED");

      return {
        statusCode: 200,
        headers: corsHeaders,
        body: JSON.stringify({
          message: "Card successfully activated!",
          card: updatedCard,
        }),
      };
    } catch (error: any) {
      console.error("Error activating card:", error);
      return {
        statusCode: 500,
        headers: corsHeaders,
        body: JSON.stringify({
          message: "Internal server error",
          error: error.message || "Unknown error",
        }),
      };
    }
  }
);
