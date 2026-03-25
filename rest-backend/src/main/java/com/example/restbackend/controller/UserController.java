package com.example.restbackend.controller;

import com.example.restbackend.model.UserResponse;
import com.example.restbackend.service.UserService;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RestController;

/*
    ユーザー取得用コントローラ
*/
@RestController
public class UserController {

    private final UserService userService;

    public UserController(UserService userService) {
        this.userService = userService;
    }

    @GetMapping("/api/users/{id}")
    public UserResponse getUser(@PathVariable("id") String id) {
        return userService.getUserById(id);
    }
}