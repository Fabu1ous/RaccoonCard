import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/category.dart';
import '../models/word.dart';
import '../models/verb.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class FileService {
  // Константы для путей к файлам
  // Путь для rootBundle не должен содержать "assets/" в начале,
  // т.к. rootBundle автоматически добавляет этот префикс
  static const String CATEGORIES_FILE = 'categories.txt';
  static const String VERBS_FILE = 'verbs.txt';
  static const String CATEGORIES_DIR = 'categories/';
  
  // Ключи для хранения данных в SharedPreferences
  static const String CUSTOM_CATEGORIES_KEY = 'custom_categories';
  static const String CUSTOM_WORDS_PREFIX = 'custom_words_';
  
  /// Загружает все категории и их слова
  static Future<List<Category>> loadCategories() async {
    try {
      // Сначала пытаемся загрузить из локальной файловой системы
      List<Category> localCategories = [];
      
      try {
        localCategories = await loadCategoriesFromLocalFiles();
        if (localCategories.isNotEmpty) {
          print('Loaded ${localCategories.length} categories from local files');
          return localCategories;
        }
      } catch (e) {
        print('Error loading categories from local files: $e');
      }
      
      // Если не удалось, загружаем встроенные категории
      List<Category> categories = await _loadBuiltInCategories();
      
      // Загружаем пользовательские категории
      List<Category> customCategories = await _loadCustomCategories();
      
      // Объединяем списки
      categories.addAll(customCategories);
      
      return categories;
    } catch (e) {
      print('Error loading categories: $e');
      return [];
    }
  }
  
  /// Загружает категории с фильтрацией по уровню
  static Future<List<Category>> loadCategoriesForLevel(String level) async {
    try {
      // Получаем все категории
      List<Category> allCategories = await loadCategories();
      
      // Если требуются все уровни, возвращаем как есть
      if (level == "Все") {
        return allCategories;
      }
      
      // Если нужен конкретный уровень, загружаем только его
      List<Category> filteredCategories = [];
      
      // Для каждой категории фильтруем слова только для выбранного уровня
      for (var category in allCategories) {
        // Фильтруем слова только для выбранного уровня
        List<Word> filteredWords = category.words.where((word) => word.level == level).toList();
        
        // Создаем новую категорию с отфильтрованными словами
        Category filteredCategory = Category(
          name: category.name,
          words: filteredWords,
          isEditable: category.isEditable,
        );
        
        filteredCategories.add(filteredCategory);
      }
      
      return filteredCategories;
    } catch (e) {
      print('Error loading categories for level $level: $e');
      return [];
    }
  }
  
  /// Загружает категории из локальных файлов с фильтрацией по уровню
  static Future<List<Category>> loadCategoriesFromLocalFilesForLevel(String level) async {
    try {
      // Если требуются все уровни, загружаем все категории
      if (level == "Все") {
        return await loadCategoriesFromLocalFiles();
      }
      
      // Преобразуем отображаемый уровень в имя файла
      String fileLevel;
      switch (level) {
        case 'B1+':
          fileLevel = 'B1plus';
          break;
        default:
          fileLevel = level; // A2, B1
          break;
      }
      
      final directory = await _getLocalDirectory();
      List<FileSystemEntity> entities = await directory.list().toList();
      List<String> categoryNames = entities
          .where((entity) => entity is Directory && entity.path.contains('categories'))
          .map((entity) => entity.path.split('/').last)
          .toList();
      
      List<Category> categories = [];
      
      for (String categoryName in categoryNames) {
        if (_isValidCategoryName(categoryName)) {
          Category category = await _loadCategoryFromLocalFilesForLevel(categoryName, fileLevel);
          categories.add(category);
        }
      }
      
      return categories;
    } catch (e) {
      print('Error loading categories from local files for level $level: $e');
      return [];
    }
  }
  
  /// Загружает слова для конкретной категории и уровня из локальных файлов
  static Future<Category> _loadCategoryFromLocalFilesForLevel(String categoryName, String fileLevel) async {
    try {
      // Путь к файлу уровня
      final directory = await _getLocalDirectory();
      final levelFile = File('${directory.path}/categories/$categoryName/$fileLevel.json');
      
      List<Word> words = [];
      
      // Если файл существует, загружаем слова из него
      if (await levelFile.exists()) {
        String content = await levelFile.readAsString();
        List<dynamic> wordsJson = jsonDecode(content);
        words = wordsJson.map((wordJson) => Word.fromJson(wordJson)).toList();
      }
      
      // Создаем категорию только с словами указанного уровня
      return Category(
        name: categoryName,
        words: words,
        isEditable: true,
      );
    } catch (e) {
      print('Error loading category $categoryName for level $fileLevel: $e');
      return Category(name: categoryName, isEditable: true);
    }
  }
  
  /// Загружает категории из локальной файловой системы
  static Future<List<Category>> loadCategoriesFromLocalFiles() async {
    try {
      final List<Category> categories = [];
      
      // 1. Сначала пытаемся загрузить категории из обычного файла categories_local.txt
      final String path = await _getLocalPath();
      final String categoriesFile = '$path/categories_local.txt';
      final File file = File(categoriesFile);
      
      if (await file.exists()) {
        print('Loading categories from $categoriesFile');
        // Читаем с явным указанием кодировки UTF-8
        final String content = await file.readAsString(encoding: utf8);
        final categoryNames = LineSplitter.split(content)
            .where((line) => line.trim().isNotEmpty)
            .toList();
        
        if (categoryNames.isNotEmpty) {
          print('Found ${categoryNames.length} categories in categories_local.txt');
          for (var categoryName in categoryNames) {
            try {
              final category = await _loadCategoryFromLocalFiles(categoryName);
              categories.add(category);
              print('Added category ${category.name} with ${category.words.length} words');
            } catch (e) {
              print('Error loading local category $categoryName: $e');
            }
          }
        }
      }
      
      // 2. Загружаем все категории из директории categories
      final Directory categoriesDir = Directory('$path/categories');
      
      if (await categoriesDir.exists()) {
        final List<FileSystemEntity> entries = await categoriesDir.list().toList();
        // Фильтруем только директории
        final catDirs = entries.whereType<Directory>().toList();
        
        print('Found ${catDirs.length} category directories');
        
        for (var catDir in catDirs) {
          // Получаем имя категории, заменяя подчеркивания на пробелы
          String dirName = catDir.path.split(Platform.isWindows ? '\\' : '/').last;
          String categoryName = dirName.replaceAll('_', ' ');
          
          // Проверяем, не загружена ли уже эта категория
          if (!categories.any((c) => c.name == categoryName)) {
            try {
              final category = await _loadCategoryFromLocalFiles(categoryName);
              categories.add(category);
              print('Added category ${category.name} with ${category.words.length} words from directory');
            } catch (e) {
              print('Error loading category $categoryName from directory: $e');
            }
          }
        }
      }
      
      // Сортируем категории с учетом натуральной сортировки для Unit-категорий
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
      
      print('Loaded ${categories.length} categories from local files');
      return categories;
    } catch (e) {
      print('Error loading categories from local files: $e');
      return [];
    }
  }
  
  /// Загружает одну категорию из локальной файловой системы
  static Future<Category> _loadCategoryFromLocalFiles(String categoryName) async {
    try {
      final List<Word> words = [];
      final bool isUnitCategory = categoryName.startsWith('Unit ');
      
      // Очищаем имя директории от недопустимых символов
      final String safeDirName = categoryName
          .replaceAll(' ', '_')
          .replaceAll('/', '_')
          .replaceAll('\\', '_')
          .replaceAll(':', '_')
          .replaceAll('*', '_')
          .replaceAll('?', '_')
          .replaceAll('"', '_')
          .replaceAll('<', '_')
          .replaceAll('>', '_')
          .replaceAll('|', '_');
      
      // Определяем уровни с их отображаемыми именами
      final levelMap = {
        'A2': 'A2',
        'B1': 'B1',
        'B1plus': 'B1+'
      };
      
      final path = await _getLocalPath();
      
      if (isUnitCategory) {
        // Это Unit категория, проверяем файлы A2/B1/B1plus
        for (var entry in levelMap.entries) {
          String level = entry.key;
          
          try {
            final String filePath = '$path/categories/$safeDirName/$level.txt';
            final file = File(filePath);
            
            if (await file.exists()) {
              final fileContent = await file.readAsString(encoding: utf8);
              if (fileContent.trim().isNotEmpty) {
                _parseWords(fileContent, level, words);
                print('Loaded $level words for $categoryName from local file');
              }
            }
          } catch (e) {
            print('Error loading $level words for $categoryName: $e');
          }
        }
      } else {
        // Обычная категория, проверяем файлы A2/B1/B1plus в подпапке
        try {
          final String dirPath = '$path/categories/$safeDirName';
          final Directory dir = Directory(dirPath);
          
          if (await dir.exists()) {
            // Проверяем наличие файлов уровней
            for (var entry in levelMap.entries) {
              String level = entry.key;
              
              final String filePath = '$dirPath/$level.txt';
              final file = File(filePath);
              
              if (await file.exists()) {
                final fileContent = await file.readAsString(encoding: utf8);
                if (fileContent.trim().isNotEmpty) {
                  _parseWords(fileContent, level, words);
                  print('Loaded $level words for $categoryName from local file');
                }
              }
            }
          } else {
            // Проверяем старый формат - обычные файлы
            final String filePath = '$path/categories/$safeDirName.txt';
            final file = File(filePath);
            
            if (await file.exists()) {
              final fileContent = await file.readAsString(encoding: utf8);
              if (fileContent.trim().isNotEmpty) {
                _parseWords(fileContent, null, words);
                print('Loaded words for $categoryName from local file');
              }
            }
          }
        } catch (e) {
          print('Error loading words for $categoryName: $e');
        }
      }
      
      return Category(
        name: categoryName,
        words: words,
        isEditable: true, // Категории из локальной файловой системы редактируемые
      );
    } catch (e) {
      print('Error in _loadCategoryFromLocalFiles for $categoryName: $e');
      return Category(
        name: categoryName,
        words: [],
        isEditable: true,
      );
    }
  }
  
  /// Загружает встроенные категории из ассетов
  static Future<List<Category>> _loadBuiltInCategories() async {
    try {
      List<Category> categories = [];
      
      // Загружаем список категорий из categories.txt
      try {
        final categoriesContent = await rootBundle.loadString('assets/$CATEGORIES_FILE');
        final categoryNames = LineSplitter.split(categoriesContent)
            .where((line) => line.trim().isNotEmpty)
            .toList();
        
        if (categoryNames.isNotEmpty) {
          print('Found ${categoryNames.length} categories in assets/$CATEGORIES_FILE');
          
          for (var categoryName in categoryNames) {
            try {
              final category = await _loadCategoryWordsDirectly(categoryName);
              if (category.words.isNotEmpty) {
                categories.add(category);
                print('Added category ${category.name} with ${category.words.length} words');
              } else {
                print('Warning: Category $categoryName has no words');
              }
            } catch (e) {
              print('Error loading category $categoryName: $e');
            }
          }
        } else {
          print('No categories found in assets/$CATEGORIES_FILE');
        }
      } catch (e) {
        print('Error loading categories from file assets/$CATEGORIES_FILE: $e');
      }
      
      return categories;
    } catch (e) {
      print('Error loading built-in categories: $e');
      return [];
    }
  }
  
  /// Загружает слова для категории из ассетов напрямую
  static Future<Category> _loadCategoryWordsDirectly(String categoryName) async {
    final List<Word> words = [];
    try {
      // Загружаем слова для категории из разных уровней
      final levels = ['A2', 'B1', 'B1plus'];
      for (var level in levels) {
        try {
          final String filePath = 'assets/$CATEGORIES_DIR$categoryName/$level.txt';
          try {
            // Пробуем загрузить файл, но если его нет - тихо пропускаем
            final fileContent = await rootBundle.loadString(filePath);
            if (fileContent.trim().isNotEmpty) {
              _parseWords(fileContent, level, words);
              print('Loaded $level words for $categoryName');
            }
          } catch (e) {
            // Молча пропускаем, если файла для уровня нет
            //print('No $level words for $categoryName: ${e.toString().substring(0, math.min(50, e.toString().length))}...');
          }
        } catch (e) {
          // Тоже молча пропускаем
          //print('Error loading $level words for $categoryName: ${e.toString().substring(0, math.min(50, e.toString().length))}...');
        }
      }
      
      return Category(
        name: categoryName,
        words: words,
        isEditable: false, // Встроенные категории не редактируемые
      );
    } catch (e) {
      print('Error in _loadCategoryWordsDirectly for $categoryName: $e');
      return Category(
        name: categoryName,
        words: [],
        isEditable: false,
      );
    }
  }
  
  /// Загружает пользовательские категории из SharedPreferences
  static Future<List<Category>> _loadCustomCategories() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Получаем список имен пользовательских категорий
      final categoryNamesJson = prefs.getString(CUSTOM_CATEGORIES_KEY);
      if (categoryNamesJson == null) {
        return [];
      }
      
      final List<dynamic> categoryNames = json.decode(categoryNamesJson);
      final List<Category> categories = [];
      
      // Загружаем слова для каждой категории
      for (String categoryName in categoryNames) {
        final wordsJson = prefs.getString('$CUSTOM_WORDS_PREFIX$categoryName');
        if (wordsJson == null) continue;
        
        try {
          final List<dynamic> wordsData = json.decode(wordsJson);
          final Category category = Category(name: categoryName);
          
          for (var wordData in wordsData) {
            category.addWord(Word.fromJson(wordData));
          }
          
          if (category.words.isNotEmpty) {
            categories.add(category);
            print('Loaded custom category $categoryName with ${category.words.length} words');
          }
        } catch (e) {
          print('Error decoding words for category $categoryName: $e');
        }
      }
      
      return categories;
    } catch (e) {
      print('Error loading custom categories: $e');
      return [];
    }
  }
  
  /// Загружает глаголы из локального файла
  static Future<List<Verb>> loadVerbsFromLocalFile() async {
    try {
      final file = await _getLocalFile('verbs_local.txt');
      if (!await file.exists()) {
        print('Local verbs file does not exist: ${file.path}');
        return [];
      }
      
      final content = await file.readAsString();
      List<Verb> verbs = parseVerbsFromFileFormat(content);
      
      // Проверяем на дубликаты
      int originalCount = verbs.length;
      verbs = removeDuplicateVerbs(verbs);
      
      if (verbs.length < originalCount) {
        print('Удалено ${originalCount - verbs.length} дубликатов из локального файла');
        // Сохраняем файл без дубликатов
        await saveVerbsToLocalFile(verbs);
      }
      
      print('Loaded ${verbs.length} verbs from local file: ${file.path}');
      return verbs;
    } catch (e) {
      print('Error loading verbs from local file: $e');
      return [];
    }
  }
  
  /// Загружает неправильные глаголы из встроенного файла
  static Future<List<Verb>> loadVerbs() async {
    try {
      // Сначала пробуем загрузить из локальной файловой системы
      try {
        final localFile = await _getLocalFile('verbs_local.txt');
        if (await localFile.exists()) {
          final content = await localFile.readAsString();
          if (content.trim().isNotEmpty) {
            final verbs = _parseVerbsFromContent(content);
            print('Загружено ${verbs.length} глаголов из локального файла');
            return verbs;
          }
        }
      } catch (e) {
        print('Ошибка при загрузке глаголов из локального файла: $e');
      }
      
      // Если не удалось, загружаем из ассетов
      try {
        final content = await rootBundle.loadString('assets/$VERBS_FILE');
        if (content.trim().isNotEmpty) {
          final verbs = _parseVerbsFromContent(content);
          print('Загружено ${verbs.length} глаголов из assets/$VERBS_FILE');
          return verbs;
        } else {
          print('Файл глаголов в assets/$VERBS_FILE пуст');
          return [];
        }
      } catch (e) {
        print('Ошибка при загрузке глаголов из assets/$VERBS_FILE: $e');
        return [];
      }
    } catch (e) {
      print('Ошибка при загрузке глаголов: $e');
      return [];
    }
  }
  
  /// Парсит глаголы из содержимого файла
  static List<Verb> _parseVerbsFromContent(String content) {
    final List<Verb> verbs = [];
    final lines = LineSplitter.split(content);
    
    for (var line in lines) {
      if (line.trim().isEmpty) continue;
      
      try {
        final parts = line.split(' - ');
        if (parts.length >= 7) {
          final verb = Verb(
            base: parts[0].trim(),
            baseTranscription: parts[1].trim(),
            pastSimple: parts[2].trim(),
            pastSimpleTranscription: parts[3].trim(),
            pastParticiple: parts[4].trim(),
            pastParticipleTranscription: parts[5].trim(),
            translation: parts[6].trim(),
            isLearned: parts.length > 7 ? parts[7].trim() == '1' || parts[7].trim().toLowerCase() == 'true' : false,
            isBlocked: parts.length > 8 ? parts[8].trim() == '1' || parts[8].trim().toLowerCase() == 'true' : false,
            repetitions: parts.length > 9 ? int.tryParse(parts[9].trim()) ?? 0 : 0,
          );
          verbs.add(verb);
        } else {
          print('Неверный формат строки глагола, ожидалось минимум 7 частей, получено ${parts.length}: ${line.substring(0, math.min(50, line.length))}...');
        }
      } catch (e) {
        print('Ошибка при парсинге строки с глаголом: $e');
      }
    }
    
    return verbs;
  }
  
  /// Создает локальную директорию для категории
  static Future<bool> createCategoryDirectory(String categoryName) async {
    try {
      final path = await _getLocalPath();
      
      // Очищаем имя директории от недопустимых символов,
      // но сохраняем кириллицу и другие специальные символы
      final String safeDirName = categoryName
          .replaceAll(' ', '_')
          .replaceAll('/', '_')
          .replaceAll('\\', '_')
          .replaceAll(':', '_')
          .replaceAll('*', '_')
          .replaceAll('?', '_')
          .replaceAll('"', '_')
          .replaceAll('<', '_')
          .replaceAll('>', '_')
          .replaceAll('|', '_');
      
      final Directory dir = Directory('$path/categories/$safeDirName');
      
      if (!(await dir.exists())) {
        await dir.create(recursive: true);
        print('Created directory for category: $categoryName at path: ${dir.path}');
        
        // Создаем пустой файл категории
        final File categoryFile = File('${dir.path}/A2.txt');
        if (!(await categoryFile.exists())) {
          await categoryFile.writeAsString('');
          print('Created empty A2.txt file for category: $categoryName');
        }
        
        // Создаем файл локальной категории с поддержкой UTF-8
        final String categoriesFile = '$path/categories_local.txt';
        final File file = File(categoriesFile);
        
        List<String> currentCategories = [];
        if (await file.exists()) {
          // Читаем с явным указанием кодировки UTF-8
          final content = await file.readAsString(encoding: utf8);
          currentCategories = LineSplitter.split(content)
            .where((line) => line.trim().isNotEmpty)
            .toList();
        }
        
        if (!currentCategories.contains(categoryName)) {
          currentCategories.add(categoryName);
          // Записываем с явным указанием кодировки UTF-8
          await file.writeAsString(currentCategories.join('\n'), encoding: utf8);
          print('Added $categoryName to categories_local.txt');
        }
      }
      return true;
    } catch (e) {
      print('Error creating category directory: $e');
      return false;
    }
  }
  
  /// Удаляет локальную директорию категории
  static Future<bool> deleteCategoryDirectory(String categoryName) async {
    try {
      final path = await _getLocalPath();
      
      // Очищаем имя директории от недопустимых символов,
      // но сохраняем кириллицу и другие специальные символы
      final String safeDirName = categoryName
          .replaceAll(' ', '_')
          .replaceAll('/', '_')
          .replaceAll('\\', '_')
          .replaceAll(':', '_')
          .replaceAll('*', '_')
          .replaceAll('?', '_')
          .replaceAll('"', '_')
          .replaceAll('<', '_')
          .replaceAll('>', '_')
          .replaceAll('|', '_');
      
      final Directory dir = Directory('$path/categories/$safeDirName');
      
      if (await dir.exists()) {
        await dir.delete(recursive: true);
        print('Deleted directory for category: $categoryName at path: ${dir.path}');
      }
      
      // Удаляем категорию из локального файла с поддержкой UTF-8
      final String categoriesFile = '$path/categories_local.txt';
      final File file = File(categoriesFile);
      
      if (await file.exists()) {
        // Читаем с явным указанием кодировки UTF-8
        final content = await file.readAsString(encoding: utf8);
        final currentCategories = LineSplitter.split(content)
          .where((line) => line.trim().isNotEmpty && line.trim() != categoryName)
          .toList();
        
        // Записываем с явным указанием кодировки UTF-8
        await file.writeAsString(currentCategories.join('\n'), encoding: utf8);
        print('Removed $categoryName from categories_local.txt');
      }
      
      return true;
    } catch (e) {
      print('Error deleting category directory: $e');
      return false;
    }
  }
  
  /// Экспортирует слово в строковый формат для сохранения в файле
  static String _wordToFileString(Word word) {
    final isLearnedStr = word.isLearned ? "1" : "0";
    final isBlockedStr = word.isBlocked ? "1" : "0";
    final repetitionsStr = word.repetitions.toString();
    
    return "${word.english} - ${word.transcription} - ${word.russian} - $isLearnedStr - $isBlockedStr - $repetitionsStr";
  }
  
  /// Сохраняет слова категории в файлы уровней
  static Future<bool> _saveCategoryWordsToFiles(Category category) async {
    try {
      final path = await _getLocalPath();
      
      // Очищаем имя директории от недопустимых символов
      final String safeDirName = category.name
          .replaceAll(' ', '_')
          .replaceAll('/', '_')
          .replaceAll('\\', '_')
          .replaceAll(':', '_')
          .replaceAll('*', '_')
          .replaceAll('?', '_')
          .replaceAll('"', '_')
          .replaceAll('<', '_')
          .replaceAll('>', '_')
          .replaceAll('|', '_');
      
      final Directory dir = Directory('$path/categories/$safeDirName');
      
      if (!(await dir.exists())) {
        await dir.create(recursive: true);
      }
      
      // Группируем слова по уровням
      final Map<String, List<Word>> wordsByLevel = {};
      
      for (var word in category.words) {
        String fileLevel;
        
        // Преобразуем отображаемый уровень в имя файла
        switch (word.level) {
          case 'B1+':
            fileLevel = 'B1plus';
            break;
          default:
            fileLevel = word.level; // A2, B1
            break;
        }
        
        if (!wordsByLevel.containsKey(fileLevel)) {
          wordsByLevel[fileLevel] = [];
        }
        
        wordsByLevel[fileLevel]!.add(word);
      }
      
      // Сохраняем слова в соответствующие файлы уровней
      for (var entry in wordsByLevel.entries) {
        final levelFile = File('${dir.path}/${entry.key}.txt');
        
        // Преобразуем слова в строки
        final List<String> wordStrings = entry.value.map((word) => _wordToFileString(word)).toList();
        
        // Записываем в файл с использованием UTF-8
        await levelFile.writeAsString(wordStrings.join('\n'), encoding: utf8);
        print('Saved ${entry.value.length} words to ${levelFile.path}');
      }
      
      return true;
    } catch (e) {
      print('Error saving category words to files: $e');
      return false;
    }
  }
  
  /// Сохраняет новую категорию в SharedPreferences и файловую систему
  static Future<bool> saveCategory(Category category) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Получаем текущий список категорий
      List<String> categoryNames = [];
      final categoryNamesJson = prefs.getString(CUSTOM_CATEGORIES_KEY);
      
      if (categoryNamesJson != null) {
        categoryNames = List<String>.from(json.decode(categoryNamesJson));
      }
      
      // Проверяем, существует ли уже такая категория
      if (!categoryNames.contains(category.name)) {
        categoryNames.add(category.name);
        await prefs.setString(CUSTOM_CATEGORIES_KEY, json.encode(categoryNames));
      }
      
      // Сохраняем слова категории в SharedPreferences
      final wordsList = category.words.map((word) => word.toJson()).toList();
      await prefs.setString('$CUSTOM_WORDS_PREFIX${category.name}', json.encode(wordsList));
      
      // Создаем директорию категории в файловой системе
      await createCategoryDirectory(category.name);
      
      // Сохраняем слова в файлы соответствующих уровней
      await _saveCategoryWordsToFiles(category);
      
      print('Saved category ${category.name} with ${category.words.length} words');
      return true;
    } catch (e) {
      print('Error saving category: $e');
      return false;
    }
  }
  
  /// Удаляет категорию из SharedPreferences и файловой системы
  static Future<bool> deleteCategory(String categoryName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Получаем текущий список категорий
      final categoryNamesJson = prefs.getString(CUSTOM_CATEGORIES_KEY);
      if (categoryNamesJson == null) return false;
      
      List<String> categoryNames = List<String>.from(json.decode(categoryNamesJson));
      
      // Удаляем категорию из списка
      if (categoryNames.contains(categoryName)) {
        categoryNames.remove(categoryName);
        await prefs.setString(CUSTOM_CATEGORIES_KEY, json.encode(categoryNames));
        
        // Удаляем слова категории
        await prefs.remove('$CUSTOM_WORDS_PREFIX$categoryName');
        
        // Удаляем директорию категории
        await deleteCategoryDirectory(categoryName);
        
        print('Deleted category $categoryName');
        return true;
      }
      
      return false;
    } catch (e) {
      print('Error deleting category: $e');
      return false;
    }
  }
  
  /// Обновляет слова в категории
  static Future<bool> updateCategoryWords(String categoryName, List<Word> words) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Проверяем, существует ли категория в списке пользовательских
      final categoryNamesJson = prefs.getString(CUSTOM_CATEGORIES_KEY);
      if (categoryNamesJson == null) return false;
      
      List<String> categoryNames = List<String>.from(json.decode(categoryNamesJson));
      
      if (!categoryNames.contains(categoryName)) {
        return false; // Не обновляем встроенные категории
      }
      
      // Сохраняем обновленные слова в SharedPreferences
      final wordsList = words.map((word) => word.toJson()).toList();
      await prefs.setString('$CUSTOM_WORDS_PREFIX$categoryName', json.encode(wordsList));
      
      // Сохраняем слова в файлы
      await _saveCategoryWordsToFiles(Category(name: categoryName, words: words));
      
      print('Updated category $categoryName with ${words.length} words');
      return true;
    } catch (e) {
      print('Error updating category words: $e');
      return false;
    }
  }
  
  /// Сохраняет список глаголов в SharedPreferences
  static Future<bool> saveVerbs(List<Verb> verbs) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Удаляем дубликаты перед сохранением
      List<Verb> uniqueVerbs = removeDuplicateVerbs(verbs);
      
      // Если были найдены и удалены дубликаты
      if (uniqueVerbs.length < verbs.length) {
        print('Удалено ${verbs.length - uniqueVerbs.length} дубликатов глаголов перед сохранением');
        // Обновляем исходный список
        verbs.clear();
        verbs.addAll(uniqueVerbs);
      }
      
      // Создаем резервную копию перед сохранением
      final oldVerbsJson = prefs.getString('custom_verbs');
      if (oldVerbsJson != null) {
        await prefs.setString('custom_verbs_backup', oldVerbsJson);
        print('Created backup of verbs data');
      }
      
      // Сохраняем обновленные глаголы в SharedPreferences
      final verbsList = verbs.map((verb) => verb.toJson()).toList();
      await prefs.setString('custom_verbs', json.encode(verbsList));
      print('Saved ${verbs.length} verbs to SharedPreferences');
      
      // Также сохраняем глаголы в локальной файловой системе
      try {
        await saveVerbsToLocalFile(verbs);
      } catch (e) {
        print('Error saving verbs to local file: $e');
      }
      
      return true;
    } catch (e) {
      print('Error saving verbs: $e');
      return false;
    }
  }
  
  /// Удаляет дубликаты глаголов из списка, сохраняя только один экземпляр для каждой базовой формы
  static List<Verb> removeDuplicateVerbs(List<Verb> verbs) {
    // Создаем карту для хранения уникальных глаголов по базовой форме
    final Map<String, Verb> uniqueVerbs = {};
    
    for (var verb in verbs) {
      String key = verb.base.toLowerCase().trim();
      
      // Если глагол с такой базовой формой уже существует
      if (uniqueVerbs.containsKey(key)) {
        // Объединяем свойства - сохраняем максимальное значение статусов
        Verb existingVerb = uniqueVerbs[key]!;
        
        // Если хотя бы в одном случае глагол отмечен как изученный
        if (verb.isLearned) {
          existingVerb.isLearned = true;
        }
        
        // Если хотя бы в одном случае глагол отмечен как заблокированный
        if (verb.isBlocked) {
          existingVerb.isBlocked = true;
        }
        
        // Сохраняем максимальное количество повторений
        existingVerb.repetitions = math.max(existingVerb.repetitions, verb.repetitions);
        
        print('Объединены свойства дубликата глагола: ${verb.base}');
      } else {
        // Добавляем глагол в карту уникальных глаголов
        uniqueVerbs[key] = verb;
      }
    }
    
    // Возвращаем список уникальных глаголов
    return uniqueVerbs.values.toList();
  }
  
  /// Загружает список пользовательских глаголов из SharedPreferences
  static Future<List<Verb>> loadCustomVerbs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Получаем JSON со списком глаголов
      final verbsJson = prefs.getString('custom_verbs');
      if (verbsJson == null) {
        return [];
      }
      
      final List<dynamic> verbsData = json.decode(verbsJson);
      List<Verb> verbs = [];
      
      for (var verbData in verbsData) {
        verbs.add(Verb.fromJson(verbData));
      }
      
      // Проверяем наличие дубликатов при загрузке
      int originalCount = verbs.length;
      verbs = removeDuplicateVerbs(verbs);
      
      if (verbs.length < originalCount) {
        print('Удалено ${originalCount - verbs.length} дубликатов при загрузке пользовательских глаголов');
        
        // Если были найдены дубликаты, сохраняем обновленный список
        await saveVerbs(verbs);
      }
      
      print('Loaded ${verbs.length} custom verbs');
      return verbs;
    } catch (e) {
      print('Error loading custom verbs: $e');
      
      // Пробуем восстановить из резервной копии
      try {
        return await restoreVerbsFromBackup();
      } catch (backupError) {
        print('Failed to restore from backup: $backupError');
        return [];
      }
    }
  }
  
  /// Восстанавливает глаголы из резервной копии
  static Future<List<Verb>> restoreVerbsFromBackup() async {
    final prefs = await SharedPreferences.getInstance();
    
    final backupJson = prefs.getString('custom_verbs_backup');
    if (backupJson == null) {
      print('No backup found for verbs');
      return [];
    }
    
    try {
      final List<dynamic> verbsData = json.decode(backupJson);
      final List<Verb> verbs = [];
      
      for (var verbData in verbsData) {
        verbs.add(Verb.fromJson(verbData));
      }
      
      print('Restored ${verbs.length} verbs from backup');
      
      // Восстанавливаем основные данные из бэкапа
      await prefs.setString('custom_verbs', backupJson);
      print('Restored main verbs data from backup');
      
      return verbs;
    } catch (e) {
      print('Error restoring verbs from backup: $e');
      return [];
    }
  }
  
  /// Экспортирует глаголы в формат, совместимый с текстовым файлом
  static String exportVerbsToFileFormat(List<Verb> verbs) {
    StringBuffer buffer = StringBuffer();
    
    for (var verb in verbs) {
      final isLearnedStr = verb.isLearned ? "1" : "0";
      final isBlockedStr = verb.isBlocked ? "1" : "0";
      final repetitionsStr = verb.repetitions.toString();
      
      buffer.writeln('${verb.base} - ${verb.baseTranscription} - ${verb.pastSimple} - ${verb.pastSimpleTranscription} - ${verb.pastParticiple} - ${verb.pastParticipleTranscription} - ${verb.translation} - $isLearnedStr - $isBlockedStr - $repetitionsStr');
    }
    
    return buffer.toString();
  }
  
  /// Парсит глаголы из форматированного текста файла
  static List<Verb> parseVerbsFromFileFormat(String fileContent) {
    final lines = LineSplitter.split(fileContent)
        .where((line) => line.trim().isNotEmpty);
    
    final List<Verb> verbs = [];
    int lineNumber = 0;
    
    for (var line in lines) {
      lineNumber++;
      try {
        verbs.add(Verb.fromString(line));
      } catch (e) {
        print('Error parsing verb at line $lineNumber: "$line"');
        print('Error details: $e');
      }
    }
    
    return verbs;
  }
  
  /// Парсит слова из содержимого файла и добавляет их в список
  static void _parseWords(String content, String? level, List<Word> words) {
    final lines = LineSplitter.split(content).where((line) => line.trim().isNotEmpty);
    
    // Карта преобразования уровней из имен файлов в отображаемые значения
    final levelMap = {
      'A2': 'A2',
      'B1': 'B1',
      'B1plus': 'B1+'
    };
    
    // Определяем отображаемый уровень
    String displayLevel = levelMap[level] ?? 'A2'; // По умолчанию A2, если не указано
    
    for (var line in lines) {
      try {
        // Формат: english - [transcription] - russian - isLearned - isBlocked - repetitions
        final parts = line.split(' - ');
        
        if (parts.length >= 3) {
          final english = parts[0].trim();
          final transcription = parts[1].trim();
          final russian = parts[2].trim();
          
          // Проверяем наличие дополнительных параметров
          bool isLearned = false;
          bool isBlocked = false;
          int repetitions = 0;
          
          if (parts.length > 3) {
            isLearned = parts[3].trim() == '1' || parts[3].trim().toLowerCase() == 'true';
            
            if (parts.length > 4) {
              isBlocked = parts[4].trim() == '1' || parts[4].trim().toLowerCase() == 'true';
              
              if (parts.length > 5) {
                repetitions = int.tryParse(parts[5].trim()) ?? 0;
              }
            }
          }
          
          final word = Word(
            english: english,
            russian: russian,
            level: displayLevel,
            transcription: transcription,
            isLearned: isLearned,
            isBlocked: isBlocked,
            repetitions: repetitions,
          );
          
          // Добавляем слово, если его еще нет в списке
          if (!words.any((w) => w.english == word.english)) {
            words.add(word);
          }
        }
      } catch (e) {
        print('Error parsing word from line: $line, error: $e');
      }
    }
  }
  
  /// Возвращает путь к локальной директории
  static Future<String> _getLocalPath() async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }
  
  /// Получает ссылку на файл в локальной файловой системе
  static Future<File> _getLocalFile(String filename) async {
    final path = await _getLocalPath();
    return File('$path/$filename');
  }
  
  /// Создает директорию в локальной файловой системе
  static Future<Directory> _createLocalDirectory(String dirPath) async {
    final path = await _getLocalPath();
    final dir = Directory('$path/$dirPath');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }
  
  /// Сохраняет список глаголов в локальной файловой системе
  static Future<bool> saveVerbsToLocalFile(List<Verb> verbs) async {
    try {
      final file = await _getLocalFile('verbs_local.txt');
      final content = exportVerbsToFileFormat(verbs);
      await file.writeAsString(content);
      print('Saved ${verbs.length} verbs to local file: ${file.path}');
      return true;
    } catch (e) {
      print('Error saving verbs to local file: $e');
      return false;
    }
  }
  
  /// Копирует ассеты в локальную файловую систему
  static Future<bool> copyAssetsToLocalFile() async {
    try {
      print('Копирование ассетов в локальную файловую систему');
      
      // 1. Сначала пробуем скопировать файл categories.txt
      try {
        final categoriesContent = await rootBundle.loadString('assets/$CATEGORIES_FILE');
        final file = File('${await _getLocalPath()}/categories_local.txt');
        
        // Проверяем существование файла
        if (!await file.exists()) {
          await file.writeAsString(categoriesContent);
          print('Скопирован файл categories.txt в categories_local.txt');
        } else {
          print('Файл categories_local.txt уже существует, пропускаем копирование');
        }
      } catch (e) {
        print('Не удалось скопировать файл categories.txt: $e');
      }
      
      // 2. Копируем Unit категории
      for (int i = 1; i <= 12; i++) {
        final unitName = 'Unit $i';
        final safeUnitName = unitName.replaceAll(' ', '_');
        
        try {
          // Создаем директорию для Unit
          final unitDir = await _createLocalDirectory('categories/$safeUnitName');
          
          // Копируем файлы для каждого уровня
          for (var level in ['A2', 'B1', 'B1plus']) {
            try {
              final assetPath = 'assets/$CATEGORIES_DIR$unitName/$level.txt';
              final content = await rootBundle.loadString(assetPath);
              
              if (content.trim().isNotEmpty) {
                final file = File('${unitDir.path}/$level.txt');
                // Проверяем существование файла
                if (!await file.exists()) {
                  await file.writeAsString(content);
                  print('Скопирован файл $assetPath');
                }
              } else {
                print('Файл $assetPath пуст, пропускаем');
              }
            } catch (e) {
              // Молча пропускаем, если файла для уровня нет
            }
          }
        } catch (e) {
          print('Ошибка при копировании $unitName: $e');
        }
      }
      
      // 3. Загружаем существующие пользовательские категории и создаем для них директории
      final prefs = await SharedPreferences.getInstance();
      final categoryNamesJson = prefs.getString(CUSTOM_CATEGORIES_KEY);
      if (categoryNamesJson != null) {
        final categoryNames = List<String>.from(json.decode(categoryNamesJson));
        for (var categoryName in categoryNames) {
          await createCategoryDirectory(categoryName);
        }
      }
      
      return true;
    } catch (e) {
      print('Ошибка при копировании ассетов: $e');
      return false;
    }
  }
  
  /// Тестовый метод для проверки корректности загрузки данных
  static Future<void> testDataLoading() async {
    try {
      print('=== НАЧАЛО ТЕСТИРОВАНИЯ ЗАГРУЗКИ ДАННЫХ ===');
      
      // Проверяем доступ к файлу categories.txt
      try {
        final categoriesContent = await rootBundle.loadString('assets/$CATEGORIES_FILE');
        print('Файл categories.txt успешно загружен: ${categoriesContent.split('\n').length} строк');
      } catch (e) {
        print('ОШИБКА загрузки файла categories.txt: $e');
      }
      
      // Проверяем доступность директорий с категориями
      for (int i = 1; i <= 12; i++) {
        final unitName = 'Unit $i';
        try {
          final fileContent = await rootBundle.loadString('assets/$CATEGORIES_DIR$unitName/A2.txt');
          print('Файл assets/$CATEGORIES_DIR$unitName/A2.txt успешно загружен: ${fileContent.split('\n').length} строк');
        } catch (e) {
          print('ОШИБКА загрузки файла assets/$CATEGORIES_DIR$unitName/A2.txt: $e');
        }
        
        // Проверяем B1plus файл для Unit 1
        if (i == 1) {
          try {
            final fileContent = await rootBundle.loadString('assets/$CATEGORIES_DIR$unitName/B1plus.txt');
            print('Файл assets/$CATEGORIES_DIR$unitName/B1plus.txt успешно загружен: ${fileContent.split('\n').length} строк');
          } catch (e) {
            print('ОШИБКА загрузки файла assets/$CATEGORIES_DIR$unitName/B1plus.txt: $e');
          }
        }
      }
      
      // Тестируем загрузку категорий
      print('\nЗагрузка категорий...');
      try {
        final categories = await loadCategories();
        print('Загружено ${categories.length} категорий');
        
        // Выводим информацию о каждой категории
        for (var category in categories) {
          print('Категория: ${category.name} - ${category.words.length} слов');
          
          // Анализируем уровни слов в категории
          final levelCounts = <String, int>{};
          for (var word in category.words) {
            levelCounts[word.level] = (levelCounts[word.level] ?? 0) + 1;
          }
          print('  Распределение по уровням: $levelCounts');
          
          // Опционально: выводим первые 3 слова в категории для проверки
          if (category.words.isNotEmpty) {
            print('  Примеры слов:');
            for (int i = 0; i < math.min(3, category.words.length); i++) {
              print('    ${i+1}. ${category.words[i].english} - ${category.words[i].transcription} - ${category.words[i].russian} (${category.words[i].level})');
            }
          }
        }
      } catch (e) {
        print('ОШИБКА при загрузке категорий: $e');
      }
      
      // Тестируем загрузку глаголов
      print('\nЗагрузка глаголов...');
      try {
        final verbsContent = await rootBundle.loadString('assets/$VERBS_FILE');
        print('Файл verbs.txt успешно загружен: ${verbsContent.split('\n').length} строк');
      } catch (e) {
        print('ОШИБКА загрузки файла verbs.txt: $e');
      }
      
      try {
        final verbs = await loadVerbs();
        print('Загружено ${verbs.length} глаголов');
        
        // Выводим информацию о первых 3 глаголах для проверки
        if (verbs.isNotEmpty) {
          print('  Примеры глаголов:');
          for (int i = 0; i < math.min(3, verbs.length); i++) {
            print('    ${i+1}. ${verbs[i].base} - ${verbs[i].pastSimple} - ${verbs[i].pastParticiple} - ${verbs[i].translation}');
          }
        }
      } catch (e) {
        print('ОШИБКА при загрузке глаголов: $e');
      }
      
      print('=== ТЕСТИРОВАНИЕ ЗАГРУЗКИ ДАННЫХ ЗАВЕРШЕНО ===');
    } catch (e) {
      print('Ошибка при тестировании загрузки данных: $e');
    }
  }
  
  /// Возвращает директорию для локальных файлов
  static Future<Directory> _getLocalDirectory() async {
    final path = await _getLocalPath();
    return Directory(path);
  }

  /// Проверяет, является ли имя категории допустимым
  static bool _isValidCategoryName(String categoryName) {
    // Исключаем служебные директории и файлы
    return categoryName.isNotEmpty && 
           !categoryName.startsWith('.') && 
           !categoryName.contains('categories_local') &&
           !categoryName.contains('images');
  }
} 