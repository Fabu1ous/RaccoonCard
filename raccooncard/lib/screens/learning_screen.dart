import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/category.dart';
import '../models/word.dart';
import '../theme/theme_provider.dart';
import '../services/file_service.dart';
import 'stage2_screen.dart';
import 'stage3_screen.dart';
import 'stage4_screen.dart';
import 'stage5_screen.dart';
import 'stage6_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class LearningScreen extends StatefulWidget {
  final List<Word> words;
  final Category category;
  final Function(Category) onCategoryUpdated;
  final int initialStage;
  final int initialIndex;

  const LearningScreen({
    Key? key,
    required this.words,
    required this.category,
    required this.onCategoryUpdated,
    this.initialStage = 1,
    this.initialIndex = 0,
  }) : super(key: key);

  @override
  _LearningScreenState createState() => _LearningScreenState();
}

class _LearningScreenState extends State<LearningScreen> {
  int _currentStage = 1;
  int _currentIndex = 0;
  Map<String, bool> _completedPairs = {};
  Map<String, bool> _completedChoices = {};
  late PageController _pageController;
  static const String _learningStateKey = 'learning_state_';

  @override
  void initState() {
    super.initState();
    _currentStage = widget.initialStage;
    _currentIndex = widget.initialIndex;
    
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  // Сохранить текущее состояние обучения
  Future<void> _saveLearningState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stateKey = _learningStateKey + widget.category.name;
      
      // Сохраняем данные о текущем состоянии
      final wordsData = widget.words.map((word) => word.toJson()).toList();
      
      final state = {
        'stage': _currentStage,
        'index': _currentIndex,
        'words': wordsData,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      
      await prefs.setString(stateKey, jsonEncode(state));
      print('DEBUG: Сохранено состояние обучения: этап $_currentStage, индекс $_currentIndex');
    } catch (e) {
      print('Ошибка при сохранении состояния обучения: $e');
    }
  }

  // Переход к следующему этапу
  void _nextStage() {
    setState(() {
      _currentStage++;
      _currentIndex = 0;
      _completedPairs.clear();
      _completedChoices.clear();
    });
    
    _saveLearningState();
  }

