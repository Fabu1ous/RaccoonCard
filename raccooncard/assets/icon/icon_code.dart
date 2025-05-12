// Этот файл содержит код для генерации иконки приложения
// Вы можете создать проект Flutter с этим кодом и экспортировать изображение

import 'package:flutter/material.dart';

void main() {
  runApp(MaterialApp(
    home: Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Container(
          width: 1024,
          height: 1024,
          color: Color(0xFF795548), // коричневый цвет
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.book,
                  size: 600,
                  color: Colors.white,
                ),
                Text(
                  "RC",
                  style: TextStyle(
                    fontSize: 240,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  ));
} 