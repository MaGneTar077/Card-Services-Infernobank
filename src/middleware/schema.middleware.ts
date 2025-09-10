import { MiddlewareObj, Request } from "@middy/core";
import { APIGatewayEvent, APIGatewayProxyResult } from "aws-lambda";
import createHttpError from "http-errors";
import Joi from "joi";

// 📌 Schemas
export const purchaseBodySchema = Joi.object({
  merchant: Joi.string().required(),
  cardId: Joi.string().uuid().required(),
  amount: Joi.number().positive().required(),
});

export const createCardSchema = Joi.object({
  userId: Joi.string().uuid().required(),
  type: Joi.string().valid("DEBIT", "CREDIT").required(),
  balance: Joi.number().min(0).required(),
  status: Joi.string().valid("ACTIVATED", "BLOCKED").default("ACTIVATED"),
});

export const transactionSchema = Joi.object({
  transactionId: Joi.string().uuid().required(),
  cardId: Joi.string().uuid().required(),
  merchant: Joi.string().required(),
  amount: Joi.number().positive().required(),
  date: Joi.date().iso().required(),
});

// 📌 Middleware genérico
export const schemaMiddleware = (
  schema: Joi.ObjectSchema = purchaseBodySchema
): MiddlewareObj<APIGatewayEvent, APIGatewayProxyResult> => {
  return {
    before(request: Request<APIGatewayEvent, APIGatewayProxyResult>) {
      let body: any;

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

      const { error: bodyError, value: bodyValue } = schema.validate(body, {
        abortEarly: false,
        stripUnknown: true,
      });

      if (bodyError) {
        throw new createHttpError.BadRequest(
          JSON.stringify({
            msg: "Invalid body input",
            details: bodyError.details.map((d) => d.message),
          })
        );
      }

      (request.event as any).body = bodyValue;
    },
  };
};
