package org.example;

import com.amazonaws.services.lambda.runtime.Context;
import com.amazonaws.services.lambda.runtime.RequestHandler;
import com.amazonaws.services.lambda.runtime.events.APIGatewayProxyRequestEvent;
import com.amazonaws.services.lambda.runtime.events.APIGatewayProxyResponseEvent;
import com.fasterxml.jackson.databind.ObjectMapper;
import software.amazon.awssdk.core.sync.RequestBody;
import software.amazon.awssdk.services.dynamodb.DynamoDbClient;
import software.amazon.awssdk.services.dynamodb.model.AttributeValue;
import software.amazon.awssdk.services.dynamodb.model.ScanRequest;
import software.amazon.awssdk.services.dynamodb.model.ScanResponse;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.presigner.S3Presigner;
import software.amazon.awssdk.services.s3.presigner.model.GetObjectPresignRequest;
import software.amazon.awssdk.services.s3.model.PutObjectRequest;
import software.amazon.awssdk.services.s3.model.GetObjectRequest;
import software.amazon.awssdk.services.sqs.SqsClient;
import software.amazon.awssdk.services.sqs.model.SendMessageRequest;

import java.net.URL;
import java.time.Duration;
import java.time.Instant;
import java.time.format.DateTimeFormatter;
import java.util.*;

public class CardGetReportLambda implements RequestHandler<APIGatewayProxyRequestEvent, APIGatewayProxyResponseEvent> {

    private final ObjectMapper objectMapper = new ObjectMapper();
    private final DynamoDbClient ddb;
    private final S3Client s3;
    private final S3Presigner presigner;
    private final SqsClient sqs;
    private final String TRANSACTION_TABLE = System.getenv().getOrDefault("TRANSACTIONS_TABLE", "transaction-table");
    private final String REPORTS_BUCKET = System.getenv().getOrDefault("REPORTS_BUCKET", "transactions-report-bucket");
    private final String NOTIFICATION_QUEUE_URL = System.getenv().get("SQS_QUEUE_URL_NOTIFICATION");

    public CardGetReportLambda() {
        this.ddb = DynamoDbClient.create();
        this.s3 = S3Client.create();
        this.presigner = S3Presigner.create();
        this.sqs = SqsClient.create();
    }

    @Override
    public APIGatewayProxyResponseEvent handleRequest(APIGatewayProxyRequestEvent req, Context ctx) {
        try {
            String cardId = null;
            if (req.getPathParameters() != null) {
                cardId = req.getPathParameters().get("card_id");
            }
            if (cardId == null || cardId.isBlank()) {
                return errorResponse(400, "Missing path parameter card_id");
            }

            Map<String, String> queryParams = req.getQueryStringParameters();
            if (queryParams == null || !queryParams.containsKey("start") || !queryParams.containsKey("end")) {
                return errorResponse(400, "Missing query parameters start or end");
            }
            String start = queryParams.get("start");
            String end = queryParams.get("end");

            List<Map<String, AttributeValue>> items = scanTransactions(cardId, start, end);

            String csv = buildCsv(items);

            String timestamp = DateTimeFormatter.ISO_INSTANT.format(Instant.now()).replace(":", "-");
            String key = String.format("reports/%s/%s.csv", cardId, timestamp);
            s3.putObject(PutObjectRequest.builder()
                            .bucket(REPORTS_BUCKET)
                            .key(key)
                            .contentType("text/csv")
                            .build(),
                    RequestBody.fromString(csv));

            String presignedUrl = presignUrl(REPORTS_BUCKET, key, Duration.ofHours(24));

            sendNotification(presignedUrl);

            Map<String, String> resp = new HashMap<>();
            resp.put("message", "Report generated successfully");
            resp.put("url", presignedUrl);

            return new APIGatewayProxyResponseEvent()
                    .withStatusCode(200)
                    .withBody(objectMapper.writeValueAsString(resp))
                    .withHeaders(Map.of("Content-Type", "application/json"));
        } catch (Exception e) {
            ctx.getLogger().log("Error: " + e.getMessage());
            return errorResponse(500, "Internal error: " + e.getMessage());
        }
    }

