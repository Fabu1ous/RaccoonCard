import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/verb.dart';
import '../theme/theme_provider.dart';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class Question {
  final Verb verb;
  final int formIndex;

  Question(this.verb, this.formIndex);

  String get correctAnswer {
    switch (formIndex) {
      case 0:
        return verb.base;
      case 1:
        return verb.pastSimple;
      case 2:
        return verb.pastParticiple;
      default:
        return '';
    }
  }

  String get formLabel {
    return '${formIndex + 1} форма';
  }
}

class VerbLearningScreen extends StatefulWidget {
  final List<Verb> verbs;
  final Function(List<Verb>) onVerbsUpdated;
  final int initialStage;
  final int initialVerbIndex;
  final int initialQuestionIndex;

  const VerbLearningScreen({
    Key? key,
    required this.verbs,
    required this.onVerbsUpdated,
    this.initialStage = 1,
    this.initialVerbIndex = 0,
    this.initialQuestionIndex = 0,
  }) : super(key: key);

  @override
  _VerbLearningScreenState createState() => _VerbLearningScreenState();
}

class _VerbLearningScreenState extends State<VerbLearningScreen>
    with SingleTickerProviderStateMixin {
  late List<Verb> _currentVerbs = [];
  late List<Question> _questions = [];
  int _currentQuestionIndex = 0;
  int _currentStage = 1;
  int _currentVerbIndex = 0;
  final TextEditingController _inputController = TextEditingController();
  final FocusNode _inputFocusNode = FocusNode();
  bool _isCorrect = false;
  bool _showResult = false;
  int _correctAnswers = 0;
  int _totalQuestions = 0;
  bool _showHint = false;
  bool _showError = false;
  bool _hasWrongAttempt = false;
  late PageController _pageController;
  bool _showTranslation = false;
  
  final TextEditingController _form1Controller = TextEditingController();
  
  final FocusNode _form1FocusNode = FocusNode();
  
  final TextEditingController _pastSimpleController = TextEditingController();
  final FocusNode _pastSimpleFocusNode = FocusNode();
  final TextEditingController _pastParticipleController = TextEditingController();
  final FocusNode _pastParticipleFocusNode = FocusNode();
  bool _isPastSimpleCorrect = false;
  bool _isPastParticipleCorrect = false;
  bool _showPastSimpleError = false;
  bool _showPastParticipleError = false;
  List<String> _completedVerbs = [];
  bool _hasStage3WrongAttempt = false;
  bool _showForm1Error = false;
  bool _isForm1Correct = false;
  static const String _verbLearningStateKey = 'verb_learning_state';

  @override
  void initState() {
    super.initState();
    
    _currentStage = widget.initialStage;
    _currentVerbIndex = widget.initialVerbIndex;
    _currentQuestionIndex = widget.initialQuestionIndex;
    
    _pageController = PageController(initialPage: _currentVerbIndex);
    _hasWrongAttempt = false;
    
    print("DEBUG VERBS RECEIVED: ${widget.verbs.length}");
    if (widget.verbs.isNotEmpty) {
      print("FIRST VERB: ${widget.verbs[0].base}, blocked=${widget.verbs[0].isBlocked}, learned=${widget.verbs[0].isLearned}");
    }
    
    _initializeVerbs();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_currentStage == 3) {
        _form1FocusNode.requestFocus();
      }
    });
  }

  void _preSelectVerbs() {
    print("DEBUG: Pre-selecting verbs because there's no saved state");
    
    if (widget.verbs.isEmpty) return;
    
    List<Verb> verbsToUse = widget.verbs
        .where((verb) => !verb.isBlocked && !verb.isLearned)
        .toList();
    
    print("DEBUG PRE-SELECT: Unlearned and unblocked verbs: ${verbsToUse.length}");
    
    if (verbsToUse.isEmpty) {
      verbsToUse = widget.verbs
          .where((verb) => !verb.isBlocked)
          .toList();
      
      print("DEBUG PRE-SELECT: All non-blocked verbs: ${verbsToUse.length}");
    }

    if (verbsToUse.isNotEmpty) {
      final random = Random();
      verbsToUse.shuffle(random);
      _currentVerbs = verbsToUse.length <= 5
          ? List.from(verbsToUse)
          : verbsToUse.sublist(0, 5);
          
      print("DEBUG PRE-SELECT: Pre-selected ${_currentVerbs.length} verbs: ${_currentVerbs.map((v) => v.base).join(', ')}");
    }
  }

  @override
  void dispose() {
    if (!_showResult) {
      _saveVerbLearningState();
    }
    
    _inputController.dispose();
    _inputFocusNode.dispose();
    _pageController.dispose();
    _form1Controller.dispose();
    _form1FocusNode.dispose();
    _pastSimpleController.dispose();
    _pastSimpleFocusNode.dispose();
    _pastParticipleController.dispose();
    _pastParticipleFocusNode.dispose();
    super.dispose();
  }

  Future<void> _saveVerbLearningState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final verbsData = _currentVerbs.map((verb) => verb.toJson()).toList();
      
      final state = {
        'stage': _currentStage,
        'verbIndex': _currentVerbIndex,
        'questionIndex': _currentQuestionIndex,
        'verbs': verbsData,
        'correctAnswers': _correctAnswers,
        'totalQuestions': _totalQuestions,
        'completedVerbs': _completedVerbs,
      };
      
      await prefs.setString(_verbLearningStateKey, jsonEncode(state));
      print("DEBUG: Verb learning state saved");
    } catch (e) {
      print("Error saving verb learning state: $e");
    }
  }


  void _initializeVerbs() {
    print("DEBUG: All verbs: ${widget.verbs.map((v) => '${v.base}(blocked=${v.isBlocked},learned=${v.isLearned})').join(', ')}");
    
    if (widget.verbs.isEmpty) {
      setState(() {
        _showResult = true;
        _currentVerbs = [];
      });
      return;
    }
    
    List<Verb> verbsToUse = [];
    
    verbsToUse = widget.verbs
        .where((verb) => !verb.isBlocked && !verb.isLearned)
        .toList();
    
    verbsToUse.sort((a, b) => a.base.compareTo(b.base));
    
    print("DEBUG: Unlearned and unblocked verbs: ${verbsToUse.length}");
    
    if (verbsToUse.isEmpty) {
      verbsToUse = widget.verbs
          .where((verb) => !verb.isBlocked)
          .toList();
      
      verbsToUse.sort((a, b) => a.base.compareTo(b.base));
      
      print("DEBUG: All non-blocked verbs: ${verbsToUse.length}");
      
      if (verbsToUse.isEmpty) {
        setState(() {
          _showResult = true;
          _currentVerbs = [];
        });
        print("DEBUG: All verbs are blocked!");
        return;
      }
    }

    print("DEBUG: Total verbs: ${widget.verbs.length}");
    print("DEBUG: Using ${verbsToUse.length} verbs");
    
    final random = Random();
    verbsToUse.shuffle(random);
    
    setState(() {
      _currentVerbs = verbsToUse.length <= 5
          ? List.from(verbsToUse)
          : verbsToUse.sublist(0, 5);
      
      _showResult = false;
    });
    
    print("DEBUG: Selected verbs: ${_currentVerbs.map((v) => v.base).join(', ')}");

    _questions = [];
    for (var verb in _currentVerbs) {
      for (int formIndex = 0; formIndex < 3; formIndex++) {
        _questions.add(Question(verb, formIndex));
      }
    }
    
    if (_questions.isNotEmpty) {
      _questions.shuffle(Random());
      _totalQuestions = _questions.length;
      print("DEBUG: Generated ${_questions.length} questions in random order");
      
      for (int i = 0; i < min(5, _questions.length); i++) {
        final q = _questions[i];
        print("DEBUG: Question $i: ${q.formIndex + 1} форма глагола ${q.verb.translation} (${q.verb.base})");
      }
    } else {
      print("DEBUG: No questions generated!");
    }
  }

  bool _checkVerbAnswer(String input, String correctAnswer) {
    final inputLower = input.trim().toLowerCase();
    final correctAnswers =
        correctAnswer.split('/').map((a) => a.trim().toLowerCase()).toList();
    
    final processedCorrectAnswers = correctAnswers.map((answer) {
      return answer.replaceAll(RegExp(r'\([^)]*\)'), '').trim();
    }).toList();
    
    return processedCorrectAnswers.any((answer) => inputLower == answer);
  }

  void _checkAnswer() {
    if (_currentStage != 2) return;

    final currentQuestion = _questions[_currentQuestionIndex];
    final correctAnswer = currentQuestion.correctAnswer;

    setState(() {
      _isCorrect = _checkVerbAnswer(_inputController.text, correctAnswer);
      if (_isCorrect) {
        _correctAnswers++;
        _showError = false;
        _hasWrongAttempt = false;
        _showHint = false;
        Future.delayed(Duration(milliseconds: 1000), () {
          if (mounted) {
            setState(() {
              _nextQuestion();
            });
          }
        });
      } else {
        _showError = true;
        _hasWrongAttempt = true;
      }
    });

    if (!_isCorrect) {
      _inputController.clear();
      _inputFocusNode.requestFocus();
    }
  }

  void _checkStage3Answers() {
    final currentVerb = _currentVerbs[_currentVerbIndex];
    final isForm1Correct = _checkVerbAnswer(
        _form1Controller.text.trim(), currentVerb.base);
    final isPastSimpleCorrect = _checkVerbAnswer(
        _pastSimpleController.text.trim(), currentVerb.pastSimple);
    final isPastParticipleCorrect = _checkVerbAnswer(
        _pastParticipleController.text.trim(), currentVerb.pastParticiple);

    setState(() {
      _isForm1Correct = isForm1Correct;
      _isPastSimpleCorrect = isPastSimpleCorrect;
      _isPastParticipleCorrect = isPastParticipleCorrect;
      _showForm1Error = !isForm1Correct;
      _showPastSimpleError = !isPastSimpleCorrect;
      _showPastParticipleError = !isPastParticipleCorrect;
      
      if (!isForm1Correct || !isPastSimpleCorrect || !isPastParticipleCorrect) {
        _hasStage3WrongAttempt = true;
      }
    });

    if (isForm1Correct && isPastSimpleCorrect && isPastParticipleCorrect) {
      _saveProgress();
      if (_currentVerbIndex < _currentVerbs.length - 1) {
        _goToNextVerb();
      } else {
        _showCompletionDialog();
      }
    }
  }

  void _nextQuestion() {
    print("DEBUG: nextQuestion called, stage: $_currentStage, questionIndex: $_currentQuestionIndex, total questions: ${_questions.length}");
    
    if (_currentStage == 2) {
      if (_currentQuestionIndex < _questions.length - 1) {
        setState(() {
          _currentQuestionIndex++;
          _inputController.clear();
          _inputFocusNode.requestFocus();
          _showHint = false;
          _showError = false;
          _hasWrongAttempt = false;
          _isCorrect = false;
        });
        print("DEBUG: Moving to next question: $_currentQuestionIndex");
      } else {
        print("DEBUG: Stage 2 complete, moving to stage 3");
        setState(() {
          _currentStage = 3;
          _currentVerbIndex = 0;
          _inputController.clear();
          _form1Controller.clear();
          _pastSimpleController.clear();
          _pastParticipleController.clear();
          _showHint = false;
          _showError = false;
          _hasWrongAttempt = false;
          _isCorrect = false;
          _isForm1Correct = false;
          _isPastSimpleCorrect = false;
          _isPastParticipleCorrect = false;
          _showForm1Error = false;
          _showPastSimpleError = false;
          _showPastParticipleError = false;
          
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _form1FocusNode.requestFocus();
          });
        });
      }
    } else if (_currentStage == 3) {
      if (_currentVerbIndex < _currentVerbs.length - 1) {
        print("DEBUG: Moving to next verb: ${_currentVerbIndex + 1}");
        setState(() {
          _currentVerbIndex++;
          _form1Controller.clear();
          _pastSimpleController.clear();
          _pastParticipleController.clear();
          _showHint = false;
          _showError = false;
          _hasWrongAttempt = false;
          _isCorrect = false;
          _isForm1Correct = false;
          _isPastSimpleCorrect = false;
          _isPastParticipleCorrect = false;
          _showForm1Error = false;
          _showPastSimpleError = false;
          _showPastParticipleError = false;
          
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _form1FocusNode.requestFocus();
          });
        });
      } else {
        print("DEBUG: Stage 3 complete, finishing learning");
        _finishLearning();
      }
    }
  }

  void _finishLearning() {
    if (!mounted) return;

    setState(() {
      for (var verb in _currentVerbs) {
        verb.isLearned = true;
        verb.repetitions++;
      }
      widget.onVerbsUpdated(widget.verbs);
      _showResult = true;
    });
    
    _clearSavedLearningState();
  }

  
  Future<void> _clearSavedLearningState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stateKey = 'verb_learning_state';
      await prefs.remove(stateKey);
    } catch (e) {
      print('Error clearing verb learning state: $e');
    }
  }


  String _getHint(Question question) {
    return question.correctAnswer;
  }

  Widget _buildStage1() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final cardWidth = (screenWidth > 600 ? 600 : screenWidth * 0.9).toDouble();
    final cardHeight = screenHeight * 0.5;

    print("DEBUG: In buildStage1, currentVerbs: ${_currentVerbs.length}");

    if (_currentVerbs.isEmpty && widget.verbs.isNotEmpty) {
      print("DEBUG: Fixing empty currentVerbs in buildStage1");
      _preSelectVerbs();
      if (_currentVerbs.isEmpty) {
        print("DEBUG: Still no verbs after preselect attempt");
      }
    }

    if (_currentVerbs.isEmpty) {
      print("DEBUG: No verbs in stage 1");
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Нет доступных глаголов для изучения',
              style: TextStyle(
                fontSize: 20,
                color: themeProvider.themeColor,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                backgroundColor: themeProvider.isDarkTheme
                    ? Colors.grey[700]
                    : Colors.brown[400],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Вернуться в главное меню',
                style: TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: _currentVerbs.length,
            onPageChanged: (index) {
              setState(() {
                _currentVerbIndex = index;
                _showTranslation = false;
              });
            },
            itemBuilder: (context, index) {
              final verb = _currentVerbs[index];
              return Center(
                child: Container(
                  width: cardWidth,
                  height: cardHeight,
                  child: Card(
                    elevation: 8,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    color: themeProvider.themeBackgroundColor,
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _showTranslation = !_showTranslation;
                        });
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                verb.translation,
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: themeProvider.themeColor,
                                ),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                verb.base,
                                style: TextStyle(
                                  fontSize: 24,
                                  color: themeProvider.themeColor,
                                ),
                              ),
                              Text(
                                verb.baseTranscription,
                                style: TextStyle(
                                  fontSize: 18,
                                  color:
                                      themeProvider.themeColor.withAlpha(179),
                                ),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                verb.pastSimple,
                                style: TextStyle(
                                  fontSize: 24,
                                  color: themeProvider.themeColor,
                                ),
                              ),
                              Text(
                                verb.pastSimpleTranscription,
                                style: TextStyle(
                                  fontSize: 18,
                                  color:
                                      themeProvider.themeColor.withAlpha(179),
                                ),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                verb.pastParticiple,
                                style: TextStyle(
                                  fontSize: 24,
                                  color: themeProvider.themeColor,
                                ),
                              ),
                              Text(
                                verb.pastParticipleTranscription,
                                style: TextStyle(
                                  fontSize: 18,
                                  color:
                                      themeProvider.themeColor.withAlpha(179),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: Icon(
                  Icons.arrow_back_ios,
                  color: _currentVerbIndex > 0
                      ? themeProvider.themeColor
                      : themeProvider.themeColor.withAlpha(77),
                  size: 32,
                ),
                onPressed: _currentVerbIndex > 0
                    ? () {
                        _pageController.previousPage(
                          duration: Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      }
                    : null,
              ),
              SizedBox(width: 40),
              IconButton(
                icon: Icon(
                  Icons.arrow_forward_ios,
                  color: _currentVerbIndex < _currentVerbs.length - 1
                      ? themeProvider.themeColor
                      : themeProvider.themeColor.withAlpha(77),
                  size: 32,
                ),
                onPressed: _currentVerbIndex < _currentVerbs.length - 1
                    ? () {
                        _pageController.nextPage(
                          duration: Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      }
                    : null,
              ),
            ],
          ),
        ),
        if (_currentVerbIndex == _currentVerbs.length - 1)
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: ElevatedButton(
              onPressed: () {
                print("DEBUG: Moving from Stage 1 to Stage 2");
                setState(() {
                  _currentStage = 2;
                  _currentVerbIndex = 0;
                  _currentQuestionIndex = 0;
                  _inputController.clear();
                  _inputFocusNode.requestFocus();
                });
              },
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                backgroundColor: themeProvider.isDarkTheme
                    ? Colors.grey[700]
                    : Colors.brown[400],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 4,
              ),
              child: Text(
                'Начать проверку',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildStage2() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    if (_questions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Нет доступных глаголов для изучения',
              style: TextStyle(
                fontSize: 20,
                color: themeProvider.themeColor,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                backgroundColor: themeProvider.isDarkTheme
                    ? Colors.grey[700]
                    : Colors.brown[400],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Вернуться в главное меню',
                style: TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
      );
    }
    
    final currentQuestion = _questions[_currentQuestionIndex];
    final screenWidth = MediaQuery.of(context).size.width;
    final maxWidth = screenWidth > 600 ? 600.0 : screenWidth * 0.9;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Container(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Вопрос ${_currentQuestionIndex + 1} из ${_questions.length}',
                style: TextStyle(
                  fontSize: 18,
                  color: themeProvider.themeColor,
                ),
              ),
              SizedBox(height: 32),
              Card(
                elevation: 4,
                color: themeProvider.themeBackgroundColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      Text(
                        currentQuestion.formLabel,
                        style: TextStyle(
                          fontSize: 24,
                          color: themeProvider.themeColor.withAlpha(204),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 20),
                      Text(
                        currentQuestion.verb.translation,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: themeProvider.themeColor,
                        ),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.visible,
                      ),
                      SizedBox(height: 24),
                      TextField(
                        controller: _inputController,
                        focusNode: _inputFocusNode,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          color: themeProvider.themeColor,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Введите форму глагола',
                          labelStyle: TextStyle(color: themeProvider.themeColor),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: themeProvider.themeColor),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: themeProvider.themeColor.withAlpha(128)),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.red),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.red),
                          ),
                          errorText: _showError ? 'Неправильный ответ' : null,
                          suffixIcon: _isCorrect
                              ? Icon(Icons.check_circle, color: Colors.green)
                              : null,
                        ),
                        onSubmitted: (_) {
                          _checkAnswer();
                        },
                      ),
                      if (!_isCorrect && _showHint) ...[
                        SizedBox(height: 20),
                        Text(
                          'Подсказка: ${_getHint(currentQuestion)}',
                          style: TextStyle(
                            fontSize: 16,
                            color: themeProvider.themeColor.withAlpha(153),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              SizedBox(height: 32),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 16,
                runSpacing: 16,
                children: [
                  ElevatedButton(
                    onPressed: _hasWrongAttempt
                        ? () {
                            setState(() {
                              _showHint = !_showHint;
                            });
                          }
                        : null,
                    child: Text(
                      _showHint ? 'Скрыть подсказку' : 'Показать подсказку',
                      style: TextStyle(fontSize: 18, color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: themeProvider.isDarkTheme
                          ? Colors.grey[700]
                          : Colors.brown[400],
                      padding:
                          EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      _checkAnswer();
                    },
                    child: Text(
                      'Проверить',
                      style: TextStyle(fontSize: 18, color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: themeProvider.isDarkTheme
                          ? Colors.grey[700]
                          : Colors.brown[400],
                      padding:
                          EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStage3() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_form1FocusNode.hasFocus && mounted) {
        _form1FocusNode.requestFocus();
      }
    });
    
    if (_currentVerbs.isEmpty || _currentVerbIndex >= _currentVerbs.length) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Нет доступных глаголов для изучения',
              style: TextStyle(
                fontSize: 20,
                color: themeProvider.themeColor,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                backgroundColor: themeProvider.isDarkTheme
                    ? Colors.grey[700]
                    : Colors.brown[400],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Вернуться в главное меню',
                style: TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
      );
    }
    
    final currentVerb = _currentVerbs[_currentVerbIndex];
    final screenWidth = MediaQuery.of(context).size.width;
    final maxWidth = screenWidth > 600 ? 600.0 : screenWidth * 0.9;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Container(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Глагол ${_currentVerbIndex + 1} из ${_currentVerbs.length}',
                style: TextStyle(
                  fontSize: 18,
                  color: themeProvider.themeColor,
                ),
              ),
              SizedBox(height: 24),
              Card(
                elevation: 4,
                color: themeProvider.themeBackgroundColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      Text(
                        currentVerb.translation,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: themeProvider.themeColor,
                        ),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.visible,
                      ),
                      SizedBox(height: 24),
                      
                      Text(
                        'Введите формы глагола',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: themeProvider.themeColor,
                        ),
                      ),
                      SizedBox(height: 24),

                      Text(
                        'Введите 1-ю форму',
                        style: TextStyle(
                          fontSize: 16,
                          color: themeProvider.themeColor.withAlpha(204),
                        ),
                      ),
                      SizedBox(height: 8),
                      TextField(
                        controller: _form1Controller,
                        focusNode: _form1FocusNode,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          color: themeProvider.themeColor,
                        ),
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: themeProvider.themeColor),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: themeProvider.themeColor.withAlpha(128)),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.red),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.red),
                          ),
                          errorText: _showForm1Error ? 'Неправильно' : null,
                          suffixIcon: _isForm1Correct
                              ? Icon(Icons.check_circle, color: Colors.green)
                              : null,
                        ),
                        onSubmitted: (_) {
                          _pastSimpleFocusNode.requestFocus();
                        },
                      ),
                      SizedBox(height: 20),
                      
                      Text(
                        'Введите 2-ю форму',
                        style: TextStyle(
                          fontSize: 16,
                          color: themeProvider.themeColor.withAlpha(204),
                        ),
                      ),
                      SizedBox(height: 8),
                      TextField(
                        controller: _pastSimpleController,
                        focusNode: _pastSimpleFocusNode,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          color: themeProvider.themeColor,
                        ),
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: themeProvider.themeColor),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: themeProvider.themeColor.withAlpha(128)),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.red),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.red),
                          ),
                          errorText: _showPastSimpleError ? 'Неправильно' : null,
                          suffixIcon: _isPastSimpleCorrect
                              ? Icon(Icons.check_circle, color: Colors.green)
                              : null,
                        ),
                        onSubmitted: (_) {
                          _pastParticipleFocusNode.requestFocus();
                        },
                      ),
                      SizedBox(height: 20),
                      Text(
                        'Введите 3-ю форму',
                        style: TextStyle(
                          fontSize: 16,
                          color: themeProvider.themeColor.withAlpha(204),
                        ),
                      ),
                      SizedBox(height: 8),
                      TextField(
                        controller: _pastParticipleController,
                        focusNode: _pastParticipleFocusNode,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          color: themeProvider.themeColor,
                        ),
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: themeProvider.themeColor),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: themeProvider.themeColor.withAlpha(128)),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.red),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.red),
                          ),
                          errorText: _showPastParticipleError ? 'Неправильно' : null,
                          suffixIcon: _isPastParticipleCorrect
                              ? Icon(Icons.check_circle, color: Colors.green)
                              : null,
                        ),
                        onSubmitted: (_) {
                          _checkStage3Answers();
                        },
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 32),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 16,
                runSpacing: 16,
                children: [
                  if ((!_isForm1Correct || !_isPastSimpleCorrect || !_isPastParticipleCorrect) && _hasStage3WrongAttempt)
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _form1Controller.text = currentVerb.base;
                          _pastSimpleController.text = currentVerb.pastSimple;
                          _pastParticipleController.text =
                              currentVerb.pastParticiple;
                          _showForm1Error = false;
                          _showPastSimpleError = false;
                          _showPastParticipleError = false;
                          _isForm1Correct = true;
                          _isPastSimpleCorrect = true;
                          _isPastParticipleCorrect = true;
                        });
                      },
                      child: Text(
                        'Показать ответ',
                        style: TextStyle(fontSize: 18, color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: themeProvider.isDarkTheme
                            ? Colors.grey[700]
                            : Colors.brown[400],
                        padding:
                            EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ElevatedButton(
                    onPressed: () {
                      _checkStage3Answers();
                    },
                    child: Text(
                      'Проверить',
                      style: TextStyle(fontSize: 18, color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: themeProvider.isDarkTheme
                          ? Colors.grey[700]
                          : Colors.brown[400],
                      padding:
                          EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultScreen() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final maxWidth = screenWidth > 600 ? 600.0 : screenWidth * 0.9;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Container(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Card(
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                color: themeProvider.themeBackgroundColor,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 30),
                  child: Column(
                    children: [
                      Icon(
                        Icons.celebration,
                        size: 60,
                        color: themeProvider.isDarkTheme
                            ? Colors.amber[400]
                            : Colors.brown[300],
                      ),
                      SizedBox(height: 20),
                      Text(
                        'Поздравляем!',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: themeProvider.themeColor,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 20),
                      Text(
                        'Вы изучили ${_currentVerbs.length} глаголов!',
                        style: TextStyle(
                          fontSize: 24,
                          color: themeProvider.themeColor.withAlpha(204),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: themeProvider.isDarkTheme
                            ? Colors.grey[800]
                            : Colors.brown[400],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 4,
                      ),
                      child: Text(
                        'В главное меню',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _initializeVerbs();
                          _currentStage = 1;
                          _currentVerbIndex = 0;
                          _showResult = false;
                          _correctAnswers = 0;
                          _showHint = false;
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: themeProvider.isDarkTheme
                            ? Colors.grey[700]
                            : Colors.brown[300],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 4,
                      ),
                      child: Text(
                        'Начать новый набор',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _saveProgress() {
    final currentVerb = _currentVerbs[_currentVerbIndex];
    setState(() {
      _completedVerbs.add(currentVerb.base);
    });
  }

  void _goToNextVerb() {
    setState(() {
      _currentVerbIndex++;
      _resetStage3Fields();
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _form1FocusNode.requestFocus();
      });
    });
  }

  void _resetStage3Fields() {
    _form1Controller.clear();
    _pastSimpleController.clear();
    _pastParticipleController.clear();
    _isForm1Correct = false;
    _isPastSimpleCorrect = false;
    _isPastParticipleCorrect = false;
    _showForm1Error = false;
    _showPastSimpleError = false;
    _showPastParticipleError = false;
    _hasStage3WrongAttempt = false;
  }

  void _showCompletionDialog() {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: themeProvider.themeBackgroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Поздравляем!',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: themeProvider.themeColor,
            ),
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.celebration,
                size: 48,
                color: themeProvider.isDarkTheme ? Colors.amber[400] : Colors.brown[300],
              ),
              SizedBox(height: 16),
              Text(
                'Вы завершили изучение этого набора глаголов!',
                style: TextStyle(
                  fontSize: 18,
                  color: themeProvider.themeColor,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              child: Text(
                'Вернуться в меню',
                style: TextStyle(
                  color: themeProvider.isDarkTheme ? Colors.grey[400] : Colors.brown[700],
                  fontSize: 16,
                ),
              ),
              onPressed: () {
                _finishLearning();
                Navigator.of(context).pop();
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              child: Text(
                'Следующий набор',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: themeProvider.isDarkTheme ? Colors.grey[700] : Colors.brown[400],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                setState(() {
                  _finishLearning();
                  _initializeVerbs();
                  _currentStage = 1;
                  _currentVerbIndex = 0;
                  _showResult = false;
                });
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    print("DEBUG: Build method called - verbs: ${widget.verbs.length}, currentVerbs: ${_currentVerbs.length}, stage: $_currentStage, showResult: $_showResult");
    
    if (_currentVerbs.isEmpty && widget.verbs.isNotEmpty && !_showResult) {
      print("DEBUG: Fixing inconsistent state - repopulating verbs");
      _preSelectVerbs();
    }
    
    if (widget.verbs.isEmpty) {
      print("DEBUG: Empty verbs in build - forcing result state");
      setState(() {
        _showResult = true;
      });
    }
    
    if (_currentVerbs.isNotEmpty && _showResult && _currentStage == 1) {
      print("DEBUG: We have verbs but showResult is true - fixing");
      setState(() {
        _showResult = false;
      });
    }
    
    print("DEBUG: In build - stage: $_currentStage, showResult: $_showResult, currentVerbs: ${_currentVerbs.length}");

    return WillPopScope(
      onWillPop: () async {
        if (!_showResult && _currentStage == 3) {
          final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
          final shouldExit = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: themeProvider.themeBackgroundColor,
              title: Text(
                'Вы уверены?',
                style: TextStyle(color: themeProvider.themeColor),
              ),
              content: Text(
                'Прогресс будет сохранен только для уже полностью изученных глаголов',
                style: TextStyle(color: themeProvider.themeColor),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(
                    'Нет',
                    style: TextStyle(color: themeProvider.themeColor),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(true);
                  },
                  child: Text(
                    'Да',
                    style: TextStyle(color: themeProvider.themeColor),
                  ),
                ),
              ],
            ),
          );
          return shouldExit ?? false;
        }
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: Icon(Icons.home, color: Colors.white),
            onPressed: () {
              if (!_showResult && _currentStage == 3) {
                final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor: themeProvider.themeBackgroundColor,
                    title: Text(
                      'Вы уверены?',
                      style: TextStyle(color: themeProvider.themeColor),
                    ),
                    content: Text(
                      'Прогресс будет сохранен только для уже полностью изученных глаголов',
                      style: TextStyle(color: themeProvider.themeColor),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(
                          'Нет',
                          style: TextStyle(color: themeProvider.themeColor),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          Navigator.of(context).pop();
                        },
                        child: Text(
                          'Да',
                          style: TextStyle(color: themeProvider.themeColor),
                        ),
                      ),
                    ],
                  ),
                );
              } else {
                Navigator.of(context).pop();
              }
            },
          ),
          title: Text('Изучение глаголов'),
          backgroundColor: themeProvider.isDarkTheme
              ? Colors.grey[900]
              : themeProvider.themeColor,
        ),
        body: Container(
          color: themeProvider.themeBackgroundColor,
          child: _showResult
              ? _buildResult()
              : _currentStage == 1
                  ? _buildStage1()
                  : _currentStage == 2
                      ? SingleChildScrollView(
                          padding: EdgeInsets.all(20),
                          child: _buildStage2(),
                        )
                      : SingleChildScrollView(
                          padding: EdgeInsets.all(20),
                          child: _buildStage3(),
                        ),
        ),
      ),
    );
  }

  Widget _buildResult() {
    final themeProvider = Provider.of<ThemeProvider>(context);

    if (_currentVerbs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              color: themeProvider.themeBackgroundColor,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                child: Column(
                  children: [
                    Text(
                      'Нет доступных глаголов',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: themeProvider.themeColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 20),
                    Text(
                      'Все глаголы уже изучены',
                      style: TextStyle(
                        fontSize: 24,
                        color: themeProvider.themeColor.withAlpha(204),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 40),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                backgroundColor: themeProvider.isDarkTheme
                    ? Colors.grey[700]
                    : themeProvider.themeColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 4,
              ),
              child: Text(
                'В главное меню',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return _buildResultScreen();
  }
}
