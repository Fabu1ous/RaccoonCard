import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/word.dart';
import '../theme/theme_provider.dart';
import 'dart:math';

class Stage2Screen extends StatefulWidget {
  final List<Word> words;
  final Function(List<Word>) onComplete;

  const Stage2Screen({
    Key? key,
    required this.words,
    required this.onComplete,
  }) : super(key: key);

  @override
  _Stage2ScreenState createState() => _Stage2ScreenState();
}

class _Stage2ScreenState extends State<Stage2Screen>
    with SingleTickerProviderStateMixin {
  List<Word> _shuffledWords = [];
  List<String> _shuffledTranslations = [];
  String? _selectedWord;
  String? _selectedTranslation;
  Map<String, String> _matchedPairs = {};
  List<Word> _learnedWords = [];
  bool _isWrongMatch = false;
  late AnimationController _animationController;
  late Animation<Color?> _colorAnimation;

  @override
  void initState() {
    super.initState();
    _initializeGame();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _colorAnimation = ColorTween(
      begin: Colors.transparent,
      end: Colors.red,
    ).animate(_animationController)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _animationController.reverse();
        }
      });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _initializeGame() {
    _shuffledWords = List.from(widget.words)..shuffle();
    _shuffledTranslations = widget.words.map((w) => w.russian).toList()
      ..shuffle();
    _matchedPairs = {};
    _selectedWord = null;
    _selectedTranslation = null;
  }

  void _handleWordTap(String word) {
    if (_matchedPairs.containsKey(word)) return;

    setState(() {
      _selectedWord = word;
      if (_selectedTranslation != null) {
        _checkMatch(word, _selectedTranslation!);
      }
    });
  }

  void _handleTranslationTap(String translation) {
    if (_matchedPairs.containsValue(translation)) return;

    setState(() {
      _selectedTranslation = translation;
      if (_selectedWord != null) {
        _checkMatch(_selectedWord!, translation);
      }
    });
  }

  void _checkMatch(String word, String translation) {
    final matchedWord = _shuffledWords.firstWhere((w) => w.english == word);

    if (matchedWord.russian == translation) {
      setState(() {
        _matchedPairs[word] = translation;
        _selectedWord = null;
        _selectedTranslation = null;
        if (!_learnedWords.contains(matchedWord)) {
          _learnedWords.add(matchedWord);
        }
      });

      if (_matchedPairs.length == widget.words.length) {
        widget.onComplete(_learnedWords);
      }
    } else {
      _animationController.forward();
      setState(() {
        _isWrongMatch = true;
        Future.delayed(Duration(milliseconds: 600), () {
          if (mounted) {
            setState(() {
              _selectedWord = null;
              _selectedTranslation = null;
              _isWrongMatch = false;
            });
          }
        });
      });
    }
  }

  Color _getWordColor(ThemeProvider themeProvider, String word) {
    if (_isWrongMatch && _selectedWord == word) {
      return _colorAnimation.value ?? Colors.transparent;
    }
    if (_matchedPairs.containsKey(word)) {
      return Colors.green;
    }
    if (_selectedWord == word) {
      return Colors.blue;
    }
    return themeProvider.themeBackgroundColor;
  }

  Color _getTranslationColor(ThemeProvider themeProvider, String translation) {
    if (_isWrongMatch && _selectedTranslation == translation) {
      return _colorAnimation.value ?? Colors.transparent;
    }
    if (_matchedPairs.containsValue(translation)) {
      return Colors.green;
    }
    if (_selectedTranslation == translation) {
      return Colors.blue;
    }
    return themeProvider.themeBackgroundColor;
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final maxWidth = min(screenWidth - 32, 600.0);
    
    return Scaffold(
      backgroundColor: themeProvider.scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: Container(
            constraints: BoxConstraints(maxWidth: maxWidth),
            padding: EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Колонка английских слов
                Expanded(
                  child: Column(
                    children: List.generate(
                      _shuffledWords.length,
                      (index) {
                        final word = _shuffledWords[index];
                        return Expanded(
                          child: AnimatedBuilder(
                            animation: _colorAnimation,
                            builder: (context, child) => Card(
                              margin: EdgeInsets.symmetric(
                                  vertical: 4, horizontal: 4),
                              color: _getWordColor(themeProvider, word.english),
                              child: InkWell(
                                onTap: () => _handleWordTap(word.english),
                                child: Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(8),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          word.english,
                                          style: TextStyle(
                                            color: themeProvider.themeColor,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                          textAlign: TextAlign.center,
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          word.transcription,
                                          style: TextStyle(
                                            color: themeProvider.themeColor,
                                            fontSize: 14,
                                          ),
                                          textAlign: TextAlign.center,
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                SizedBox(width: 16),
                // Колонка переводов
                Expanded(
                  child: Column(
                    children: List.generate(
                      _shuffledTranslations.length,
                      (index) {
                        final translation = _shuffledTranslations[index];
                        return Expanded(
                          child: AnimatedBuilder(
                            animation: _colorAnimation,
                            builder: (context, child) => Card(
                              margin: EdgeInsets.symmetric(
                                  vertical: 4, horizontal: 4),
                              color: _getTranslationColor(
                                  themeProvider, translation),
                              child: InkWell(
                                onTap: () => _handleTranslationTap(translation),
                                child: Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(8),
                                    child: Text(
                                      translation,
                                      style: TextStyle(
                                        color: themeProvider.themeColor,
                                        fontSize: 16,
                                      ),
                                      textAlign: TextAlign.center,
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 2,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
