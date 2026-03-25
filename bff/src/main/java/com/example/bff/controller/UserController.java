package com.example.bff.controller;

import com.example.bff.model.UserResponse;
import com.example.bff.service.BffService;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RestController;

/*
    ユーザー取得用コントローラ
*/
@RestController
public class UserController {

    private final BffService bffService;

    public UserController(BffService bffService) {
        this.bffService = bffService;
    }

    @GetMapping("/api/users/{id}")
    public UserResponse getUser(@PathVariable("id") String id) {
        return bffService.getUser(id);
    }
}