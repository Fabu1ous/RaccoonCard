import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/theme_provider.dart';
import 'dart:math' as math;

class TranscriptionKeyboard extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onClose;

  const TranscriptionKeyboard({
    Key? key,
    required this.controller,
    required this.onClose,
  }) : super(key: key);

  static const List<String> mainSymbols = [
    'æ',
    'ʌ',
    'ɑ',
    'ɒ',
    'ə',
    'ɜ',
    'ɔ',
    'ɪ',
    'i',
    'ʊ',
    'u',
    'e',
    'a',
    'p',
    'b',
    't',
    'd',
    'k',
    'g',
    'f',
    'v',
    'θ',
    'ð',
    's',
    'z',
    'ʃ',
    'ʒ',
    'h',
    'm',
    'n',
    'ŋ',
    'l',
    'r',
    'w',
    'j',
  ];

  static const List<String> specialSymbols = ['[', ']', '(', ')', ':', '\''];

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final screenSize = MediaQuery.of(context).size;
    final maxWidth = math.min(screenSize.width, 600.0);
    final keyboardHeight = screenSize.height * 0.35;

    // Автоматически устанавливаем фокус на поле ввода
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(FocusNode());
      controller.selection = TextSelection.fromPosition(
        TextPosition(offset: controller.text.length),
      );
    });

    // Создаем список всех символов с разделением на строки
    final symbolRows = [
      ['æ', 'ʌ', 'ɑ', 'ɒ', 'ə', 'ɜ', 'ɔ'],
      ['ɪ', 'i', 'ʊ', 'u', 'e', 'a', 'p'],
      ['b', 't', 'd', 'k', 'g', 'f', 'v'],
      ['θ', 'ð', 's', 'z', 'ʃ', 'ʒ', 'h'],
      ['m', 'n', 'ŋ', 'l', 'r', 'w', 'j'],
    ];

    return Container(
      width: maxWidth,
      height: keyboardHeight,
      decoration: BoxDecoration(
        color: themeProvider.themeBackgroundColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Основные символы в строках
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(4.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: symbolRows.map((row) {
                    return Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: row.map((symbol) {
                          return Expanded(
                            child: Padding(
                              padding: EdgeInsets.all(2.0),
                              child: _buildButton(context, symbol, themeProvider),
                            ),
                          );
                        }).toList(),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            
            // Спец символы
            Container(
              height: keyboardHeight * 0.15,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: specialSymbols.map((symbol) {
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.all(2.0),
                        child: _buildButton(context, symbol, themeProvider),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            
            // Управляющие кнопки
            Container(
              height: keyboardHeight * 0.15,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.all(2.0),
                        child: _buildControlButton(
                          context,
                          Icons.backspace,
                          () {
                            final currentText = controller.text;
                            final selection = controller.selection;
                            if (selection.start > 0) {
                              final newText = currentText.replaceRange(
                                selection.start - 1,
                                selection.end,
                                '',
                              );
                              controller.text = newText;
                              controller.selection = TextSelection.collapsed(
                                offset: selection.start - 1,
                              );
                            }
                          },
                          themeProvider,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Padding(
                        padding: EdgeInsets.all(2.0),
                        child: _buildControlButton(
                          context,
                          Icons.space_bar,
                          () {
                            final currentText = controller.text;
                            final selection = controller.selection;
                            final newText = currentText.replaceRange(
                              selection.start,
                              selection.end,
                              ' ',
                            );
                            controller.text = newText;
                            controller.selection = TextSelection.collapsed(
                              offset: selection.start + 1,
                            );
                          },
                          themeProvider,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.all(2.0),
                        child: _buildControlButton(
                          context,
                          Icons.keyboard_arrow_down,
                          onClose,
                          themeProvider,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildButton(
      BuildContext context, String symbol, ThemeProvider themeProvider) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: themeProvider.isDarkTheme ? Colors.grey[700] : Colors.brown[400],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            final currentText = controller.text;
            final selection = controller.selection;
            final newText = currentText.replaceRange(
              selection.start,
              selection.end,
              symbol,
            );
            controller.text = newText;
            controller.selection = TextSelection.collapsed(
              offset: selection.start + symbol.length,
            );
          },
          child: Center(
            child: Text(
              symbol,
              style: TextStyle(fontSize: 20, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildControlButton(
    BuildContext context,
    IconData icon,
    VoidCallback onPressed,
    ThemeProvider themeProvider,
  ) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: themeProvider.isDarkTheme ? Colors.grey[700] : Colors.brown[400],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onPressed,
          child: Center(
            child: Icon(icon, color: Colors.white),
          ),
        ),
      ),
    );
  }
}
