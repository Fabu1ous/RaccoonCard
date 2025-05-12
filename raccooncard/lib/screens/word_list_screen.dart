import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/word.dart';
import '../models/category.dart';
import '../screens/learning_screen.dart';
import '../screens/edit_word_screen.dart';
import '../theme/theme_provider.dart';
import '../services/file_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../screens/add_word_screen.dart';

class WordListScreen extends StatefulWidget {
  final String categoryName;
  final String level;
  final List<Category> categories;
  final Function(Category)
      onCategoryUpdated;

  const WordListScreen({
    Key? key,
    required this.categoryName,
    required this.level,
    required this.categories,
    required this.onCategoryUpdated,
  }) : super(key: key);

  @override
  _WordListScreenState createState() => _WordListScreenState();
}

class _WordListScreenState extends State<WordListScreen> {
  bool _isSelectionMode = false;
  final Set<int> _selectedWordIndexes = {};
  late Category _category;
  late List<Word> _filteredWords;
  final TextEditingController _searchController = TextEditingController();

  // Функция для показа SnackBar с предварительным скрытием старых
  void _showSnackBar(String message, {Duration? duration}) {
    // Скрыть все текущие SnackBar
    ScaffoldMessenger.of(context).clearSnackBars();
    // Показать новый SnackBar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: duration ?? Duration(seconds: 2),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _category =
        widget.categories.firstWhere((c) => c.name == widget.categoryName);
    _updateFilteredWords();
  }

  void _updateFilteredWords() {
    _filteredWords = _category.words.where((word) {
      if (widget.level == "Все") return true;
      return word.level == widget.level;
    }).toList();

    if (_searchController.text.isNotEmpty) {
      final query = _searchController.text.toLowerCase();
      _filteredWords = _filteredWords.where((word) {
        return word.english.toLowerCase().contains(query) ||
            word.russian.toLowerCase().contains(query);
      }).toList();
    }

    _filteredWords.sort((a, b) => a.english.compareTo(b.english));
  }

  // Функция для получения слов для изучения/повторения
  Future<List<Word>> _getWordsForLearning(bool isLearned) async {
    List<Word> filteredWords = _category.words
        .where((word) =>
            word.isLearned == isLearned &&
            !word.isBlocked &&
            (widget.level == 'Все' || word.level == widget.level))
        .toList();

    filteredWords.shuffle();

    return filteredWords.take(5).toList();
  }

