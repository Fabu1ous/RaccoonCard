import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/verb.dart';
import '../theme/theme_provider.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'edit_verb_screen.dart';
import 'verb_learning_screen.dart';
import 'add_verb_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class VerbsScreen extends StatefulWidget {
  final List<Verb> verbs;
  final Function(List<Verb>) onVerbsUpdated;

  const VerbsScreen({
    Key? key,
    required this.verbs,
    required this.onVerbsUpdated,
  }) : super(key: key);

  @override
  _VerbsScreenState createState() => _VerbsScreenState();
}

class _VerbsScreenState extends State<VerbsScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Verb> _filteredVerbs = [];
  
  bool _isSelectionMode = false;
  final Set<String> _selectedVerbs = {};
  
  final Set<String> _lastUsedVerbBases = {};
  
  // Ключ для хранения состояния обучения глаголов
  static const String _verbLearningStateKey = 'verb_learning_state';
  
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
    _filteredVerbs = List.from(widget.verbs);
    
    _removeDuplicateVerbs();
    
    _sortVerbs();
  }
  
  void _removeDuplicateVerbs() {
    final Set<String> uniqueBases = {};
    final List<Verb> uniqueVerbs = [];
    
    for (var verb in widget.verbs) {
      if (!uniqueBases.contains(verb.base)) {
        uniqueBases.add(verb.base);
        uniqueVerbs.add(verb);
      } else {
        print("DEBUG: Удален дубликат глагола: ${verb.base}");
      }
    }
    
    if (uniqueVerbs.length < widget.verbs.length) {
      print("DEBUG: Удалено ${widget.verbs.length - uniqueVerbs.length} дубликатов глаголов");
      widget.verbs.clear();
      widget.verbs.addAll(uniqueVerbs);
      widget.onVerbsUpdated(widget.verbs);
    }
    
    _filteredVerbs = List.from(widget.verbs);
  }
  
  void _sortVerbs() {
    widget.verbs.sort((a, b) => a.base.toLowerCase().compareTo(b.base.toLowerCase()));
    _filteredVerbs = List.from(widget.verbs);
  }

  void _filterVerbs(String query) {
    setState(() {
      _filteredVerbs = widget.verbs.where((verb) {
        return verb.base.toLowerCase().contains(query.toLowerCase()) ||
            verb.translation.toLowerCase().contains(query.toLowerCase());
      }).toList();
      
      _filteredVerbs.sort((a, b) => a.base.toLowerCase().compareTo(b.base.toLowerCase()));
    });
  }

  void _toggleVerbLearned(int index) {
    final verb = _filteredVerbs[index];
    final mainIndex = widget.verbs.indexWhere((v) => v.base == verb.base);
    
    if (mainIndex != -1) {
      setState(() {
        widget.verbs[mainIndex].isLearned = !widget.verbs[mainIndex].isLearned;
        _filteredVerbs[index].isLearned = widget.verbs[mainIndex].isLearned;
        
        _filteredVerbs = List.from(_filteredVerbs);
        _sortVerbs();
        widget.onVerbsUpdated(widget.verbs);
      });
    }
  }

  void _toggleVerbBlocked(int index) {
    final verb = _filteredVerbs[index];
    final mainIndex = widget.verbs.indexWhere((v) => v.base == verb.base);
    
    if (mainIndex != -1) {
      setState(() {
        widget.verbs[mainIndex].isBlocked = !widget.verbs[mainIndex].isBlocked;
        _filteredVerbs[index].isBlocked = widget.verbs[mainIndex].isBlocked;
        
        _filteredVerbs = List.from(_filteredVerbs);
        _sortVerbs();
        widget.onVerbsUpdated(widget.verbs);
      });
    }
  }
  
  void _toggleVerbSelection(String base) {
    setState(() {
      if (_selectedVerbs.contains(base)) {
        _selectedVerbs.remove(base);
      } else {
        _selectedVerbs.add(base);
      }
      _isSelectionMode = _selectedVerbs.isNotEmpty;
    });
  }
  
  void _cancelSelection() {
    setState(() {
      _selectedVerbs.clear();
      _isSelectionMode = false;
    });
  }
  
  void _deleteSelectedVerbs() {
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
          'Вы уверены, что хотите удалить выбранные глаголы?\nЭто действие нельзя отменить!',
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
            onPressed: () {
              widget.verbs.removeWhere((verb) => _selectedVerbs.contains(verb.base));
              
              setState(() {
                _sortVerbs();
                _selectedVerbs.clear();
                _isSelectionMode = false;
              });
              
              widget.onVerbsUpdated(widget.verbs);
              
              Navigator.pop(context);
              
              _showSnackBar('Выбранные глаголы успешно удалены');
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

  // Проверка наличия незаконченного обучения
  Future<bool> _hasUnfinishedLearning() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.containsKey(_verbLearningStateKey);
    } catch (e) {
      print('Ошибка при проверке состояния обучения глаголов: $e');
      return false;
    }
  }
  
  // Очистка сохраненного состояния
  Future<void> _clearSavedLearningState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_verbLearningStateKey);
      print("DEBUG: Verb learning state cleared");
    } catch (e) {
      print("Error clearing verb learning state: $e");
    }
  }
  
  // Загрузка сохраненного состояния
  Future<Map<String, dynamic>?> _loadSavedLearningState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedState = prefs.getString(_verbLearningStateKey);
      
      if (savedState != null) {
        return jsonDecode(savedState);
      }
      return null;
    } catch (e) {
      print('Ошибка при загрузке состояния обучения глаголов: $e');
      return null;
    }
  }
  
  
  // Общий метод для запуска экрана обучения
  void _startLearningWithVerbs(List<Verb> verbs) async {
    if (verbs.isEmpty) {
      _showSnackBar('Нет доступных глаголов для обучения');
      return;
    }
    
    // Проверяем наличие незаконченного обучения
    final hasUnfinished = await _hasUnfinishedLearning();
    
    if (hasUnfinished) {
      _showContinueLearningDialog(verbs);
    } else {
      _startNewLearning(verbs);
    }
  }
  
  // Показать диалог с предложением продолжить обучение
  void _showContinueLearningDialog(List<Verb> verbs) {
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
          'У вас есть незаконченное обучение глаголов. Хотите продолжить с того места, где остановились?',
          style: TextStyle(
            color: themeProvider.themeColor,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _startNewLearning(verbs);
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
  void _startNewLearning(List<Verb> verbs) async {
    // Очищаем предыдущее сохраненное состояние
    await _clearSavedLearningState();
    
    // Сохраняем текущие глаголы как последние использованные
    _lastUsedVerbBases.clear();
    for (var verb in verbs) {
      _lastUsedVerbBases.add(verb.base);
    }
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VerbLearningScreen(
          verbs: verbs,
          onVerbsUpdated: widget.onVerbsUpdated,
        ),
      ),
    ).then((_) {
      // Обновляем список после возврата с экрана обучения
      setState(() {
        _filteredVerbs = List.from(widget.verbs);
        if (_searchController.text.isNotEmpty) {
          _filterVerbs(_searchController.text);
        }
      });
    });
  }
  
  // Продолжить обучение
  void _continueLearning() async {
    try {
      // Загружаем сохраненное состояние
      final savedState = await _loadSavedLearningState();
      
      if (savedState != null) {
        // Получаем данные о сохраненных глаголах
        List<Verb> savedVerbs = [];
        
        if (savedState['verbs'] != null) {
          final List<dynamic> verbsData = savedState['verbs'];
          
          for (var verbData in verbsData) {
            savedVerbs.add(Verb.fromJson(verbData));
          }
        }
        
        // Если все еще нет глаголов, выбираем новые
        if (savedVerbs.isEmpty) {
          // Сначала пробуем найти изученные глаголы для повторения
          final learnedVerbs = widget.verbs
              .where((verb) => verb.isLearned && !verb.isBlocked)
              .toList();
              
          if (learnedVerbs.isNotEmpty) {
            // Если есть изученные глаголы, используем их
            learnedVerbs.shuffle();
            savedVerbs = learnedVerbs.take(5).toList();
          } else {
            // Если нет изученных, используем любые неблокированные
            final availableVerbs = widget.verbs
                .where((verb) => !verb.isBlocked)
                .toList();
                
            if (availableVerbs.isEmpty) {
              _showSnackBar('Нет доступных глаголов для обучения');
              return;
            }
            
            availableVerbs.shuffle();
            savedVerbs = availableVerbs.take(5).toList();
          }
        }
        
        // Получаем сохраненные индексы
        final stage = savedState['stage'] ?? 1;
        final verbIndex = savedState['verbIndex'] ?? 0;
        final questionIndex = savedState['questionIndex'] ?? 0;
        
        // Запускаем экран обучения с восстановленными параметрами
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VerbLearningScreen(
              verbs: savedVerbs,
              onVerbsUpdated: widget.onVerbsUpdated,
              initialStage: stage,
              initialVerbIndex: verbIndex,
              initialQuestionIndex: questionIndex,
            ),
          ),
        ).then((_) {
          // Обновляем список после возврата с экрана обучения
          setState(() {
            _filteredVerbs = List.from(widget.verbs);
            if (_searchController.text.isNotEmpty) {
              _filterVerbs(_searchController.text);
            }
          });
        });
      } else {
        // Если ошибка при загрузке состояния, начинаем новое обучение
        _showSnackBar('Не удалось восстановить предыдущую сессию');
        List<Verb> verbs = widget.verbs
            .where((verb) => !verb.isBlocked && !verb.isLearned)
            .toList();
        if (verbs.isEmpty) {
          verbs = widget.verbs
              .where((verb) => !verb.isBlocked)
              .toList();
        }
        if (verbs.isNotEmpty) {
          verbs.shuffle();
          _startNewLearning(verbs.take(5).toList());
        } else {
          _showSnackBar('Нет доступных глаголов для обучения');
        }
      }
    } catch (e) {
      print('Ошибка при продолжении обучения глаголов: $e');
      _showSnackBar('Произошла ошибка при восстановлении сессии');
    }
  }

  Future<void> _resetRepetitions() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Сбрасываем все счетчики повторений
    for (var verb in _filteredVerbs) {
      await prefs.remove('verb_repetition_${verb.base}');
      verb.repetitions = 0;
    }
    
    setState(() {
      _filteredVerbs = List.from(_filteredVerbs);
      widget.onVerbsUpdated(_filteredVerbs);
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Счетчики повторений сброшены'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: themeProvider.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          _isSelectionMode 
              ? "Выбрано: ${_selectedVerbs.length}" 
              : "Глаголы",
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
              onPressed: _deleteSelectedVerbs,
            ),
        ],
      ),
      body: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: 800),
                  child: Column(
                    children: [
                      // Строка поиска (показываем всегда)
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        child: TextField(
                          controller: _searchController,
                          cursorColor: themeProvider.themeColor,
                          decoration: InputDecoration(
                            labelText: 'Поиск',
                            labelStyle: TextStyle(color: themeProvider.themeColor),
                            filled: true,
                            fillColor: themeProvider.themeBackgroundColor,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: EdgeInsets.symmetric(
                                vertical: 16, horizontal: 20),
                            suffixIcon: Icon(Icons.search,
                                color: themeProvider.themeColor),
                          ),
                          style: TextStyle(
                              fontSize: 16,
                              color: themeProvider.themeColor),
                          onChanged: _filterVerbs,
                        ),
                      ),

                      // Список глаголов
                      Expanded(
                        child: ListView.builder(
                          itemCount: _filteredVerbs.length,
                          itemBuilder: (context, index) {
                            final verb = _filteredVerbs[index];
                            final isSelected = _selectedVerbs.contains(verb.base);
                            
                            return Align(
                              alignment: Alignment.topCenter,
                              child: Container(
                                constraints: BoxConstraints(maxWidth: 600),
                                padding: EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                child: GestureDetector(
                                  onLongPress: () {
                                    _toggleVerbSelection(verb.base);
                                  },
                                  onTap: () {
                                    if (_isSelectionMode) {
                                      _toggleVerbSelection(verb.base);
                                    }
                                  },
                                  child: Card(
                                    color: isSelected 
                                      ? (themeProvider.isDarkTheme ? Colors.grey[700] : Colors.brown[100])
                                      : themeProvider.themeBackgroundColor,
                                    elevation: 4,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      side: isSelected
                                        ? BorderSide(
                                            color: themeProvider.isDarkTheme
                                                ? Colors.grey[500]!
                                                : Colors.brown[400]!,
                                            width: 2,
                                          )
                                        : BorderSide.none,
                                    ),
                                    child: Padding(
                                      padding: EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          // Перевод
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  verb.translation,
                                                  style: TextStyle(
                                                    fontSize: 24,
                                                    fontWeight: FontWeight.bold,
                                                    color: themeProvider.themeColor,
                                                  ),
                                                  textAlign: TextAlign.center,
                                                ),
                                              ),
                                              if (_isSelectionMode)
                                                Icon(
                                                  isSelected
                                                      ? Icons.check_circle
                                                      : Icons.circle_outlined,
                                                  color: themeProvider.themeColor,
                                                ),
                                            ],
                                          ),
                                          SizedBox(height: 16),

                                          // Формы глагола
                                          Table(
                                            columnWidths: {
                                              0: FlexColumnWidth(2),
                                              1: FlexColumnWidth(3),
                                            },
                                            children: [
                                              // Infinitive
                                              TableRow(
                                                children: [
                                                  Text(
                                                    verb.base,
                                                    style: TextStyle(
                                                      fontSize: 18,
                                                      color: themeProvider
                                                          .themeColor,
                                                    ),
                                                  ),
                                                  Text(
                                                    verb.baseTranscription,
                                                    style: TextStyle(
                                                      fontSize: 18,
                                                      color: themeProvider
                                                          .themeColor,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              TableRow(
                                                children: [
                                                  SizedBox(height: 8),
                                                  SizedBox(height: 8),
                                                ],
                                              ),
                                              // Past Simple
                                              TableRow(
                                                children: [
                                                  Text(
                                                    verb.pastSimple,
                                                    style: TextStyle(
                                                      fontSize: 18,
                                                      color: themeProvider
                                                          .themeColor,
                                                    ),
                                                  ),
                                                  Text(
                                                    verb.pastSimpleTranscription,
                                                    style: TextStyle(
                                                      fontSize: 18,
                                                      color: themeProvider
                                                          .themeColor,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              TableRow(
                                                children: [
                                                  SizedBox(height: 8),
                                                  SizedBox(height: 8),
                                                ],
                                              ),
                                              // Past Participle
                                              TableRow(
                                                children: [
                                                  Text(
                                                    verb.pastParticiple,
                                                    style: TextStyle(
                                                      fontSize: 18,
                                                      color: themeProvider
                                                          .themeColor,
                                                    ),
                                                  ),
                                                  Text(
                                                    verb.pastParticipleTranscription,
                                                    style: TextStyle(
                                                      fontSize: 18,
                                                      color: themeProvider
                                                          .themeColor,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                          
                                          SizedBox(height: 8),
                                          
                                          // Статус глагола и кнопки
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.end,
                                            children: [
                                              // Повторения
                                              if (verb.repetitions > 0)
                                                Row(
                                                  children: [
                                                    IconButton(
                                                      icon: Icon(
                                                        Icons.refresh,
                                                        size: 16,
                                                        color: themeProvider.themeColor,
                                                      ),
                                                      onPressed: () async {
                                                        final prefs = await SharedPreferences.getInstance();
                                                        await prefs.remove('verb_repetition_${verb.base}');
                                                        setState(() {
                                                          verb.repetitions = 0;
                                                          widget.onVerbsUpdated(_filteredVerbs);
                                                        });
                                                      },
                                                    ),
                                                    SizedBox(width: 4),
                                                    Text(
                                                      '${verb.repetitions}',
                                                      style: TextStyle(
                                                        color: themeProvider.themeColor,
                                                      ),
                                                    ),
                                                    SizedBox(width: 12),
                                                  ],
                                                ),
                                              
                                              // Изучено
                                              IconButton(
                                                icon: Icon(
                                                  verb.isLearned
                                                      ? Icons.check_circle
                                                      : Icons.check_circle_outline,
                                                  color: verb.isLearned
                                                      ? Colors.green
                                                      : themeProvider.themeColor,
                                                ),
                                                onPressed: () {
                                                  _toggleVerbLearned(index);
                                                },
                                              ),
                                              
                                              // Блокировка
                                              IconButton(
                                                icon: Icon(
                                                  verb.isBlocked
                                                      ? Icons.block
                                                      : Icons.lock_open_rounded,
                                                  color: verb.isBlocked
                                                      ? Colors.red
                                                      : themeProvider.themeColor,
                                                ),
                                                onPressed: () {
                                                  _toggleVerbBlocked(index);
                                                },
                                              ),
                                              
                                              // Редактирование
                                              IconButton(
                                                icon: Icon(
                                                  Icons.edit,
                                                  color: themeProvider.themeColor,
                                                ),
                                                onPressed: () {
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (context) =>
                                                          EditVerbScreen(
                                                        initialVerb: verb,
                                                        onVerbUpdated: (updatedVerb) {
                                                          setState(() {
                                                            _filterVerbs(_searchController.text);
                                                          });
                                                        },
                                                      ),
                                                    ),
                                                  );
                                                },
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      // Нижняя панель с кнопками
      bottomNavigationBar: !_isSelectionMode 
        ? Container(
            height: 80,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  constraints: BoxConstraints(maxWidth: 800),
                  width: MediaQuery.of(context).size.width,
                  padding: EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        flex: 1,
                        child: FloatingActionButton(
                          heroTag: 'verb_add',
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => AddVerbScreen(
                                  onVerbAdded: (newVerb) {
                                    widget.verbs.add(newVerb);
                                    widget.onVerbsUpdated(widget.verbs);
                                    setState(() {
                                      _filteredVerbs = List.from(widget.verbs);
                                      if (_searchController.text.isNotEmpty) {
                                        _filterVerbs(_searchController.text);
                                      }
                                    });
                                  },
                                ),
                              ),
                            );
                          },
                          child: Icon(Icons.add, color: Colors.white, size: 24),
                          backgroundColor: themeProvider.isDarkTheme
                              ? Colors.grey[800]
                              : Colors.brown[400]!,
                        ),
                      ),
                      SizedBox(width: 16),
                      Flexible(
                        flex: 4,
                        child: FloatingActionButton.extended(
                          heroTag: 'verb_learn',
                          onPressed: () {
                            // Подготавливаем список глаголов для изучения
                            List<Verb> learningVerbs = widget.verbs
                                .where((verb) => !verb.isBlocked && !verb.isLearned)
                                .toList();
                            
                            if (learningVerbs.isEmpty) {
                              learningVerbs = widget.verbs
                                  .where((verb) => !verb.isBlocked)
                                  .toList();
                            }
                            
                            if (learningVerbs.isNotEmpty) {
                              learningVerbs.shuffle();
                              if (learningVerbs.length > 5) {
                                learningVerbs = learningVerbs.sublist(0, 5);
                              }
                              // Запускаем обучение с подготовленным списком
                              _startLearningWithVerbs(learningVerbs);
                            } else {
                              _showSnackBar('Нет доступных глаголов для обучения');
                            }
                          },
                          label: Text(
                            "Изучить",
                            style: TextStyle(color: Colors.white, fontSize: 14),
                          ),
                          icon: Icon(Icons.school, color: Colors.white, size: 22),
                          backgroundColor: themeProvider.isDarkTheme
                              ? Colors.grey[800]
                              : Colors.brown[400]!,
                        ),
                      ),
                      SizedBox(width: 16),
                      Flexible(
                        flex: 4,
                        child: FloatingActionButton.extended(
                          heroTag: 'verb_repeat',
                          onPressed: () {
                            // Подготавливаем список глаголов только из изученных и не заблокированных
                            List<Verb> repeatingVerbs = widget.verbs
                                .where((verb) => verb.isLearned && !verb.isBlocked)
                                .toList();
                            
                            if (repeatingVerbs.isNotEmpty) {
                              repeatingVerbs.shuffle();
                              if (repeatingVerbs.length > 5) {
                                repeatingVerbs = repeatingVerbs.sublist(0, 5);
                              }
                              // Запускаем обучение с подготовленным списком
                              _startLearningWithVerbs(repeatingVerbs);
                            } else {
                              _showSnackBar('Нет доступных глаголов для повторения');
                            }
                          },
                          label: Text(
                            "Повторить",
                            style: TextStyle(color: Colors.white, fontSize: 14),
                          ),
                          icon: Icon(Icons.replay, color: Colors.white, size: 22),
                          backgroundColor: themeProvider.isDarkTheme
                              ? Colors.grey[800]
                              : Colors.brown[400]!,
                        ),
                      ),
                      SizedBox(width: 8),
                      SpeedDial(
                        heroTag: 'verb_speed_dial',
                        icon: Icons.menu,
                        activeIcon: Icons.close,
                        buttonSize: Size(52, 52),
                        visible: true,
                        closeManually: false,
                        curve: Curves.bounceIn,
                        overlayColor: Colors.black,
                        overlayOpacity: 0.5,
                        backgroundColor: themeProvider.isDarkTheme
                            ? Colors.grey[800]
                            : Colors.brown[400]!,
                        foregroundColor: Colors.white,
                        elevation: 8.0,
                        shape: CircleBorder(),
                        children: [
                          SpeedDialChild(
                            child: Icon(Icons.book),
                            backgroundColor: themeProvider.themeBackgroundColor,
                            foregroundColor: themeProvider.themeColor,
                            label: 'Перейти к словам',
                            labelStyle: TextStyle(fontSize: 14),
                            onTap: () => Navigator.pop(context),
                          ),
                          SpeedDialChild(
                            child: Icon(Icons.brightness_6),
                            backgroundColor: themeProvider.themeBackgroundColor,
                            foregroundColor: themeProvider.themeColor,
                            label:
                                'Тема: ${themeProvider.isDarkTheme ? "Тёмная" : "Светлая"}',
                            labelStyle: TextStyle(fontSize: 14),
                            onTap: () => themeProvider.toggleTheme(),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
        : null,
      floatingActionButton: null,
    );
  }
}
