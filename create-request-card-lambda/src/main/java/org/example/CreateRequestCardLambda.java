package org.example;

import com.amazonaws.services.lambda.runtime.Context;
import com.amazonaws.services.lambda.runtime.LambdaLogger;
import com.amazonaws.services.lambda.runtime.RequestHandler;
import com.amazonaws.services.lambda.runtime.events.SQSEvent;
import com.amazonaws.services.lambda.runtime.events.SQSBatchResponse;
import com.amazonaws.services.sqs.AmazonSQS;
import com.amazonaws.services.sqs.AmazonSQSClientBuilder;
import com.amazonaws.services.sqs.model.SendMessageRequest;
import com.amazonaws.services.dynamodbv2.AmazonDynamoDB;
import com.amazonaws.services.dynamodbv2.AmazonDynamoDBClientBuilder;
import com.amazonaws.services.dynamodbv2.model.AttributeValue;
import com.amazonaws.services.dynamodbv2.model.PutItemRequest;
import com.fasterxml.jackson.databind.ObjectMapper;

import java.time.Instant;
import java.util.*;

public class CreateRequestCardLambda implements RequestHandler<SQSEvent, SQSBatchResponse> {

    private final AmazonDynamoDB dynamoDb = AmazonDynamoDBClientBuilder.defaultClient();
    private final AmazonSQS sqsClient = AmazonSQSClientBuilder.defaultClient();
    private final ObjectMapper objectMapper = new ObjectMapper();
    private static final String CARD_TABLE = "card-table";
    private static final String QUEUE_URL_NOTIFICATION = System.getenv("SQS_QUEUE_URL_NOTIFICATION");
    private static final String DLQ_URL = System.getenv("SQS_DLQ_URL");

    @Override
    public SQSBatchResponse handleRequest(SQSEvent sqsEvent, Context context) {

        LambdaLogger logger = context.getLogger();
        List<SQSBatchResponse.BatchItemFailure> batchFailures = new ArrayList<>();

        for (SQSEvent.SQSMessage msg : sqsEvent.getRecords()) {
            try {
                logger.log("Processing SQS message: " + msg.getBody());

                Map<String, Object> messageMap = objectMapper.readValue(msg.getBody(), Map.class);
                Map<String, String> data = (Map<String, String>) messageMap.get("data");

                String requestType = data.get("request");
                String userId = data.get("userId");
                String cardId = UUID.randomUUID().toString();
                String createdAt = Instant.now().toString();

                Map<String, AttributeValue> item = new HashMap<>();
                item.put("uuid", new AttributeValue(cardId));
                item.put("userId", new AttributeValue(userId));
                item.put("createdAt", new AttributeValue(createdAt));

                double amount = 0;

                if ("DEBIT".equalsIgnoreCase(requestType)) {
                    item.put("type", new AttributeValue("DEBIT"));
                    item.put("status", new AttributeValue("ACTIVATED"));
                    item.put("balance", new AttributeValue().withN("0"));
                } else if ("CREDIT".equalsIgnoreCase(requestType)) {
                    int score = new Random().nextInt(101);
                    amount = 100 + (score / 100.0) * (10_000_000 - 100);

                    item.put("type", new AttributeValue("CREDIT"));
                    item.put("status", new AttributeValue("PENDING"));
                    item.put("balance", new AttributeValue().withN(String.valueOf(amount)));
                } else {
                    throw new RuntimeException("Unknown request type: " + requestType);
                }

                dynamoDb.putItem(new PutItemRequest()
                        .withTableName(CARD_TABLE)
                        .withItem(item));
                logger.log("Saved card in DynamoDB: " + cardId);

                Map<String, Object> notification = new HashMap<>();
                notification.put("type", "CARD.CREATE");

                Map<String, Object> notificationData = new HashMap<>();
                notificationData.put("date", createdAt);
                notificationData.put("type", requestType.toUpperCase());
                notificationData.put("amount", amount);

                notification.put("data", notificationData);

                String notificationJson = objectMapper.writeValueAsString(notification);

                sqsClient.sendMessage(new SendMessageRequest()
                        .withQueueUrl(QUEUE_URL_NOTIFICATION)
                        .withMessageBody(notificationJson));

                logger.log("Sent notification to SQS: " + notificationJson);

            } catch (Exception e) {
                logger.log("Error processing message, sending to DLQ: " + e.getMessage());

                try {
                    sqsClient.sendMessage(new SendMessageRequest()
                            .withQueueUrl(DLQ_URL)
                            .withMessageBody(msg.getBody()));
                    logger.log("Message sent to DLQ: " + DLQ_URL);
                } catch (Exception dlqEx) {
                    logger.log("Failed to send message to DLQ: " + dlqEx.getMessage());
                }

                batchFailures.add(new SQSBatchResponse.BatchItemFailure(msg.getMessageId()));
            }
        }

        return new SQSBatchResponse(batchFailures);
    }
}
