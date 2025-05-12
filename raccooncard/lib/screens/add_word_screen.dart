import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/word.dart';
import '../models/category.dart';
import '../theme/theme_provider.dart';
import '../widgets/transcription_keyboard.dart';
import '../services/file_service.dart';
import 'dart:math' as math;

class AddWordScreen extends StatefulWidget {
  final List<Category> categories;
  final Function(Category) onCategoryUpdated;
  final String? preselectedCategory;
  final String? preselectedLevel;

  const AddWordScreen({
    Key? key,
    required this.categories,
    required this.onCategoryUpdated,
    this.preselectedCategory,
    this.preselectedLevel,
  }) : super(key: key);

  @override
  _AddWordScreenState createState() => _AddWordScreenState();
}

class _AddWordScreenState extends State<AddWordScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _englishController;
  late TextEditingController _russianController;
  late TextEditingController _transcriptionController;
  late FocusNode _transcriptionFocusNode;
  String _selectedCategory = '';
  String _selectedLevel = 'A2';
  final List<String> _levels = ['A2', 'B1', 'B1+'];

  @override
  void initState() {
    super.initState();
    _englishController = TextEditingController();
    _russianController = TextEditingController();
    _transcriptionController = TextEditingController();
    _transcriptionFocusNode = FocusNode();
    if (widget.preselectedCategory != null) {
      _selectedCategory = widget.preselectedCategory!;
    } else if (widget.categories.isNotEmpty) {
      _selectedCategory = widget.categories[0].name;
    }
    if (widget.preselectedLevel != null) {
      _selectedLevel = widget.preselectedLevel!;
    }
  }

  @override
  void dispose() {
    _englishController.dispose();
    _russianController.dispose();
    _transcriptionController.dispose();
    _transcriptionFocusNode.dispose();
    super.dispose();
  }

  void _addWord() async {
    if (_formKey.currentState!.validate()) {
      final category = widget.categories.firstWhere(
        (c) => c.name == _selectedCategory,
      );

      final newWord = Word(
        english: _englishController.text.trim(),
        russian: _russianController.text.trim(),
        transcription: _transcriptionController.text.trim(),
        level: _selectedLevel,
      );

      category.words.add(newWord);
      
      widget.onCategoryUpdated(category);
      
      // Сохраняем изменения в SharedPreferences
      await FileService.saveCategory(category);

      _englishController.clear();
      _russianController.clear();
      _transcriptionController.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Слово успешно добавлено')),
      );
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
          'Добавить слово',
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
                    child: DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      decoration: InputDecoration(
                        labelText: 'Категория',
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
                      items: widget.categories.map((category) {
                        return DropdownMenuItem(
                          value: category.name,
                          child: Text(
                            category.name,
                            style: TextStyle(
                              color: themeProvider.themeColor,
                              fontSize: 16,
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedCategory = value!;
                        });
                      },
                    ),
                  ),
                  SizedBox(height: 16),
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
                  SizedBox(height: 24),
                  Container(
                    constraints: BoxConstraints(maxHeight: 50),
                    child: ElevatedButton(
                      onPressed: _addWord,
                      child: Text(
                        'Добавить слово',
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
