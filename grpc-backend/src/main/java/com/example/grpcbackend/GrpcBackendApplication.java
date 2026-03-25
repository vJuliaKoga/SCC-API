package com.example.grpcbackend;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

/*
    gRPC Backend の起動クラス
*/
@SpringBootApplication
public class GrpcBackendApplication {

    public static void main(String[] args) {
        SpringApplication.run(GrpcBackendApplication.class, args);
    }
}