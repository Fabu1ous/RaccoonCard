import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/verb.dart';
import '../theme/theme_provider.dart';
import '../widgets/transcription_keyboard.dart';

class EditVerbScreen extends StatefulWidget {
  final Verb initialVerb;
  final Function(Verb) onVerbUpdated;

  const EditVerbScreen({
    Key? key,
    required this.initialVerb,
    required this.onVerbUpdated,
  }) : super(key: key);

  @override
  _EditVerbScreenState createState() => _EditVerbScreenState();
}

class _EditVerbScreenState extends State<EditVerbScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _baseController;
  late TextEditingController _baseTransController;
  late TextEditingController _pastSimpleController;
  late TextEditingController _pastSimpleTransController;
  late TextEditingController _pastParticipleController;
  late TextEditingController _pastParticipleTransController;
  late TextEditingController _translationController;
  bool _isLearned = false;
  bool _isBlocked = false;

  @override
  void initState() {
    super.initState();
    _baseController =
        TextEditingController(text: widget.initialVerb.base);
    _baseTransController =
        TextEditingController(text: widget.initialVerb.baseTranscription);
    _pastSimpleController =
        TextEditingController(text: widget.initialVerb.pastSimple);
    _pastSimpleTransController =
        TextEditingController(text: widget.initialVerb.pastSimpleTranscription);
    _pastParticipleController =
        TextEditingController(text: widget.initialVerb.pastParticiple);
    _pastParticipleTransController = TextEditingController(
        text: widget.initialVerb.pastParticipleTranscription);
    _translationController =
        TextEditingController(text: widget.initialVerb.translation);
    _isLearned = widget.initialVerb.isLearned;
    _isBlocked = widget.initialVerb.isBlocked;
  }

  @override
  void dispose() {
    _baseController.dispose();
    _baseTransController.dispose();
    _pastSimpleController.dispose();
    _pastSimpleTransController.dispose();
    _pastParticipleController.dispose();
    _pastParticipleTransController.dispose();
    _translationController.dispose();
    super.dispose();
  }

  void _updateVerb() {
    if (_formKey.currentState!.validate()) {
      final updatedVerb = Verb(
        base: _baseController.text.trim(),
        baseTranscription: _baseTransController.text.trim(),
        pastSimple: _pastSimpleController.text.trim(),
        pastSimpleTranscription: _pastSimpleTransController.text.trim(),
        pastParticiple: _pastParticipleController.text.trim(),
        pastParticipleTranscription: _pastParticipleTransController.text.trim(),
        translation: _translationController.text.trim(),
        isLearned: _isLearned,
        isBlocked: _isBlocked,
        repetitions: widget.initialVerb.repetitions,
      );

      widget.onVerbUpdated(updatedVerb);
      Navigator.pop(context);
      _showSnackBar('Глагол успешно обновлен');
    }
  }

  void _showTranscriptionKeyboard(TextEditingController controller) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: TranscriptionKeyboard(
          controller: controller,
          onClose: () => Navigator.pop(context),
        ),
      ),
    );
  }

  Widget _buildVerbFormField({
    required String label,
    required TextEditingController controller,
    required TextEditingController transcriptionController,
    required ThemeProvider themeProvider,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: themeProvider.themeColor,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: controller,
                cursorColor: themeProvider.themeColor,
                decoration: InputDecoration(
                  labelText: 'Слово',
                  labelStyle: TextStyle(color: themeProvider.themeColor),
                  filled: true,
                  fillColor: themeProvider.themeBackgroundColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding:
                      EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                ),
                style: TextStyle(
                  fontSize: 16,
                  color: themeProvider.themeColor,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Пожалуйста, введите форму глагола';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                controller: transcriptionController,
                cursorColor: themeProvider.themeColor,
                decoration: InputDecoration(
                  labelText: 'Транскрипция',
                  labelStyle: TextStyle(color: themeProvider.themeColor),
                  filled: true,
                  fillColor: themeProvider.themeBackgroundColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding:
                      EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                  suffixIcon: IconButton(
                    icon: Icon(Icons.keyboard,
                        color: themeProvider.themeColor),
                    onPressed: () =>
                        _showTranscriptionKeyboard(transcriptionController),
                  ),
                ),
                style: TextStyle(
                  fontSize: 16,
                  color: themeProvider.themeColor,
                ),
                validator: (value) {
                  // Transcription is optional
                  return null;
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }

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
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      backgroundColor: themeProvider.scaffoldBackgroundColor,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: Text(
          'Редактировать глагол',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor:
            themeProvider.isDarkTheme ? Colors.grey[800] : Colors.brown[400],
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _translationController,
                  decoration: InputDecoration(
                    labelText: 'Перевод',
                    labelStyle: TextStyle(color: themeProvider.themeColor),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: themeProvider.themeColor),
                    ),
                  ),
                  style: TextStyle(color: themeProvider.themeColor),
                  cursorColor: themeProvider.themeColor,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Пожалуйста, введите перевод';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16),
                _buildVerbFormField(
                  label: 'Инфинитив',
                  controller: _baseController,
                  transcriptionController: _baseTransController,
                  themeProvider: themeProvider,
                ),
                _buildVerbFormField(
                  label: 'Прошедшее время',
                  controller: _pastSimpleController,
                  transcriptionController: _pastSimpleTransController,
                  themeProvider: themeProvider,
                ),
                _buildVerbFormField(
                  label: 'Причастие прошедшего времени',
                  controller: _pastParticipleController,
                  transcriptionController: _pastParticipleTransController,
                  themeProvider: themeProvider,
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: CheckboxListTile(
                        title: Text(
                          'Изучено',
                          style: TextStyle(color: themeProvider.themeColor),
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
                          style: TextStyle(color: themeProvider.themeColor),
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
                SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _updateVerb,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    child: Text(
                      'Сохранить изменения',
                      style: TextStyle(fontSize: 18, color: Colors.white),
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: themeProvider.isDarkTheme
                        ? Colors.grey[700]
                        : Colors.brown[400],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
