package com.example.restbackend.model;

/*
    ユーザー取得レスポンス
*/
public record UserResponse(
    String userId,
    String name,
    String status
) {
}