import 'dart:math' as math;

class Verb {
  final String base;
  final String baseTranscription;
  final String pastSimple;
  final String pastSimpleTranscription;
  final String pastParticiple;
  final String pastParticipleTranscription;
  final String translation;
  bool isLearned;
  bool isBlocked;
  int repetitions;

  Verb({
    required this.base,
    required this.baseTranscription,
    required this.pastSimple,
    required this.pastSimpleTranscription,
    required this.pastParticiple,
    required this.pastParticipleTranscription,
    required this.translation,
    this.isLearned = false,
    this.isBlocked = false,
    this.repetitions = 0,
  });

  // Копирование объекта с возможностью обновления отдельных полей
  Verb copyWith({
    bool? isLearned,
    bool? isBlocked,
    int? repetitions,
  }) {
    return Verb(
      base: this.base,
      baseTranscription: this.baseTranscription,
      pastSimple: this.pastSimple,
      pastSimpleTranscription: this.pastSimpleTranscription,
      pastParticiple: this.pastParticiple,
      pastParticipleTranscription: this.pastParticipleTranscription,
      translation: this.translation,
      isLearned: isLearned ?? this.isLearned,
      isBlocked: isBlocked ?? this.isBlocked,
      repetitions: repetitions ?? this.repetitions,
    );
  }

  // Парсинг глагола из строки файла
  static Verb fromString(String line) {
    final parts = line.split(' - ');
    
    if (parts.length >= 7) {
      // Базовые поля глагола
      String base = parts[0].trim();
      String baseTranscription = parts[1].trim();
      String pastSimple = parts[2].trim();
      String pastSimpleTranscription = parts[3].trim();
      String pastParticiple = parts[4].trim();
      String pastParticipleTranscription = parts[5].trim();
      String translation = parts[6].trim();
      
      // Дополнительные поля состояния
      bool isLearned = false;
      bool isBlocked = false;
      int repetitions = 0;
      
      if (parts.length > 7) {
        String learnedStr = parts[7].trim();
        isLearned = learnedStr == '1' || learnedStr.toLowerCase() == 'true';
        
        if (parts.length > 8) {
          String blockedStr = parts[8].trim();
          isBlocked = blockedStr == '1' || blockedStr.toLowerCase() == 'true';
          
          if (parts.length > 9) {
            repetitions = int.tryParse(parts[9].trim()) ?? 0;
          }
        }
      }
      
      return Verb(
        base: base,
        baseTranscription: baseTranscription,
        pastSimple: pastSimple,
        pastSimpleTranscription: pastSimpleTranscription,
        pastParticiple: pastParticiple,
        pastParticipleTranscription: pastParticipleTranscription,
        translation: translation,
        isLearned: isLearned,
        isBlocked: isBlocked,
        repetitions: repetitions,
      );
    } else {
      throw Exception('Invalid verb format: ${parts.length} parts found, expected at least 7. Line: ${line.substring(0, math.min(50, line.length))}...');
    }
  }

  // Преобразование в JSON для сохранения
  Map<String, dynamic> toJson() {
    return {
      'base': base,
      'baseTranscription': baseTranscription,
      'pastSimple': pastSimple,
      'pastSimpleTranscription': pastSimpleTranscription,
      'pastParticiple': pastParticiple,
      'pastParticipleTranscription': pastParticipleTranscription,
      'translation': translation,
      'isLearned': isLearned,
      'isBlocked': isBlocked,
      'repetitions': repetitions,
    };
  }

  // Создание объекта из JSON
  factory Verb.fromJson(Map<String, dynamic> json) {
    return Verb(
      base: json['base'],
      baseTranscription: json['baseTranscription'],
      pastSimple: json['pastSimple'],
      pastSimpleTranscription: json['pastSimpleTranscription'],
      pastParticiple: json['pastParticiple'],
      pastParticipleTranscription: json['pastParticipleTranscription'],
      translation: json['translation'],
      isLearned: json['isLearned'] ?? false,
      isBlocked: json['isBlocked'] ?? false,
      repetitions: json['repetitions'] ?? 0,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Verb && other.base == base;
  }

  @override
  int get hashCode => base.hashCode;

  @override
  String toString() {
    return 'Verb(base: $base, translation: $translation, isLearned: $isLearned)';
  }
}
