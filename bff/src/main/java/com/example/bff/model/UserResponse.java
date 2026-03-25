package com.example.bff.model;

/*
    ユーザー取得レスポンス
*/
public record UserResponse(
    String userId,
    String name,
    String status
) {
}