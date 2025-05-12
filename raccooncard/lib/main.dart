import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/home_screen.dart';
import 'models/category.dart';
import 'models/verb.dart';
import 'theme/theme_provider.dart';
import 'services/file_service.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

void main() async {
  // Сохранение splash screen до загрузки данных
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  
  print("Инициализация приложения...");

  try {
    // Загрузка данных
    final categories = await FileService.loadCategories();
    final verbs = await loadVerbs();
    final customVerbs = await FileService.loadCustomVerbs();
    
    // Копируем ассеты в локальную файловую систему
    await FileService.copyAssetsToLocalFile();
    
    // Объединяем встроенные и пользовательские глаголы
    verbs.addAll(customVerbs);
    
    // Удаление splash screen после загрузки всех данных
    FlutterNativeSplash.remove();
    
    // Запуск приложения
    runApp(
      ChangeNotifierProvider(
        create: (_) => ThemeProvider(),
        child: LifecycleManager(
          child: MyApp(
            categories: categories,
            verbs: verbs,
          ),
        ),
      ),
    );
  } catch (e) {
    print("Ошибка при загрузке данных: $e");
    
    // Удаление splash screen в случае ошибки
    FlutterNativeSplash.remove();
    
    // Запуск приложения с пустыми данными
    runApp(
      ChangeNotifierProvider(
        create: (_) => ThemeProvider(),
        child: LifecycleManager(
          child: MyApp(
            categories: [],
            verbs: [],
          ),
        ),
      ),
    );
  }
}

// Загрузка глаголов
Future<List<Verb>> loadVerbs() async {
  try {
    final localVerbs = await FileService.loadVerbsFromLocalFile();
    if (localVerbs.isNotEmpty) {
      print("Loaded ${localVerbs.length} verbs from local file");
      return localVerbs;
    }
  } catch (e) {
    print("Error loading verbs from local file: $e");
  }
  
  return FileService.loadVerbs();
}

class MyApp extends StatelessWidget {
  final List<Category> categories;
  final List<Verb> verbs;

  const MyApp({
    Key? key,
    required this.categories,
    required this.verbs,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      title: 'Raccoon Card',
      theme: themeProvider.themeData,
      
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en', ''),
        Locale('ru', ''),
      ],
      locale: const Locale('ru', ''),
      home: HomeScreen(
        categories: categories,
        verbs: verbs,
      ),
    );
  }
}

/// Класс для управления жизненным циклом приложения
class LifecycleManager extends StatefulWidget {
  final Widget child;

  const LifecycleManager({Key? key, required this.child}) : super(key: key);

  @override
  _LifecycleManagerState createState() => _LifecycleManagerState();
}

class _LifecycleManagerState extends State<LifecycleManager>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    print('Состояние жизненного цикла: $state');
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
