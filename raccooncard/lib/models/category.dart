import 'word.dart';

class Category {
  final String name;
  final List<Word> words;
  final bool isEditable;

  Category({
    required this.name,
    List<Word>? words,
    this.isEditable = true,
  }) : words = words ?? [];

  // Метод для добавления нового слова
  void addWord(Word word) {
    if (!words.contains(word)) {
      words.add(word);
    }
  }

  // Метод для удаления слова
  void removeWord(Word word) {
    words.removeWhere((w) => w.english == word.english);
  }

  // Метод для обновления существующего слова
  void updateWord(Word oldWord, Word newWord) {
    final index = words.indexWhere((w) => w.english == oldWord.english);
    if (index != -1) {
      words[index] = newWord;
    }
  }

  // Метод для получения слова по его названию
  Word? getWordByTitle(String wordTitle) {
    return words.firstWhere((w) => w.english == wordTitle,
        orElse: () => null as Word);
  }

  // Метод для проверки наличия слова
  bool containsWord(Word word) {
    return words.any((w) => w.english == word.english);
  }

  // Переопределение метода toString для удобства отладки
  @override
  String toString() {
    return 'Category(name: $name, words: ${words.map((w) => w.english).toList()})';
  }

  // Метод для клонирования категории
  Category copyWith({
    String? name,
    List<Word>? words,
    bool? isEditable,
  }) {
    return Category(
      name: name ?? this.name,
      words: words ?? List<Word>.from(this.words),
      isEditable: isEditable ?? this.isEditable,
    );
  }
}