  // Начать новый набор
  void _startNewSet() async {
    // Сначала сохраняем текущий прогресс
    await _markWordsAsLearned();
    
    // Проверяем наличие новых слов для изучения
    final words = widget.category.words
        .where((word) => !word.isLearned && !word.isBlocked)
        .toList();
    
    if (words.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Нет доступных слов для изучения!')),
        );
        Navigator.pop(context);
      }
      return;
    }
    
    setState(() {
      _currentStage = 1;
      _currentIndex = 0;
      _completedPairs.clear();
      _completedChoices.clear();
    });
    
    _saveLearningState();
  }

  @override
  void dispose() {
    // Сохраняем состояние при закрытии экрана (если не закончили обучение)
    if (_currentStage <= 6) {
      _saveLearningState();
    } else {
      // Если обучение завершено, удаляем сохраненное состояние
      _clearLearningState();
    }
    
    _pageController.dispose();
    super.dispose();
  }

  // Очистить сохраненное состояние обучения
  Future<void> _clearLearningState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stateKey = _learningStateKey + widget.category.name;
      await prefs.remove(stateKey);
      print('DEBUG: Состояние обучения очищено');
    } catch (e) {
      print('Ошибка при очистке состояния обучения: $e');
    }
  }

  // Пометить слова как изученные
  Future<void> _markWordsAsLearned() async {
    await _clearLearningState();
    
    // Проходим по всем словам в текущей сессии
    for (final word in widget.words) {
      final wordIndex = widget.category.words.indexOf(word);
      if (wordIndex != -1) {
        // Используем copyWith для создания новой версии слова с обновленными параметрами
        widget.category.words[wordIndex] = widget.category.words[wordIndex].copyWith(
          isLearned: true,
          // Увеличиваем счетчик повторений только при завершении обучения
          repetitions: widget.category.words[wordIndex].repetitions + 1,
        );
        // Обновляем слово в текущем списке для изучения
        final sessionWordIndex = widget.words.indexOf(word);
        if (sessionWordIndex != -1) {
          widget.words[sessionWordIndex] = widget.category.words[wordIndex];
        }
      }
    }

    // Обновляем UI
    widget.onCategoryUpdated(widget.category);
    
    // Сохраняем изменения в SharedPreferences
    await FileService.saveCategory(widget.category);
    
    // Переходим на главный экран
    if (mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    if (_currentStage > 6) {
      return Scaffold(
        backgroundColor: themeProvider.scaffoldBackgroundColor,
        body: Center(
          child: Container(
            constraints: BoxConstraints(maxWidth: 600),
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Поздравляем!',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: themeProvider.themeColor,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'Вы успешно завершили изучение слов!',
                  style: TextStyle(
                    fontSize: 20,
                    color: themeProvider.themeColor,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          _markWordsAsLearned();
                          Navigator.pop(context);
                        },
                        child: Text('В главное меню',
                            style:
                                TextStyle(fontSize: 18, color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: themeProvider.isDarkTheme
                              ? Colors.grey[700]
                              : Colors.brown[400],
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _startNewSet,
                        child: Text('Новый набор',
                            style:
                                TextStyle(fontSize: 18, color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: themeProvider.isDarkTheme
                              ? Colors.grey[700]
                              : Colors.brown[400],
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: themeProvider.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Изучение слов',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor:
            themeProvider.isDarkTheme ? Colors.grey[800] : Colors.brown[400],
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _buildStageContent(),
            ),
          ],
        ),
      ),
    );
  }

  // Построение контента для текущего этапа
  Widget _buildStageContent() {
    switch (_currentStage) {
      case 1:
        return _buildStage1();
      case 2:
        return Stage2Screen(
          words: widget.words,
          onComplete: (learnedWords) {
            _nextStage();
          },
        );
      case 3:
        return Stage3Screen(
          words: widget.words,
          onComplete: (learnedWords) {
            _nextStage();
          },
        );
      case 4:
        return Stage4Screen(
          words: widget.words,
          onComplete: (learnedWords) {
            _nextStage();
          },
        );
      case 5:
        return Stage5Screen(
          words: widget.words,
          onNextStage: () {
            _nextStage();
          },
        );
      case 6:
        return Stage6Screen(
          words: widget.words,
          onNextStage: () {
            _nextStage();
          },
        );
      default:
        return Center(child: Text('Неизвестный этап'));
    }
  }

  // Первый этап: просмотр карточек
  Widget _buildStage1() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final cardWidth =
        screenWidth > 600 ? 600 : screenWidth * 0.9;
    final cardHeight = screenHeight * 0.5;

    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: widget.words.length,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
              _saveLearningState();
            },
            itemBuilder: (context, index) {
              final word = widget.words[index];
              return Center(
                child: Container(
                  width: cardWidth.toDouble(),
                  height: cardHeight.toDouble(),
                  child: Card(
                    elevation: 8,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    color: themeProvider.themeBackgroundColor,
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            word.english,
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: themeProvider.themeColor,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            word.transcription,
                            style: TextStyle(
                              fontSize: 20,
                              color: themeProvider.themeColor.withAlpha(179),
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 20),
                          Text(
                            word.russian,
                            style: TextStyle(
                              fontSize: 24,
                              color: themeProvider.themeColor.withAlpha(204),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: Icon(
                  Icons.arrow_back_ios,
                  color: _currentIndex > 0
                      ? themeProvider.themeColor
                      : themeProvider.themeColor.withAlpha(77),
                  size: 32,
                ),
                onPressed: _currentIndex > 0
                    ? () {
                        _pageController.previousPage(
                          duration: Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      }
                    : null,
              ),
              SizedBox(width: 40),
              IconButton(
                icon: Icon(
                  Icons.arrow_forward_ios,
                  color: _currentIndex < widget.words.length - 1
                      ? themeProvider.themeColor
                      : themeProvider.themeColor.withAlpha(77),
                  size: 32,
                ),
                onPressed: _currentIndex < widget.words.length - 1
                    ? () {
                        _pageController.nextPage(
                          duration: Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      }
                    : null,
              ),
            ],
          ),
        ),
        if (_currentIndex == widget.words.length - 1)
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: ElevatedButton(
              onPressed: _nextStage,
              child: Text('Далее',
                  style: TextStyle(fontSize: 18, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: themeProvider.isDarkTheme
                    ? Colors.grey[700]
                    : Colors.brown[400],
                padding:
                    const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
      ],
    );
  }
}
