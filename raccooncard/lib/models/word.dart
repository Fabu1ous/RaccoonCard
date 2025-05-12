enum WordStatus {
  notLearned,
  learned,
  blocked,
}

class Word {
  final String english;
  final String russian;
  final String level;
  final String transcription;
  bool isLearned;
  bool isBlocked;
  int repetitions;

  Word({
    required this.english,
    required this.russian,
    required this.level,
    this.transcription = '',
    this.isLearned = false,
    this.isBlocked = false,
    this.repetitions = 0,
  });

  // Метод для создания копии слова с обновлёнными значениями
  Word copyWith({
    String? english,
    String? russian,
    String? level,
    String? transcription,
    bool? isLearned,
    bool? isBlocked,
    int? repetitions,
  }) {
    return Word(
      english: english ?? this.english,
      russian: russian ?? this.russian,
      level: level ?? this.level,
      transcription: transcription ?? this.transcription,
      isLearned: isLearned ?? this.isLearned,
      isBlocked: isBlocked ?? this.isBlocked,
      repetitions: repetitions ?? this.repetitions,
    );
  }

  // Разделяем перевод на список
  List<String> get translations =>
      russian.split(',').map((t) => t.trim()).toList();

  @override
  String toString() {
    return 'Word(english: $english, russian: $russian, transcription: $transcription, translations: ${translations.join(", ")}, level: $level, isLearned: $isLearned, isBlocked: $isBlocked, repetitions: $repetitions)';
  }

  Map<String, dynamic> toJson() {
    return {
      'english': english,
      'russian': russian,
      'level': level,
      'transcription': transcription,
      'isLearned': isLearned,
      'isBlocked': isBlocked,
      'repetitions': repetitions,
    };
  }

  factory Word.fromJson(Map<String, dynamic> json) {
    return Word(
      english: json['english'] as String,
      russian: json['russian'] as String,
      level: json['level'] as String,
      transcription: json['transcription'] as String? ?? '',
      isLearned: json['isLearned'] as bool? ?? false,
      isBlocked: json['isBlocked'] as bool? ?? false,
      repetitions: json['repetitions'] as int? ?? 0,
    );
  }
}
