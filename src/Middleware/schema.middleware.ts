import {
  APIGatewayProxyEvent,
  APIGatewayProxyResult,
  APIGatewayProxyHandler,
} from "aws-lambda";

/**
 * Middleware simple que valida el formato del evento
 */
export const schemaMiddleware = (
  handler: (event: APIGatewayProxyEvent) => Promise<APIGatewayProxyResult>
): APIGatewayProxyHandler => {
  return async (
    event: APIGatewayProxyEvent
  ): Promise<APIGatewayProxyResult> => {
    try {
      if (!event.body) {
        return {
          statusCode: 400,
          body: JSON.stringify({ message: "Request body is required" }),
        };
      }

      return await handler(event);
    } catch (error: any) {
      console.error("Middleware error:", error);
      return {
        statusCode: 500,
        body: JSON.stringify({
          message: "Middleware internal error",
          error: error.message || "Unknown error",
        }),
      };
    }
  };
};
