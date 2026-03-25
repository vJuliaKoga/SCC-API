package com.example.bff.model;

/*
    エラーレスポンス
*/
public record ErrorResponse(
    String code,
    String message
) {
}