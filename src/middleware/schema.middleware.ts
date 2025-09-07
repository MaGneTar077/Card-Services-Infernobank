import { MiddlewareObj } from "@middy/core";
import { APIGatewayEvent, APIGatewayProxyResult } from "aws-lambda";
import createHttpError from "http-errors";
import Joi from "joi";

// 📌 Esquema del body para purchase
const purchaseBodySchema = Joi.object({
  merchant: Joi.string().required(),
  cardId: Joi.string().uuid().required(),
  amount: Joi.number().positive().required(),
});

export const schemaMiddleware = (
  schema: Joi.ObjectSchema = purchaseBodySchema
): MiddlewareObj<APIGatewayEvent, APIGatewayProxyResult> => {
  return {
    before(request) {
      let body: any;

      // Parsear body si viene como string
      if (typeof request.event.body === "string") {
        try {
          body = JSON.parse(request.event.body);
        } catch {
          throw new createHttpError.BadRequest(
            "Invalid JSON format in request body"
          );
        }
      } else {
        body = request.event.body || {};
      }

      // ✅ Validamos el body
      const { error: bodyError, value: bodyValue } = schema.validate(body, {
        abortEarly: false,
      });

      if (bodyError) {
        throw new createHttpError.BadRequest(
          JSON.stringify({
            msg: "Invalid body input",
            details: bodyError.details.map((d) => d.message),
          })
        );
      }

      // Guardar datos validados
      (request.event as any).body = bodyValue;
    },
  };
};