    private List<Map<String, AttributeValue>> scanTransactions(String cardId, String start, String end) {
        Map<String, AttributeValue> exprVals = new HashMap<>();
        exprVals.put(":cid", AttributeValue.builder().s(cardId).build());
        exprVals.put(":start", AttributeValue.builder().s(start).build());
        exprVals.put(":end", AttributeValue.builder().s(end).build());

        String filter = "cardId = :cid AND createdAt BETWEEN :start AND :end";

        ScanRequest scanReq = ScanRequest.builder()
                .tableName(TRANSACTION_TABLE)
                .filterExpression(filter)
                .expressionAttributeValues(exprVals)
                .build();

        ScanResponse sr = ddb.scan(scanReq);
        return sr.items() == null ? Collections.emptyList() : sr.items();
    }

    private String buildCsv(List<Map<String, AttributeValue>> items) {
        StringBuilder sb = new StringBuilder();
        sb.append("transactionId,cardId,merchant,amount,type,createdAt\n");
        for (Map<String, AttributeValue> item : items) {
            String id = safe(item.get("uuid"));
            String cardId = safe(item.get("cardId"));
            String merchant = escapeCsv(safe(item.get("merchant")));
            String amount = item.containsKey("amount") && item.get("amount").n() != null ? item.get("amount").n() : safe(item.get("amount"));
            String type = safe(item.get("type"));
            String createdAt = safe(item.get("createdAt"));
            sb.append(String.join(",", id, cardId, "\"" + merchant + "\"", amount, type, createdAt)).append("\n");
        }
        return sb.toString();
    }

    private String presignUrl(String bucket, String key, Duration ttl) {
        GetObjectRequest getObjectRequest = GetObjectRequest.builder()
                .bucket(bucket)
                .key(key)
                .build();

        GetObjectPresignRequest presignRequest = GetObjectPresignRequest.builder()
                .signatureDuration(ttl)
                .getObjectRequest(getObjectRequest)
                .build();

        URL url = presigner.presignGetObject(presignRequest).url();
        return url.toString();
    }

    private void sendNotification(String presignedUrl) {
        if (NOTIFICATION_QUEUE_URL == null || NOTIFICATION_QUEUE_URL.isBlank()) return;

        try {
            Map<String, Object> payload = new HashMap<>();
            payload.put("type", "REPORT.ACTIVITY");
            Map<String, Object> data = new HashMap<>();
            data.put("date", Instant.now().toString());
            data.put("url", presignedUrl);
            payload.put("data", data);

            String msgBody = objectMapper.writeValueAsString(payload);

            SendMessageRequest smr = SendMessageRequest.builder()
                    .queueUrl(NOTIFICATION_QUEUE_URL)
                    .messageBody(msgBody)
                    .build();

            sqs.sendMessage(smr);
        } catch (Exception ignored) {
        }
    }

    private static String safe(AttributeValue a) {
        if (a == null) return "";
        if (a.s() != null) return a.s();
        if (a.n() != null) return a.n();
        if (a.bool() != null) return String.valueOf(a.bool());
        return "";
    }

    private static String escapeCsv(String s) {
        if (s == null) return "";
        return s.replace("\"", "\"\"");
    }

    private APIGatewayProxyResponseEvent errorResponse(int code, String message) {
        try {
            Map<String, String> m = Map.of("error", message);
            return new APIGatewayProxyResponseEvent()
                    .withStatusCode(code)
                    .withBody(objectMapper.writeValueAsString(m))
                    .withHeaders(Map.of("Content-Type", "application/json"));
        } catch (Exception e) {
            return new APIGatewayProxyResponseEvent().withStatusCode(500).withBody("{\"error\":\"internal\"}");
        }
    }
}
