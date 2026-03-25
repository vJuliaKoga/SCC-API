package com.example.bff.config;

import com.example.bff.proto.OrderServiceGrpc;
import com.example.bff.proto.UserServiceGrpc;
import io.grpc.ManagedChannel;
import io.grpc.ManagedChannelBuilder;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.client.RestClient;

/*
    BFF 全体で利用する Bean を定義する
*/
@Configuration
@EnableConfigurationProperties(AppProperties.class)
public class BffConfig {

    @Bean
    public RestClient restClient(AppProperties appProperties) {
        return RestClient.builder()
            .baseUrl(appProperties.getRestBackend().getBaseUrl())
            .build();
    }

    @Bean(destroyMethod = "shutdownNow")
    public ManagedChannel grpcManagedChannel(AppProperties appProperties) {
        return ManagedChannelBuilder
            .forAddress(
                appProperties.getGrpcBackend().getHost(),
                appProperties.getGrpcBackend().getPort()
            )
            .usePlaintext()
            .build();
    }

    @Bean
    public UserServiceGrpc.UserServiceBlockingStub userServiceBlockingStub(
        ManagedChannel grpcManagedChannel
    ) {
        return UserServiceGrpc.newBlockingStub(grpcManagedChannel);
    }

    @Bean
    public OrderServiceGrpc.OrderServiceBlockingStub orderServiceBlockingStub(
        ManagedChannel grpcManagedChannel
    ) {
        return OrderServiceGrpc.newBlockingStub(grpcManagedChannel);
    }
}