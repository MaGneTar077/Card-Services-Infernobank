package org.example;

import com.amazonaws.services.dynamodbv2.AmazonDynamoDB;
import com.amazonaws.services.dynamodbv2.AmazonDynamoDBClientBuilder;
import com.amazonaws.services.dynamodbv2.document.DynamoDB;
import com.amazonaws.services.dynamodbv2.document.Item;
import com.amazonaws.services.dynamodbv2.document.Table;
import com.amazonaws.services.lambda.runtime.Context;
import com.amazonaws.services.lambda.runtime.RequestHandler;
import com.amazonaws.services.lambda.runtime.events.APIGatewayProxyRequestEvent;
import com.amazonaws.services.lambda.runtime.events.APIGatewayProxyResponseEvent;
import com.amazonaws.services.sqs.AmazonSQS;
import com.amazonaws.services.sqs.AmazonSQSClientBuilder;
import com.amazonaws.services.sqs.model.SendMessageRequest;
import com.fasterxml.jackson.databind.ObjectMapper;

import java.time.Instant;
import java.util.HashMap;
import java.util.Map;
import java.util.UUID;

public class CardPaidCreditCardLambda implements RequestHandler<APIGatewayProxyRequestEvent, APIGatewayProxyResponseEvent> {

    private final DynamoDB dynamoDB;
    private final Table cardTable;
    private final Table transactionTable;
    private final AmazonSQS sqsClient;
    private final String sqsQueueUrl;
    private final ObjectMapper objectMapper = new ObjectMapper();

    public CardPaidCreditCardLambda() {
        AmazonDynamoDB client = AmazonDynamoDBClientBuilder.defaultClient();
        this.dynamoDB = new DynamoDB(client);
        this.cardTable = dynamoDB.getTable(System.getenv("CARD_TABLE"));
        this.transactionTable = dynamoDB.getTable(System.getenv("TRANSACTION_TABLE"));
        this.sqsClient = AmazonSQSClientBuilder.defaultClient();
        this.sqsQueueUrl = System.getenv("SQS_QUEUE_URL_NOTIFICATION");
    }

    @Override
    public APIGatewayProxyResponseEvent handleRequest(APIGatewayProxyRequestEvent request, Context context) {
        try {
            String cardId = request.getPathParameters().get("card_id");

            Map<String, Object> body = objectMapper.readValue(request.getBody(), Map.class);
            String merchant = (String) body.get("merchant");
            Double amount = Double.parseDouble(body.get("amount").toString());

            Item cardItem = cardTable.getItem("cardId", cardId);
            if (cardItem == null) {
                return new APIGatewayProxyResponseEvent()
                        .withStatusCode(404)
                        .withBody("{\"error\":\"Card not found\"}");
            }

            double currentBalance = cardItem.getDouble("balance");
            double newBalance = currentBalance - amount;
            if (newBalance < 0) {
                return new APIGatewayProxyResponseEvent()
                        .withStatusCode(400)
                        .withBody("{\"error\":\"Insufficient balance\"}");
            }
            cardTable.updateItem("cardId", cardId, "set balance = :b", new HashMap<String, Object>() {{
                put(":b", newBalance);
            }});

            String uuid = UUID.randomUUID().toString();
            String timestamp = Instant.now().toString();

            transactionTable.putItem(new Item()
                    .withPrimaryKey("uuid", uuid)
                    .withString("cardId", cardId)
                    .withString("merchant", merchant)
                    .withNumber("amount", amount)
                    .withString("type", "PAYMENT")
                    .withString("status", "SUCCESS")
                    .withString("timestamp", timestamp)
            );

            Map<String, Object> eventPayload = new HashMap<>();
            eventPayload.put("eventType", "TRANSACTION.PAID");
            eventPayload.put("uuid", uuid);
            eventPayload.put("cardId", cardId);
            eventPayload.put("merchant", merchant);
            eventPayload.put("amount", amount);
            eventPayload.put("timestamp", timestamp);

            sqsClient.sendMessage(new SendMessageRequest()
                    .withQueueUrl(sqsQueueUrl)
                    .withMessageBody(objectMapper.writeValueAsString(eventPayload)));

            Map<String, Object> responseBody = new HashMap<>();
            responseBody.put("uuid", uuid);
            responseBody.put("cardId", cardId);
            responseBody.put("merchant", merchant);
            responseBody.put("amount", amount);
            responseBody.put("status", "SUCCESS");
            responseBody.put("newBalance", newBalance);
            responseBody.put("timestamp", timestamp);

            return new APIGatewayProxyResponseEvent()
                    .withStatusCode(200)
                    .withBody(objectMapper.writeValueAsString(responseBody));

        } catch (Exception e) {
            context.getLogger().log("Error: " + e.getMessage());
            return new APIGatewayProxyResponseEvent()
                    .withStatusCode(500)
                    .withBody("{\"error\":\"Internal server error\"}");
        }
    }
}
