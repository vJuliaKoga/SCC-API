package com.example.restbackend.service;

import com.example.restbackend.model.UserResponse;
import org.springframework.stereotype.Service;

/*
    ユーザー取得の業務ロジック
*/
@Service
public class UserService {

    public UserResponse getUserById(String userId) {
        if (userId == null || userId.isBlank()) {
            throw new IllegalArgumentException("ユーザーIDは必須です。");
        }

        if (!"1".equals(userId)) {
            throw new IllegalStateException("指定したユーザーは存在しません。");
        }

        return new UserResponse(
            "1",
            "Sam Ple",
            "ACTIVE"
        );
    }
}