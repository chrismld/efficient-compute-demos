package com.example.jsonprocessor;

import com.sun.net.httpserver.HttpExchange;
import com.sun.net.httpserver.HttpHandler;
import com.sun.net.httpserver.HttpServer;
import org.json.JSONArray;
import org.json.JSONObject;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStreamReader;
import java.io.OutputStream;
import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import java.util.stream.Collectors;

public class Main {
    public static void main(String[] args) throws Exception {
        int port = Integer.parseInt(System.getenv().getOrDefault("PORT", "8080"));
        
        HttpServer server = HttpServer.create(new InetSocketAddress(port), 0);
        server.createContext("/api/process", new ProcessHandler());
        server.createContext("/health", new HealthHandler());
        server.setExecutor(null);
        
        System.out.println("JSON Processing Service started on port " + port);
        System.out.println("Java Version: " + System.getProperty("java.version"));
        System.out.println("Architecture: " + System.getProperty("os.arch"));
        System.out.println("Available Processors: " + Runtime.getRuntime().availableProcessors());
        
        server.start();
    }
    
    static class ProcessHandler implements HttpHandler {
        @Override
        public void handle(HttpExchange exchange) throws IOException {
            if (!"POST".equals(exchange.getRequestMethod())) {
                sendResponse(exchange, 405, "Method not allowed");
                return;
            }
            
            try {
                String requestBody = new BufferedReader(new InputStreamReader(exchange.getRequestBody()))
                    .lines()
                    .collect(Collectors.joining("\n"));
                
                JSONObject request = new JSONObject(requestBody);
                JSONArray records = request.getJSONArray("records");
                
                // Process the records (contains performance issues)
                List<Map<String, Object>> processedRecords = processRecords(records);
                
                JSONObject response = new JSONObject();
                response.put("status", "success");
                response.put("processed", processedRecords.size());
                
                sendResponse(exchange, 200, response.toString());
                
            } catch (Exception e) {
                e.printStackTrace();
                sendResponse(exchange, 500, "Processing error: " + e.getMessage());
            }
        }
        
        // PERFORMANCE BOTTLENECK: This method has multiple inefficiencies
        private List<Map<String, Object>> processRecords(JSONArray records) {
            List<Map<String, Object>> results = new ArrayList<>();
            
            for (int i = 0; i < records.length(); i++) {
                JSONObject record = records.getJSONObject(i);
                
                // Issue 1: Repeated string concatenation (not StringBuilder)
                String processedData = "";
                for (int j = 0; j < 100; j++) {
                    processedData += sanitizeString(record.optString("data", "")) + "|";
                }
                
                // Issue 2: Inefficient regex compilation inside loop
                Pattern emailPattern = Pattern.compile("[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}");
                String email = record.optString("email", "");
                Matcher matcher = emailPattern.matcher(email);
                boolean isValidEmail = matcher.matches();
                
                // Issue 3: Unnecessary JSON parsing and re-parsing
                String metadataStr = record.optJSONObject("metadata") != null 
                    ? record.getJSONObject("metadata").toString() 
                    : "{}";
                JSONObject metadata = new JSONObject(metadataStr);
                
                // Issue 4: Creating many intermediate objects
                Map<String, Object> result = new HashMap<>();
                result.put("id", record.optString("id"));
                result.put("processed_data", processedData.substring(0, Math.min(50, processedData.length())));
                result.put("email_valid", isValidEmail);
                result.put("metadata_keys", metadata.length());
                result.put("timestamp", System.currentTimeMillis());
                
                // Issue 5: Inefficient list growth (ArrayList resizing)
                results.add(result);
            }
            
            return results;
        }
        
        // Issue 6: Inefficient character-by-character string processing
        private String sanitizeString(String input) {
            String result = "";
            for (int i = 0; i < input.length(); i++) {
                char c = input.charAt(i);
                if (Character.isLetterOrDigit(c) || c == ' ' || c == '-' || c == '_') {
                    result += c;  // String concatenation in loop
                }
            }
            return result;
        }
        
        private void sendResponse(HttpExchange exchange, int statusCode, String response) throws IOException {
            byte[] bytes = response.getBytes(StandardCharsets.UTF_8);
            exchange.getResponseHeaders().set("Content-Type", "application/json");
            exchange.sendResponseHeaders(statusCode, bytes.length);
            OutputStream os = exchange.getResponseBody();
            os.write(bytes);
            os.close();
        }
    }
    
    static class HealthHandler implements HttpHandler {
        @Override
        public void handle(HttpExchange exchange) throws IOException {
            JSONObject health = new JSONObject();
            health.put("status", "healthy");
            health.put("java_version", System.getProperty("java.version"));
            health.put("architecture", System.getProperty("os.arch"));
            health.put("available_processors", Runtime.getRuntime().availableProcessors());
            health.put("free_memory_mb", Runtime.getRuntime().freeMemory() / (1024 * 1024));
            health.put("total_memory_mb", Runtime.getRuntime().totalMemory() / (1024 * 1024));
            
            byte[] bytes = health.toString().getBytes(StandardCharsets.UTF_8);
            exchange.getResponseHeaders().set("Content-Type", "application/json");
            exchange.sendResponseHeaders(200, bytes.length);
            OutputStream os = exchange.getResponseBody();
            os.write(bytes);
            os.close();
        }
    }
}
