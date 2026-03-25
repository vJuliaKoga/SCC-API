package com.example.grpcbackend.config;

import com.example.grpcbackend.service.HealthGrpcService;
import io.grpc.Server;
import io.grpc.ServerBuilder;
import jakarta.annotation.PreDestroy;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import java.io.IOException;

/*
    gRPC サーバを Spring Boot と一緒に起動するためのコンポーネント
*/
@Component
public class GrpcServerRunner {

    private final int port;
    private final HealthGrpcService healthGrpcService;
    private Server server;

    public GrpcServerRunner(
            @Value("${grpc.server.port}") int port,
            HealthGrpcService healthGrpcService) throws IOException {
        this.port = port;
        this.healthGrpcService = healthGrpcService;
        start();
    }

    /*
     * アプリケーション起動時に gRPC サーバを開始する
     */
    private void start() throws IOException {
        this.server = ServerBuilder
                .forPort(port)
                .addService(healthGrpcService)
                .build()
                .start();

        Runtime.getRuntime().addShutdownHook(new Thread(() -> {
            if (server != null) {
                server.shutdown();
            }
        }));
    }

    /*
     * アプリケーション終了時に gRPC サーバを停止する
     */
    @PreDestroy
    public void stop() {
        if (server != null) {
            server.shutdown();
        }
    }
}