  // Очистка сохраненного состояния обучения
  Future<void> _clearLearningState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stateKey = 'learning_state_' + _category.name;
      await prefs.remove(stateKey);
      print('DEBUG: Состояние обучения очищено');
    } catch (e) {
      print('Ошибка при очистке состояния обучения: $e');
    }
  }

  // Сохранение слов, используемых в текущей сессии обучения
  Future<void> _saveWordsInLearningState(List<Word> words, int stage, int index) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stateKey = 'learning_state_' + _category.name;
      
      // Сохраняем данные слов, чтобы восстановить их точно в таком же порядке
      final wordsData = words.map((word) => word.toJson()).toList();
      
      final state = {
        'stage': stage,
        'index': index,
        'words': wordsData,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      
      await prefs.setString(stateKey, jsonEncode(state));
      print('DEBUG: Слова и состояние сохранены для продолжения обучения');
    } catch (e) {
      print('Ошибка при сохранении слов для обучения: $e');
    }
  }

  // Восстановление сохраненных слов для обучения
  Future<Map<String, dynamic>?> _getSavedLearningState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stateKey = 'learning_state_' + _category.name;
      final savedState = prefs.getString(stateKey);
      
      if (savedState != null) {
        return jsonDecode(savedState);
      }
      return null;
    } catch (e) {
      print('Ошибка при получении сохраненного состояния обучения: $e');
      return null;
    }
  }

  // Проверка наличия незаконченного обучения
  Future<bool> _hasUnfinishedLearning() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stateKey = 'learning_state_' + _category.name;
      return prefs.containsKey(stateKey);
    } catch (e) {
      print('Ошибка при проверке состояния обучения: $e');
      return false;
    }
  }

  // Показать диалог с предложением продолжить обучение
  Future<void> _showContinueLearningDialog() async {
    final hasUnfinished = await _hasUnfinishedLearning();
    if (!hasUnfinished) {
      // Если нет незаконченного обучения, сразу начинаем новое
      _startNewLearning(false);
      return;
    }

    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: themeProvider.themeBackgroundColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'Продолжить обучение?',
          style: TextStyle(
            color: themeProvider.themeColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'У вас есть незаконченное обучение в этой категории. Хотите продолжить с того места, где остановились?',
          style: TextStyle(
            color: themeProvider.themeColor,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _startNewLearning(false);
            },
            child: Text(
              'Начать заново',
              style: TextStyle(
                color: themeProvider.isDarkTheme ? Colors.grey[300] : Colors.grey[700],
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _continueLearning();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: themeProvider.isDarkTheme 
                  ? Colors.grey[700] 
                  : Colors.brown[400],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Продолжить',
              style: TextStyle(
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Начать новое обучение
  void _startNewLearning(bool isLearned) async {
    // Очищаем предыдущее сохраненное состояние
    await _clearLearningState();
    
    final words = await _getWordsForLearning(isLearned);
    if (words.isEmpty) {
      _showSnackBar(isLearned ? 'Нет доступных слов для повторения!' : 'Нет доступных слов для изучения!');
      return;
    }
    
    // Сохраняем начальное состояние обучения
    await _saveWordsInLearningState(words, 1, 0);
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LearningScreen(
          words: words,
          category: _category,
          onCategoryUpdated: widget.onCategoryUpdated,
        ),
      ),
    ).then((_) {
      // Проверяем, завершилось ли обучение
      _checkIfLearningCompleted();
    });
  }
  
  // Продолжить обучение
  void _continueLearning() async {
    try {
      final savedState = await _getSavedLearningState();
      
      if (savedState != null) {
        // Восстанавливаем сохраненные слова
        List<Word> savedWords = [];
        
        if (savedState['words'] != null) {
          final List<dynamic> wordsData = savedState['words'];
          
          for (var wordData in wordsData) {
            final Word word = Word(
              english: wordData['english'],
              russian: wordData['russian'],
              level: wordData['level'],
              transcription: wordData['transcription'] ?? '',
              isLearned: wordData['isLearned'] ?? false,
              isBlocked: wordData['isBlocked'] ?? false,
              repetitions: wordData['repetitions'] ?? 0,
            );
            
            // Обновляем статус слова из актуальной категории
            final int categoryWordIndex = _category.words.indexWhere(
              (w) => w.english == word.english && w.russian == word.russian
            );
            
            if (categoryWordIndex != -1) {
              // Используем актуальные данные слова из категории
              savedWords.add(_category.words[categoryWordIndex]);
            } else {
              // Если слово не найдено в категории, используем сохраненное
              savedWords.add(word);
            }
          }
        }
        
        // Если не удалось восстановить слова, получаем новые
        if (savedWords.isEmpty) {
          savedWords = await _getWordsForLearning(false);
          if (savedWords.isEmpty) {
            _showSnackBar('Нет доступных слов для изучения!');
            return;
          }
        }
        
        // Получаем сохраненный этап и индекс
        final int stage = savedState['stage'] ?? 1;
        final int index = savedState['index'] ?? 0;
        
        // Запускаем LearningScreen с восстановленными параметрами
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => LearningScreen(
              words: savedWords,
              category: _category,
              onCategoryUpdated: widget.onCategoryUpdated,
              initialStage: stage,
              initialIndex: index,
            ),
          ),
        ).then((_) {
          // Проверяем, завершилось ли обучение
          _checkIfLearningCompleted();
        });
      } else {
        // Если не удалось восстановить состояние, начинаем новое обучение
        _startNewLearning(false);
      }
    } catch (e) {
      print('Ошибка при продолжении обучения: $e');
      _showSnackBar('Произошла ошибка при восстановлении обучения');
      
      // В случае ошибки пробуем начать новое обучение
      _startNewLearning(false);
    }
  }
  
  // Проверяем, завершилось ли обучение успешно
  Future<void> _checkIfLearningCompleted() async {
    try {
      final savedState = await _getSavedLearningState();
      if (savedState == null) {
        // Если нет сохраненного состояния, значит обучение завершено
        print('DEBUG: Обучение завершено или данные очищены');
      } else {
        // Проверяем, если этап > 6, то обучение завершено
        final int stage = savedState['stage'] ?? 1;
        if (stage > 6) {
          await _clearLearningState();
          print('DEBUG: Обучение завершено, данные очищены');
        }
      }
    } catch (e) {
      print('Ошибка при проверке завершения обучения: $e');
    }
  }

  // Переключение режима выбора
  void _toggleSelection(int wordIndex) {
    setState(() {
      if (_selectedWordIndexes.contains(wordIndex)) {
        _selectedWordIndexes.remove(wordIndex);
      } else {
        _selectedWordIndexes.add(wordIndex);
      }
      _isSelectionMode = _selectedWordIndexes.isNotEmpty;
    });
  }

  // Удаление выбранных слов
  Future<void> _deleteSelectedWords(Category category) async {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: themeProvider.themeBackgroundColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'Подтвердите удаление',
          style: TextStyle(
            color: themeProvider.themeColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Вы уверены, что хотите удалить выбранные слова?',
          style: TextStyle(
            color: themeProvider.themeColor,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: Text(
              'Отмена',
              style: TextStyle(
                color: themeProvider.isDarkTheme ? Colors.grey[300] : Colors.grey[700],
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              // Закрываем диалог перед выполнением операций
              Navigator.pop(context);
              
              try {
                // Получаем индексы выделенных слов
                List<Word> wordsToRemove = [];
                
                // Соберем список слов для удаления
                for (int index in _selectedWordIndexes) {
                  if (index < _filteredWords.length) {
                    wordsToRemove.add(_filteredWords[index]);
                  }
                }
                
                // Удаляем каждое слово из основного списка
                for (Word word in wordsToRemove) {
                  category.words.remove(word);
                }
                
                // Очищаем выбранные индексы и выходим из режима выбора
                setState(() {
                  _selectedWordIndexes.clear();
                  _isSelectionMode = false;
                  // Обновляем отфильтрованный список
                  _updateFilteredWords();
                });
                
                // Обновляем категорию в UI
                widget.onCategoryUpdated(category);
                
                // Сохраняем изменения в SharedPreferences
                await FileService.saveCategory(category);
                
                _showSnackBar('Выбранные слова успешно удалены');
              } catch (e) {
                print('Ошибка при удалении слов: $e');
                if (mounted) {
                  _showSnackBar('Произошла ошибка при удалении слов');
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[400],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Удалить',
              style: TextStyle(
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Изменение статуса "изучено"
  void _toggleWordLearned(Word word) async {
    final wordIndex = _category.words.indexOf(word);
    if (wordIndex == -1) return;

    setState(() {
      // Создаем новое слово с обновленными параметрами
      _category.words[wordIndex] = word.copyWith(
        isLearned: !word.isLearned,
        // Не увеличиваем счетчик повторений при простом переключении статуса
      );
      // Обновляем отфильтрованный список
      _updateFilteredWords();
    });
    
    try {
      // Обновляем категорию в UI
      widget.onCategoryUpdated(_category);
      
      // Сохраняем изменения в SharedPreferences
      await FileService.saveCategory(_category);
    } catch (e) {
      print('Ошибка при сохранении статуса изучения слова: $e');
      // Показываем уведомление пользователю только если не получилось сохранить
      if (mounted) {
        _showSnackBar('Статус изучения изменен, но не сохранен (ошибка path_provider)');
      }
    }
  }

  // Сброс счетчика повторений слова
  void _resetWordRepetitions(Word word) async {
    final wordIndex = _category.words.indexOf(word);
    if (wordIndex == -1) return;

    setState(() {
      // Сбрасываем счетчик повторений
      _category.words[wordIndex] = word.copyWith(
        repetitions: 0,
      );
      // Обновляем отфильтрованный список
      _updateFilteredWords();
    });
    
    try {
      // Обновляем категорию в UI
      widget.onCategoryUpdated(_category);
      
      // Сохраняем изменения в SharedPreferences
      await FileService.saveCategory(_category);
      
      // Уведомляем пользователя
      _showSnackBar('Счетчик повторений сброшен', duration: Duration(seconds: 1));
    } catch (e) {
      print('Ошибка при сбросе счетчика повторений: $e');
      if (mounted) {
        _showSnackBar('Ошибка при сбросе счетчика повторений');
      }
    }
  }

  // Изменение статуса "заблокировано"
  void _toggleWordBlockedStatus(Word word) async {
    final wordIndex = _category.words.indexOf(word);
    if (wordIndex == -1) return;

    setState(() {
      // Используем copyWith вместо прямого изменения свойства
      _category.words[wordIndex] = word.copyWith(
        isBlocked: !word.isBlocked,
      );
      // Обновляем отфильтрованный список слов сразу
      _updateFilteredWords();
    });

    try {
      // Обновляем категорию в UI
      widget.onCategoryUpdated(_category);
      
      // Сохраняем изменения в SharedPreferences
      await FileService.saveCategory(_category);
    } catch (e) {
      print('Ошибка при сохранении статуса блокировки слова: $e');
      // Показываем уведомление пользователю только если не получилось сохранить
      if (mounted) {
        _showSnackBar('Статус блокировки изменен, но не сохранен (ошибка path_provider)');
      }
    }
  }

  // Отмена выделения
  void _cancelSelection() {
    setState(() {
      _selectedWordIndexes.clear();
      _isSelectionMode = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final maxWidth = screenWidth > 600
        ? 600.0
        : double.infinity;

    return Scaffold(
      backgroundColor: themeProvider.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          _isSelectionMode 
              ? "Выбрано: ${_selectedWordIndexes.length}" 
              : widget.categoryName,
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor:
            themeProvider.isDarkTheme ? Colors.grey[800] : Colors.brown[400],
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
        actions: [
          if (_isSelectionMode)
            IconButton(
              icon: Icon(Icons.cancel, color: Colors.white),
              onPressed: _cancelSelection,
            ),
          if (_isSelectionMode)
            IconButton(
              icon: Icon(Icons.delete, color: Colors.white),
              onPressed: () async {
                await _deleteSelectedWords(_category);
              },
            ),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: TextField(
                  controller: _searchController,
                  cursorColor: themeProvider.themeColor,
                  decoration: InputDecoration(
                    labelText: 'Поиск',
                    labelStyle: TextStyle(color: themeProvider.themeColor),
                    suffixIcon:
                        Icon(Icons.search, color: themeProvider.themeColor),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: themeProvider.themeColor),
                    ),
                  ),
                  style: TextStyle(color: themeProvider.themeColor),
                  onChanged: (value) {
                    setState(() {
                      _updateFilteredWords();
                    });
                  },
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: Container(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: _filteredWords.isEmpty
                      ? Center(
                          child: Text(
                            _searchController.text.isEmpty
                                ? 'Нет слов в данной категории'
                                : 'Ничего не найдено',
                            style: TextStyle(
                              fontSize: 18,
                              color: themeProvider.themeColor,
                            ),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _filteredWords.length,
                          itemBuilder: (context, index) {
                            final word = _filteredWords[index];
                            final isSelected =
                                _selectedWordIndexes.contains(index);

                            return GestureDetector(
                              onLongPress: () {
                                _toggleSelection(index);
                              },
                              onTap: () {
                                if (_isSelectionMode) {
                                  _toggleSelection(index);
                                }
                              },
                              child: Card(
                                margin: EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                color: themeProvider.themeBackgroundColor,
                                child: Column(
                                  children: [
                                    ListTile(
                                      title: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            word.english,
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: themeProvider.themeColor,
                                            ),
                                          ),
                                          Text(
                                            word.transcription,
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: themeProvider.themeColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                      subtitle: Text(
                                        word.russian,
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: themeProvider.themeColor,
                                        ),
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            word.level,
                                            style: TextStyle(
                                              color: themeProvider.themeColor,
                                            ),
                                          ),
                                          SizedBox(width: 8),
                                          IconButton(
                                            icon: Icon(
                                              word.isLearned
                                                  ? Icons.check_circle
                                                  : Icons.check_circle_outline,
                                              color: word.isLearned
                                                  ? (themeProvider.isDarkTheme
                                                      ? Colors.greenAccent
                                                      : Colors.green)
                                                  : themeProvider.themeColor,
                                            ),
                                            onPressed: () => _toggleWordLearned(word),
                                          ),
                                          if (!_isSelectionMode)
                                            IconButton(
                                              icon: Icon(
                                                word.isBlocked
                                                    ? Icons.block
                                                    : Icons.lock_open,
                                                color: word.isBlocked
                                                    ? Colors.red[600]
                                                    : Colors.grey[400],
                                              ),
                                              onPressed: () {
                                                _toggleWordBlockedStatus(word);
                                              },
                                            ),
                                          if (!_isSelectionMode)
                                            IconButton(
                                              icon: Icon(Icons.edit,
                                                  color: themeProvider.themeColor),
                                              onPressed: () async {
                                                final result = await Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) =>
                                                        EditWordScreen(
                                                      wordIndex: index,
                                                      initialWord: word,
                                                      category: _category,
                                                      onCategoryUpdated:
                                                          widget.onCategoryUpdated,
                                                    ),
                                                  ),
                                                );
                                                
                                                // Если были изменения, обновляем UI
                                                if (result == true) {
                                                  setState(() {
                                                    _updateFilteredWords();
                                                  });
                                                }
                                              },
                                            ),
                                          if (_isSelectionMode)
                                            Icon(
                                              isSelected
                                                  ? Icons.check_box
                                                  : Icons.check_box_outline_blank,
                                              color: themeProvider.themeColor,
                                            ),
                                        ],
                                      ),
                                    ),
                                    // Отображение количества повторений и кнопка сброса
                                    if (word.repetitions > 0)
                                      Padding(
                                        padding: EdgeInsets.only(bottom: 8, right: 16),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.end,
                                          children: [
                                            Icon(
                                              Icons.repeat,
                                              size: 14,
                                              color: themeProvider.themeColor,
                                            ),
                                            SizedBox(width: 4),
                                            Text(
                                              '${word.repetitions}',
                                              style: TextStyle(
                                                color: themeProvider.themeColor,
                                                fontSize: 14,
                                              ),
                                            ),
                                            SizedBox(width: 8),
                                            GestureDetector(
                                              onTap: () => _resetWordRepetitions(word),
                                              child: Icon(
                                                Icons.restart_alt,
                                                size: 16,
                                                color: themeProvider.isDarkTheme
                                                    ? Colors.redAccent
                                                    : Colors.red[400],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: !_isSelectionMode ? Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom > 0 
            ? MediaQuery.of(context).viewPadding.bottom 
            : 0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            // Кнопка добавления слова в текущую категорию
            FloatingActionButton(
              heroTag: 'wordlist_add_word_${widget.categoryName}',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AddWordScreen(
                      categories: widget.categories,
                      onCategoryUpdated: widget.onCategoryUpdated,
                      preselectedCategory: widget.categoryName,
                      preselectedLevel: widget.level == "Все" ? "A2" : widget.level,
                    ),
                  ),
                );
              },
              tooltip: 'Добавить слово в эту категорию',
              backgroundColor: themeProvider.isDarkTheme
                  ? Colors.grey[700]
                  : Colors.brown[400],
              child: Icon(Icons.add, color: Colors.white),
            ),
            const SizedBox(height: 10),
            FloatingActionButton(
              heroTag: 'wordlist_learn_${widget.categoryName}_${widget.level}',
              onPressed: () async {
                await _showContinueLearningDialog();
              },
              child: Icon(Icons.school, color: Colors.white),
              tooltip: 'Изучить новые слова',
              backgroundColor: themeProvider.isDarkTheme
                  ? Colors.grey[700]
                  : Colors.brown[400],
            ),
            const SizedBox(height: 10),
            FloatingActionButton(
              heroTag: 'wordlist_repeat_${widget.categoryName}_${widget.level}',
              onPressed: () async {
                final words = await _getWordsForLearning(true);
                if (words.isEmpty) {
                  _showSnackBar('Нет доступных слов для повторения!');
                  return;
                }
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => LearningScreen(
                      words: words,
                      category: _category,
                      onCategoryUpdated: widget.onCategoryUpdated,
                    ),
                  ),
                );
              },
              child: Icon(Icons.repeat, color: Colors.white),
              tooltip: 'Повторить изученные слова',
              backgroundColor: themeProvider.isDarkTheme
                  ? Colors.grey[700]
                  : Colors.brown[400],
            ),
          ],
        ),
      ) : null,
    );
  }
}
