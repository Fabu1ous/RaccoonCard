import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/word.dart';
import '../theme/theme_provider.dart';
import 'dart:math';

class Stage6Screen extends StatefulWidget {
  final List<Word> words;
  final Function() onNextStage;

  const Stage6Screen({
    Key? key,
    required this.words,
    required this.onNextStage,
  }) : super(key: key);

  @override
  _Stage6ScreenState createState() => _Stage6ScreenState();
}

class _Stage6ScreenState extends State<Stage6Screen>
    with TickerProviderStateMixin {
  int _currentIndex = 0;
  bool _showTranslation = false;
  TextEditingController _answerController = TextEditingController();
  bool _isCorrect = false;
  bool _showError = false;
  bool _hasWrongAttempt = false;
  FocusNode _focusNode = FocusNode();
  late AnimationController _flipController;
  late Animation<double> _flipAnimation;
  bool _isAnimating = false;

  @override
  void initState() {
    super.initState();

    _flipController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _flipAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(
      parent: _flipController,
      curve: Curves.easeInOut,
    ))
      ..addListener(() {
        if (_isAnimating && _flipAnimation.value >= 0.5) {
          setState(() {
            _isAnimating = false;
            _currentIndex++;
            _isCorrect = false;
            _showError = false;
            _hasWrongAttempt = false;
            _showTranslation = false;
            _answerController.clear();
          });
        }
      });

    // Анимация появления первой карточки справа
    if (_currentIndex == 0) {
      _flipController.value = 0.5;
      Future.delayed(Duration(milliseconds: 100), () {
        _flipController.animateTo(0,
            duration: Duration(milliseconds: 400), curve: Curves.easeInOut);
      });
    }

    Future.delayed(Duration(milliseconds: 100), () {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _answerController.dispose();
    _focusNode.dispose();
    _flipController.dispose();
    super.dispose();
  }

  void _checkAnswer() {
    if (_isAnimating) return;

    final answer = _answerController.text.trim().toLowerCase();
    final word = widget.words[_currentIndex];

    final correctAnswers =
        word.english.split(',').map((e) => e.trim().toLowerCase()).toList();

    final processedCorrectAnswers = correctAnswers.map((correctAnswer) {
      return correctAnswer.replaceAll(RegExp(r'\([^)]*\)'), '').trim();
    }).toList();

    if (processedCorrectAnswers.contains(answer)) {
      setState(() {
        _isCorrect = true;
        _showError = false;
        _hasWrongAttempt = false;
        _showTranslation = false;
      });

      Future.delayed(Duration(milliseconds: 500), () {
        if (_currentIndex < widget.words.length - 1) {
          setState(() {
            _isAnimating = true;
          });
          _flipController
              .animateTo(1,
                  duration: Duration(milliseconds: 400),
                  curve: Curves.easeInOut)
              .then((_) {
            _flipController.value = 0;
            Future.delayed(Duration(milliseconds: 50), () {
              _focusNode.requestFocus();
            });
          });
        } else {
          widget.onNextStage();
        }
      });
    } else {
      setState(() {
        _showError = true;
        _isCorrect = false;
        _hasWrongAttempt = true;
      });
    }
  }

  void _showHint() {
    if (_hasWrongAttempt) {
      setState(() {
        _showTranslation = !_showTranslation;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final word = widget.words[_currentIndex];
    final screenWidth = MediaQuery.of(context).size.width;
    final maxWidth = screenWidth > 600 ? 600.0 : screenWidth * 0.9;

    return Scaffold(
      backgroundColor: themeProvider.scaffoldBackgroundColor,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Container(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Слово ${_currentIndex + 1} из ${widget.words.length}',
                  style: TextStyle(
                    fontSize: 18,
                    color: themeProvider.themeColor,
                  ),
                ),
                SizedBox(height: 32),
                AnimatedBuilder(
                  animation: _flipAnimation,
                  builder: (context, child) {
                    final progress = _flipAnimation.value;
                    final showFrontSide = progress < 0.5;

                    return Transform(
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.001)
                        ..rotateY(progress * pi),
                      alignment: Alignment.center,
                      child: Card(
                        elevation: 4,
                        color: themeProvider.themeBackgroundColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: showFrontSide
                              ? _buildCardContent(word, themeProvider)
                              : Transform(
                                  transform: Matrix4.identity()..rotateY(pi),
                                  alignment: Alignment.center,
                                  child: _buildCardContent(word, themeProvider),
                                ),
                        ),
                      ),
                    );
                  },
                ),
                SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _hasWrongAttempt ? _showHint : null,
                        child: Text(
                          _showTranslation
                              ? 'Скрыть'
                              : 'Подсказка',
                          style: TextStyle(fontSize: 16, color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: themeProvider.isDarkTheme
                              ? Colors.grey[700]
                              : Colors.brown[400],
                          padding:
                              EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _checkAnswer,
                        child: Text(
                          'Проверить',
                          style: TextStyle(fontSize: 16, color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: themeProvider.isDarkTheme
                              ? Colors.grey[700]
                              : Colors.brown[400],
                          padding:
                              EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCardContent(Word word, ThemeProvider themeProvider) {
    return Column(
      children: [
        Text(
          word.russian,
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: themeProvider.themeColor,
          ),
        ),
        SizedBox(height: 24),
        TextField(
          controller: _answerController,
          focusNode: _focusNode,
          decoration: InputDecoration(
            labelText: 'Введите слово на английском',
            labelStyle: TextStyle(color: themeProvider.themeColor),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: themeProvider.themeColor),
            ),
            errorText: _showError ? 'Неправильный ответ' : null,
            suffixIcon: _isCorrect
                ? Icon(Icons.check_circle, color: Colors.green)
                : null,
          ),
          style: TextStyle(color: themeProvider.themeColor),
          cursorColor: themeProvider.themeColor,
          onSubmitted: (_) => _checkAnswer(),
        ),
        if (_showTranslation && _hasWrongAttempt)
          Padding(
            padding: const EdgeInsets.only(top: 16.0),
            child: Column(
              children: [
                Text(
                  'Подсказка: ${word.english}',
                  style: TextStyle(
                    fontSize: 16,
                    color: themeProvider.themeColor,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  word.transcription,
                  style: TextStyle(
                    fontSize: 14,
                    color: themeProvider.themeColor,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
