import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/category.dart';
import '../models/word.dart';
import '../theme/theme_provider.dart';
import '../widgets/transcription_keyboard.dart';
import '../services/file_service.dart';
import 'dart:math' as math;

class EditWordScreen extends StatefulWidget {
  final int wordIndex;
  final Word initialWord;
  final Category category;
  final Function(Category) onCategoryUpdated;

  const EditWordScreen({
    Key? key,
    required this.wordIndex,
    required this.initialWord,
    required this.category,
    required this.onCategoryUpdated,
  }) : super(key: key);

  @override
  _EditWordScreenState createState() => _EditWordScreenState();
}

class _EditWordScreenState extends State<EditWordScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _englishController;
  late TextEditingController _russianController;
  late TextEditingController _transcriptionController;
  late FocusNode _transcriptionFocusNode;
  late String _selectedLevel;
  final List<String> _levels = ['A2', 'B1', 'B1+'];
  bool _isLearned = false;
  bool _isBlocked = false;

  @override
  void initState() {
    super.initState();
    _englishController =
        TextEditingController(text: widget.initialWord.english);
    _russianController =
        TextEditingController(text: widget.initialWord.russian);
    _transcriptionController =
        TextEditingController(text: widget.initialWord.transcription);
    _transcriptionFocusNode = FocusNode();
    _selectedLevel = widget.initialWord.level;
    _isLearned = widget.initialWord.isLearned;
    _isBlocked = widget.initialWord.isBlocked;
  }

  @override
  void dispose() {
    _englishController.dispose();
    _russianController.dispose();
    _transcriptionController.dispose();
    _transcriptionFocusNode.dispose();
    super.dispose();
  }

  void _updateWord() async {
    if (_formKey.currentState!.validate()) {
      // Обновляем слово напрямую в списке, а не создаем новый объект
      try {
        // Получаем текущий индекс слова в списке категории
        int originalIndex = -1;
        for (int i = 0; i < widget.category.words.length; i++) {
          if (widget.category.words[i].english == widget.initialWord.english &&
              widget.category.words[i].russian == widget.initialWord.russian) {
            originalIndex = i;
            break;
          }
        }
        
        // Если слово найдено
        if (originalIndex >= 0) {
          final updatedWord = Word(
            english: _englishController.text.trim(),
            russian: _russianController.text.trim(),
            transcription: _transcriptionController.text.trim(),
            level: _selectedLevel,
            isLearned: _isLearned,
            isBlocked: _isBlocked,
            repetitions: widget.category.words[originalIndex].repetitions,
          );
          
          widget.category.words[originalIndex] = updatedWord;
          
          widget.onCategoryUpdated(widget.category);
          
          await FileService.saveCategory(widget.category);
          
          // Возвращаемся на предыдущий экран с результатом
          Navigator.pop(context, true);
          
          // Показываем уведомление
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Слово успешно обновлено')),
          );
        } else {
          // Если слово не найдено
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ошибка: слово не найдено в категории')),
          );
        }
      } catch (e) {
        print('Ошибка при обновлении слова: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Произошла ошибка при обновлении слова')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final screenSize = MediaQuery.of(context).size;
    final maxWidth = math.min(screenSize.width - 32, 600.0);

    return Scaffold(
      backgroundColor: themeProvider.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Редактировать слово',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor:
            themeProvider.isDarkTheme ? Colors.grey[800] : Colors.brown[400],
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(context).size.height * 0.4),
          child: Container(
            constraints: BoxConstraints(maxWidth: maxWidth),
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    constraints: BoxConstraints(maxHeight: 60),
                    child: TextFormField(
                      controller: _englishController,
                      decoration: InputDecoration(
                        labelText: 'Английское слово',
                        labelStyle: TextStyle(color: themeProvider.themeColor),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              BorderSide(color: themeProvider.themeColor),
                        ),
                      ),
                      style: TextStyle(
                        color: themeProvider.themeColor,
                        fontSize: 16,
                      ),
                      cursorColor: themeProvider.themeColor,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Пожалуйста, введите английское слово';
                        }
                        return null;
                      },
                    ),
                  ),
                  SizedBox(height: 16),
                  Container(
                    constraints: BoxConstraints(maxHeight: 60),
                    child: TextFormField(
                      controller: _transcriptionController,
                      focusNode: _transcriptionFocusNode,
                      decoration: InputDecoration(
                        labelText: 'Транскрипция',
                        labelStyle: TextStyle(color: themeProvider.themeColor),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              BorderSide(color: themeProvider.themeColor),
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(Icons.keyboard,
                              color: themeProvider.themeColor),
                          onPressed: () {
                            FocusScope.of(context)
                                .requestFocus(_transcriptionFocusNode);
                            showModalBottomSheet(
                              context: context,
                              backgroundColor: Colors.transparent,
                              barrierColor: Colors.transparent,
                              isScrollControlled: true,
                              builder: (context) => Padding(
                                padding: EdgeInsets.only(
                                  bottom:
                                      MediaQuery.of(context).viewInsets.bottom,
                                ),
                                child: TranscriptionKeyboard(
                                  controller: _transcriptionController,
                                  onClose: () => Navigator.pop(context),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      style: TextStyle(
                        color: themeProvider.themeColor,
                        fontSize: 16,
                      ),
                      cursorColor: themeProvider.themeColor,
                    ),
                  ),
                  SizedBox(height: 16),
                  Container(
                    constraints: BoxConstraints(maxHeight: 60),
                    child: TextFormField(
                      controller: _russianController,
                      decoration: InputDecoration(
                        labelText: 'Русский перевод',
                        labelStyle: TextStyle(color: themeProvider.themeColor),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              BorderSide(color: themeProvider.themeColor),
                        ),
                      ),
                      style: TextStyle(
                        color: themeProvider.themeColor,
                        fontSize: 16,
                      ),
                      cursorColor: themeProvider.themeColor,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Пожалуйста, введите русский перевод';
                        }
                        return null;
                      },
                    ),
                  ),
                  SizedBox(height: 16),
                  Container(
                    constraints: BoxConstraints(maxHeight: 60),
                    child: DropdownButtonFormField<String>(
                      value: _selectedLevel,
                      decoration: InputDecoration(
                        labelText: 'Уровень',
                        labelStyle: TextStyle(color: themeProvider.themeColor),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              BorderSide(color: themeProvider.themeColor),
                        ),
                      ),
                      style: TextStyle(
                        color: themeProvider.themeColor,
                        fontSize: 16,
                      ),
                      dropdownColor: themeProvider.themeBackgroundColor,
                      items: _levels.map((level) {
                        return DropdownMenuItem(
                          value: level,
                          child: Text(
                            level,
                            style: TextStyle(
                              color: themeProvider.themeColor,
                              fontSize: 16,
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedLevel = value!;
                        });
                      },
                    ),
                  ),
                  SizedBox(height: 16),
                  Container(
                    constraints: BoxConstraints(maxHeight: 60),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: CheckboxListTile(
                            title: Text(
                              'Изучено',
                              style: TextStyle(
                                color: themeProvider.themeColor,
                                fontSize: 16,
                              ),
                            ),
                            value: _isLearned,
                            onChanged: (bool? value) {
                              setState(() {
                                _isLearned = value ?? false;
                              });
                            },
                            activeColor: themeProvider.isDarkTheme
                                ? Colors.grey[700]
                                : Colors.brown[400],
                          ),
                        ),
                        Expanded(
                          child: CheckboxListTile(
                            title: Text(
                              'Заблокировано',
                              style: TextStyle(
                                color: themeProvider.themeColor,
                                fontSize: 16,
                              ),
                            ),
                            value: _isBlocked,
                            onChanged: (bool? value) {
                              setState(() {
                                _isBlocked = value ?? false;
                              });
                            },
                            activeColor: themeProvider.isDarkTheme
                                ? Colors.grey[700]
                                : Colors.brown[400],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 24),
                  Container(
                    constraints: BoxConstraints(maxHeight: 50),
                    child: ElevatedButton(
                      onPressed: _updateWord,
                      child: Text(
                        'Сохранить изменения',
                        style: TextStyle(fontSize: 16, color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: themeProvider.isDarkTheme
                            ? Colors.grey[700]
                            : Colors.brown[400],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
