import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/category.dart';
import '../models/verb.dart';
import '../models/word.dart';
import '../theme/theme_provider.dart';
import 'add_word_screen.dart';
import 'word_list_screen.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'verbs_screen.dart';
import '../services/file_service.dart';

class HomeScreen extends StatefulWidget {
  final List<Category> categories;
  final List<Verb> verbs;

  const HomeScreen({
    Key? key,
    required this.categories,
    required this.verbs,
  }) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedLevel = "Все"; // Выбранный уровень фильтрации
  final List<String> levels = ["Все", "A2", "B1", "B1+"];
  // Режим выбора категорий
  bool _isSelectionMode = false;
  final Set<String> _selectedCategories = {};

  // Функция для получения отфильтрованных категорий
  List<Map<String, dynamic>> getFilteredCategories(String level) {
    final filteredCategories = <Map<String, dynamic>>[];
    
    for (var category in widget.categories) {
      // Отфильтровываем слова по выбранному уровню
      final List<Word> wordsForLevel;
      
      if (level == "Все") {
        // Если выбраны все уровни, используем все слова категории
        wordsForLevel = category.words;
      } else {
        // Если выбран конкретный уровень, фильтруем только по нему
        wordsForLevel = category.words.where((word) => word.level == level).toList();
      }
      
      // Пропускаем категории без слов после фильтрации
      if (wordsForLevel.isEmpty) {
        continue;
      }
      
      // Удаление дубликатов слов
      final uniqueWords = wordsForLevel.toSet().toList();

      // Подсчитываем количество изученных слов
      final learnedCount = uniqueWords.where((word) => word.isLearned ?? false).length;

      // Добавляем категорию в отфильтрованный список
      filteredCategories.add({
        "name": category.name,
        "words": uniqueWords,
        "learnedPercentage":
            uniqueWords.isEmpty ? 0.0 : (learnedCount / uniqueWords.length).toDouble(),
      });
    }

    // Сортируем категории по алфавиту
    filteredCategories.sort((a, b) {
      String nameA = a["name"].toString().toLowerCase();
      String nameB = b["name"].toString().toLowerCase();
      
      // Специальная обработка для Unit-категорий
      if (nameA.startsWith('unit ') && nameB.startsWith('unit ')) {
        int numA = int.tryParse(nameA.substring(5)) ?? 0;
        int numB = int.tryParse(nameB.substring(5)) ?? 0;
        return numA.compareTo(numB);
      }
      
      return nameA.compareTo(nameB);
    });
    
    return filteredCategories;
  }

  // Переключение выбора категории
  void _toggleCategorySelection(String categoryName) {
    setState(() {
      if (_selectedCategories.contains(categoryName)) {
        _selectedCategories.remove(categoryName);
      } else {
        _selectedCategories.add(categoryName);
      }
      _isSelectionMode = _selectedCategories.isNotEmpty;
    });
  }

  // Отмена выделения
  void _cancelSelection() {
    setState(() {
      _selectedCategories.clear();
      _isSelectionMode = false;
    });
  }

