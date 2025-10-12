import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import {
  DynamoDBDocumentClient,
  GetCommand,
  UpdateCommand,
  QueryCommand,
} from "@aws-sdk/lib-dynamodb";
import { ScanCommand } from "@aws-sdk/lib-dynamodb";


const client = new DynamoDBClient({});
export const dynamo = DynamoDBDocumentClient.from(client);

const USER_TABLE = process.env.USER_TABLE!;
const CARD_TABLE = process.env.CARD_TABLE!;

/**
 * Obtiene un usuario por su UUID
 */
export const getUserById = async (uuid: string) => {
  const command = new GetCommand({
    TableName: USER_TABLE,
    Key: { uuid },
  });
  const result = await dynamo.send(command);
  return result.Item;
};

/**
 * Obtiene la tarjeta del usuario (usando GSI si existe)
 */
export const getUserCard = async (userId: string, type = "CREDIT") => {
  const command = new ScanCommand({
    TableName: CARD_TABLE,
    FilterExpression: "userId = :u AND #t = :t",
    ExpressionAttributeNames: { "#t": "type" },
    ExpressionAttributeValues: {
      ":u": userId,
      ":t": type,
    },
  });

  const result = await dynamo.send(command);
  return result.Items?.[0];
};

/**
 * Actualiza el estado de una tarjeta
 */
export const updateCardStatus = async (
  cardUuid: string,
  createdAt: string,
  newStatus: string
) => {
  const command = new UpdateCommand({
    TableName: CARD_TABLE,
    Key: { uuid: cardUuid, createdAt: createdAt }, // 👈 ambas claves requeridas
    UpdateExpression: "SET #s = :status",
    ExpressionAttributeNames: { "#s": "status" },
    ExpressionAttributeValues: { ":status": newStatus },
    ReturnValues: "ALL_NEW",
  });

  const result = await dynamo.send(command);
  return result.Attributes;
};

