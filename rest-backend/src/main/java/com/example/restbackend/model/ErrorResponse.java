package com.example.restbackend.model;

/*
    エラーレスポンス
*/
public record ErrorResponse(
    String code,
    String message
) {
}