  // Удаление выбранных категорий
  Future<void> _deleteSelectedCategories() async {
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
          'Вы уверены, что хотите удалить выбранные категории?\nЭто действие нельзя отменить!',
          style: TextStyle(
            color: themeProvider.themeColor,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Закрываем диалог
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
                // Удаляем каждую выбранную категорию
                for (String categoryName in _selectedCategories) {
                  widget.categories.removeWhere((category) => category.name == categoryName);
                  // Удаляем категорию из файловой системы
                  await FileService.deleteCategory(categoryName);
                }
                
                // Очищаем выбранные категории и выходим из режима выбора
                setState(() {
                  _selectedCategories.clear();
                  _isSelectionMode = false;
                });
                
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Выбранные категории успешно удалены'),
                    duration: Duration(seconds: 2),
                  ),
                );
              } catch (e) {
                print('Ошибка при удалении категорий: $e');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Произошла ошибка при удалении категорий'),
                      duration: Duration(seconds: 2),
                    ),
                  );
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

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: themeProvider.scaffoldBackgroundColor,
      appBar: AppBar(
        title: _isSelectionMode 
          ? Text(
              "Выбрано: ${_selectedCategories.length}",
              style: TextStyle(color: Colors.white),
            )
          : null,
        automaticallyImplyLeading: false,
        backgroundColor:
            themeProvider.isDarkTheme ? Colors.grey[800] : Colors.brown[400],
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          if (_isSelectionMode)
            IconButton(
              icon: Icon(Icons.cancel, color: Colors.white),
              onPressed: _cancelSelection,
            ),
          if (_isSelectionMode)
            IconButton(
              icon: Icon(Icons.delete, color: Colors.white),
              onPressed: _deleteSelectedCategories,
            ),
        ],
      ),
      body: Center(
        child: SafeArea(
          bottom: true,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final maxWidth =
                  constraints.maxWidth > 600 ? 600.0 : double.infinity;

              return Column(
                children: [
                  // Верхняя панель (заголовок, поиск, фильтры)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxWidth),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            "Raccoon Card",
                            style: TextStyle(
                              fontSize: screenHeight * 0.06,
                              fontWeight: FontWeight.bold,
                              color: themeProvider.themeColor,
                            ),
                          ),
                          SizedBox(height: 10),
                          TextField(
                            controller: _searchController,
                            cursorColor: themeProvider.themeColor,
                            decoration: InputDecoration(
                              labelText: 'Поиск',
                              labelStyle:
                                  TextStyle(color: themeProvider.themeColor),
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
                                fontSize: 16, color: themeProvider.themeColor),
                            onChanged: (query) {
                              setState(() {});
                            },
                          ),
                          SizedBox(height: 10),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: levels.map((level) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 4.0),
                                  child: ChoiceChip(
                                    label: Text(
                                      level,
                                      style: TextStyle(
                                        color: _selectedLevel == level
                                            ? Colors.white
                                            : themeProvider.themeColor,
                                      ),
                                    ),
                                    selectedColor: themeProvider.isDarkTheme
                                        ? Colors.grey[700]
                                        : Colors.brown[400],
                                    backgroundColor:
                                        themeProvider.themeBackgroundColor,
                                    side: BorderSide(
                                      color: _selectedLevel == level
                                          ? Colors.transparent
                                          : themeProvider.themeColor,
                                      width: 1.5,
                                    ),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(20)),
                                    selected: _selectedLevel == level,
                                    onSelected: (selected) {
                                      setState(() {
                                        _selectedLevel =
                                            selected ? level : "Все";
                                      });
                                    },
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Список категорий
                  Expanded(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxWidth),
                      child: Builder(
                        builder: (context) {
                          final filteredCategories =
                              getFilteredCategories(_selectedLevel);

                          // Фильтрация по поисковому запросу
                          if (_searchController.text.isNotEmpty) {
                            filteredCategories.removeWhere((category) =>
                                !category["name"]
                                    .toString()
                                    .toLowerCase()
                                    .contains(
                                        _searchController.text.toLowerCase()));
                          }

                          if (filteredCategories.isEmpty) {
                            return Center(
                              child: Text(
                                'Категории не найдены',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: themeProvider.themeColor,
                                ),
                              ),
                            );
                          }

                          return ListView.builder(
                            padding: EdgeInsets.symmetric(
                                vertical: 10, horizontal: 16),
                            itemCount: filteredCategories.length,
                            itemBuilder: (context, index) {
                              final category = filteredCategories[index];
                              final categoryName = category["name"] as String;
                              final words = category["words"] as List<Word>;
                              final learnedPercentage =
                                  category["learnedPercentage"] as double;
                              final isSelected = _selectedCategories.contains(categoryName);

                              return GestureDetector(
                                onLongPress: () {
                                  _toggleCategorySelection(categoryName);
                                },
                                onTap: () {
                                  if (_isSelectionMode) {
                                    _toggleCategorySelection(categoryName);
                                  } else {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => WordListScreen(
                                          categoryName: categoryName,
                                          level: _selectedLevel,
                                          categories: widget.categories,
                                          onCategoryUpdated: (updatedCategory) {
                                            setState(() {
                                              final index = widget.categories
                                                  .indexWhere((c) =>
                                                      c.name ==
                                                      updatedCategory.name);
                                              if (index != -1) {
                                                widget.categories[index] =
                                                    updatedCategory;
                                              }
                                            });
                                          },
                                        ),
                                      ),
                                    );
                                  }
                                },
                                child: Card(
                                  color: isSelected 
                                      ? (themeProvider.isDarkTheme ? Colors.grey[700] : Colors.brown[100])
                                      : themeProvider.themeBackgroundColor,
                                  elevation: 2,
                                  margin: EdgeInsets.only(bottom: 12),
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
                                    padding: const EdgeInsets.all(16.0),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                categoryName,
                                                style: TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                  color:
                                                      themeProvider.themeColor,
                                                ),
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
                                        SizedBox(height: 8),
                                        Text(
                                          'Слов: ${words.length}',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: themeProvider.themeColor,
                                          ),
                                        ),
                                        SizedBox(height: 8),
                                        LinearProgressIndicator(
                                          value: learnedPercentage,
                                          backgroundColor:
                                              themeProvider.isDarkTheme
                                                  ? Colors.grey[700]
                                                  : Colors.grey[300],
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                            themeProvider.isDarkTheme
                                                ? Colors.greenAccent
                                                : Colors.green,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          'Изучено: ${(learnedPercentage * 100).toInt()}%',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: themeProvider.themeColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),

      // Нижняя панель с кнопками
      bottomNavigationBar: Container(
        height: 80,
        padding: EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Кнопки добавления
              Row(
                children: [
                  FloatingActionButton.extended(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AddWordScreen(
                            categories: widget.categories,
                            onCategoryUpdated: (updatedCategory) async {
                              setState(() {
                                final index = widget.categories.indexWhere(
                                  (category) =>
                                      category.name == updatedCategory.name,
                                );
                                if (index != -1) {
                                  widget.categories[index] = updatedCategory;
                                }
                              });
                              
                              // Сохраняем обновленную категорию
                              await FileService.saveCategory(updatedCategory);
                            },
                          ),
                        ),
                      );
                    },
                    label: Text("Добавить слово",
                        style: TextStyle(color: Colors.white, fontSize: 15)),
                    icon: Icon(Icons.add, color: Colors.white),
                    backgroundColor: themeProvider.isDarkTheme
                        ? Colors.grey[800]
                        : Colors.brown[400]!,
                    heroTag: 'home_add_word',
                    extendedPadding: EdgeInsets.symmetric(horizontal: 20),
                  ),
                  SizedBox(width: 20),
                  FloatingActionButton.extended(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => AddCategoryDialog(
                          categories: widget.categories,
                          onCategoryAdded: (newCategory) {
                            setState(() {
                              widget.categories.add(newCategory);
                            });
                          },
                        ),
                      );
                    },
                    label: Text("Добавить категорию",
                        style: TextStyle(color: Colors.white, fontSize: 15)),
                    icon: Icon(Icons.add_circle_outline, color: Colors.white),
                    backgroundColor: themeProvider.isDarkTheme
                        ? Colors.grey[800]
                        : Colors.brown[400]!,
                    heroTag: 'home_add_category',
                    extendedPadding: EdgeInsets.symmetric(horizontal: 20),
                  ),
                ],
              ),

              
              SizedBox(width: 20),
              SpeedDial(
                icon: Icons.menu,
                activeIcon: Icons.close,
                buttonSize: Size(60, 60),
                visible: true,
                closeManually: false,
                curve: Curves.easeInOut,
                overlayColor: Colors.black,
                overlayOpacity: 0.5,
                backgroundColor: themeProvider.isDarkTheme
                    ? Colors.grey[800]
                    : Colors.brown[400]!,
                foregroundColor: Colors.white,
                direction: SpeedDialDirection.up,
                heroTag: 'speed_dial_menu',
                children: [
                  // Переход к глаголам
                  SpeedDialChild(
                    child: Icon(Icons.directions_run),
                    foregroundColor: themeProvider.themeColor,
                    backgroundColor: themeProvider.themeBackgroundColor,
                    label: 'Перейти к глаголам',
                    labelStyle: TextStyle(
                        fontSize: 15, color: themeProvider.themeColor),
                    labelBackgroundColor: themeProvider.themeBackgroundColor,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => VerbsScreen(
                            verbs: widget.verbs,
                            onVerbsUpdated: (updatedVerbs) async {
                              setState(() {
                                // Обновляем список глаголов
                                for (int i = 0; i < updatedVerbs.length; i++) {
                                  if (i < widget.verbs.length) {
                                    widget.verbs[i] = updatedVerbs[i];
                                  }
                                }
                              });
                              // Сохраняем глаголы
                              await FileService.saveVerbs(widget.verbs);
                            },
                          ),
                        ),
                      );
                    },
                  ),
                  // Изменение темы
                  SpeedDialChild(
                    child: Icon(Icons.brightness_6),
                    foregroundColor: themeProvider.themeColor,
                    backgroundColor: themeProvider.themeBackgroundColor,
                    label:
                        'Тема: ${themeProvider.isDarkTheme ? "Тёмная" : "Яркая"}',
                    labelStyle: TextStyle(
                      fontSize: 15,
                      color: themeProvider.themeColor,
                    ),
                    labelBackgroundColor: themeProvider.themeBackgroundColor,
                    onTap: () => themeProvider.toggleTheme(),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Диалоговое окно для добавления категории
class AddCategoryDialog extends StatelessWidget {
  final List<Category> categories;
  final Function(Category)
      onCategoryAdded;
  final TextEditingController _categoryNameController = TextEditingController();

  AddCategoryDialog({
    required this.categories,
    required this.onCategoryAdded,
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return AlertDialog(
      backgroundColor: themeProvider.themeBackgroundColor,
      title: Text(
        'Добавить категорию',
        style: TextStyle(
          fontSize: 18,
          color: themeProvider.themeColor,
        ),
      ),
      content: TextField(
        controller: _categoryNameController,
        cursorColor: themeProvider.themeColor,
        decoration: InputDecoration(
          labelText: 'Название категории',
          labelStyle: TextStyle(
            color: themeProvider.themeColor,
          ),
          filled: true,
          fillColor: themeProvider.themeBackgroundColor,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        ),
        style: TextStyle(
          fontSize: 16,
          color: themeProvider.themeColor,
        ),
        textCapitalization: TextCapitalization.sentences,
        keyboardType: TextInputType.text,
        textInputAction: TextInputAction.done,
      ),
      actions: [
        // Кнопка "Отмена"
        TextButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: Text(
            'Отмена',
            style: TextStyle(
              fontSize: 16,
              color: themeProvider.themeColor,
            ),
          ),
        ),
        // Кнопка "Добавить"
        ElevatedButton(
          onPressed: () async {
            if (_categoryNameController.text.isNotEmpty) {
              final categoryName = _categoryNameController.text.trim();

              // Проверка на существование категории
              if (categories.any((category) => category.name == categoryName)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content:
                          Text('Категория "$categoryName" уже существует!')),
                );
                return;
              }

              // Создание новой категории
              final newCategory = Category(name: categoryName, words: []);

              // Сохраняем категорию в SharedPreferences
              bool saved = await FileService.saveCategory(newCategory);
              
              if (saved) {
                onCategoryAdded(newCategory);
                
                // Сортируем категории по алфавиту
                categories.sort((a, b) {
                  String nameA = a.name.toLowerCase();
                  String nameB = b.name.toLowerCase();
                  
                  // Специальная обработка для Unit-категорий
                  if (nameA.startsWith('unit ') && nameB.startsWith('unit ')) {
                    // Извлекаем числа
                    int numA = int.tryParse(nameA.substring(5)) ?? 0;
                    int numB = int.tryParse(nameB.substring(5)) ?? 0;
                    return numA.compareTo(numB);
                  }
                  
                  return nameA.compareTo(nameB);
                });
                
                _categoryNameController.clear();
                Navigator.pop(context);
                
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Категория "$categoryName" успешно добавлена')),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Ошибка при сохранении категории')),
                );
              }
            }
          },
          child: Text(
            'Добавить',
            style: TextStyle(fontSize: 16, color: Colors.white),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: themeProvider.isDarkTheme
                ? Colors.grey[700]
                : Colors.brown[400],
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }
}
