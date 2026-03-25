package com.example.bff.config;

import org.springframework.boot.context.properties.ConfigurationProperties;

/*
    アプリケーション設定をまとめて扱う
*/
@ConfigurationProperties(prefix = "app")
public class AppProperties {

    private String callMode;
    private final RestBackend restBackend = new RestBackend();
    private final GrpcBackend grpcBackend = new GrpcBackend();

    public String getCallMode() {
        return callMode;
    }

    public void setCallMode(String callMode) {
        this.callMode = callMode;
    }

    public RestBackend getRestBackend() {
        return restBackend;
    }

    public GrpcBackend getGrpcBackend() {
        return grpcBackend;
    }

    public static class RestBackend {

        private String baseUrl;

        public String getBaseUrl() {
            return baseUrl;
        }

        public void setBaseUrl(String baseUrl) {
            this.baseUrl = baseUrl;
        }
    }

    public static class GrpcBackend {

        private String host;
        private int port;

        public String getHost() {
            return host;
        }

        public void setHost(String host) {
            this.host = host;
        }

        public int getPort() {
            return port;
        }

        public void setPort(int port) {
            this.port = port;
        }
    }
}