import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/word.dart';
import '../theme/theme_provider.dart';
import 'dart:math';

class Stage3Screen extends StatefulWidget {
  final List<Word> words;
  final Function(List<Word>) onComplete;

  const Stage3Screen({
    Key? key,
    required this.words,
    required this.onComplete,
  }) : super(key: key);

  @override
  _Stage3ScreenState createState() => _Stage3ScreenState();
}

class _Stage3ScreenState extends State<Stage3Screen>
    with TickerProviderStateMixin {
  int _currentIndex = 0;
  List<String> _options = [];
  bool _isCorrect = false;
  bool _showError = false;
  String? _selectedOption;
  late AnimationController _flipController;
  late Animation<double> _flipAnimation;
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;
  List<String> _nextOptions = [];
  Word? _nextWord;
  List<Word> _learnedWords = [];
  bool _isAnimating = false;

  @override
  void initState() {
    super.initState();
    _generateOptions();
    if (_currentIndex < widget.words.length - 1) {
      _nextWord = widget.words[_currentIndex + 1];
      _generateNextOptions();
    }
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
            _selectedOption = null;
            _showError = false;
            _options = List.from(_nextOptions);
            if (_currentIndex < widget.words.length - 1) {
              _nextWord = widget.words[_currentIndex + 1];
              _generateNextOptions();
            } else {
              _nextWord = null;
              _nextOptions = [];
            }
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

    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _shakeAnimation = Tween<double>(
      begin: 0.0,
      end: 10.0,
    ).animate(CurvedAnimation(
      parent: _shakeController,
      curve: Curves.elasticIn,
    ));

    _shakeController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _shakeController.reverse();
      }
    });
  }

  @override
  void dispose() {
    _flipController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  void _generateOptions() {
    final currentWord = widget.words[_currentIndex];
    final random = Random();
    _options = [currentWord.russian];

    final otherWords = widget.words
        .where((w) => w != currentWord)
        .map((w) => w.russian)
        .toList();

    while (_options.length < 5 && otherWords.isNotEmpty) {
      final randomIndex = random.nextInt(otherWords.length);
      _options.add(otherWords[randomIndex]);
      otherWords.removeAt(randomIndex);
    }

    _options.shuffle();
  }

  void _generateNextOptions() {
    if (_nextWord == null) return;

    final random = Random();
    _nextOptions = [_nextWord!.russian];

    final otherWords = widget.words
        .where((w) => w != _nextWord)
        .map((w) => w.russian)
        .toList();

    while (_nextOptions.length < 5 && otherWords.isNotEmpty) {
      final randomIndex = random.nextInt(otherWords.length);
      _nextOptions.add(otherWords[randomIndex]);
      otherWords.removeAt(randomIndex);
    }

    _nextOptions.shuffle();
  }

  void _checkAnswer(String selected) {
    if (_isAnimating || _isCorrect || _showError) return;

    final word = widget.words[_currentIndex];
    final isCorrectAnswer = selected == word.russian;

    setState(() {
      _selectedOption = selected;
      _showError = !isCorrectAnswer;
      _isCorrect = isCorrectAnswer;

      if (isCorrectAnswer && !_learnedWords.contains(word)) {
        _learnedWords.add(word);
      }
    });

    if (isCorrectAnswer) {
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
          });
        } else {
          widget.onComplete(_learnedWords);
        }
      });
    } else {
      _shakeController.forward(from: 0.0).then((_) {
        if (mounted) {
          setState(() {
            _selectedOption = null;
            _showError = false;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final maxWidth = screenWidth > 600 ? 600.0 : screenWidth * 0.9;
    final word = widget.words[_currentIndex];

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
                              ? _buildCardContent(word, _options, themeProvider)
                              : Transform(
                                  transform: Matrix4.identity()..rotateY(pi),
                                  alignment: Alignment.center,
                                  child: _buildCardContent(
                                      word, _options, themeProvider),
                                ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCardContent(
      Word word, List<String> options, ThemeProvider themeProvider) {
    return Column(
      children: [
        Text(
          word.english,
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: themeProvider.themeColor,
          ),
        ),
        SizedBox(height: 32),
        AnimatedBuilder(
          animation: _shakeAnimation,
          builder: (context, child) {
            return Transform.translate(
              offset: _showError
                  ? Offset(
                      _shakeAnimation.value * sin(_shakeAnimation.value * 3), 0)
                  : Offset.zero,
              child: Column(
                children: options.map((option) {
                  final isSelected = _selectedOption == option;
                  final isCorrect = option == word.russian && isSelected;
                  final isWrong =
                      option == _selectedOption && option != word.russian;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Material(
                      color: isCorrect
                          ? Colors.green
                          : isWrong
                              ? Colors.red
                              : themeProvider.themeBackgroundColor,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        onTap: (_isCorrect || _isAnimating || _showError)
                            ? null
                            : () => _checkAnswer(option),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: double.infinity,
                          padding: EdgeInsets.symmetric(
                            vertical: 16,
                            horizontal: 20,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: isCorrect
                                  ? Colors.green
                                  : isWrong
                                      ? Colors.red
                                      : themeProvider.themeColor,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            option,
                            style: TextStyle(
                              fontSize: 18,
                              color: themeProvider.themeColor,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            );
          },
        ),
      ],
    );
  }
}
