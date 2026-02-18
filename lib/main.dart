import 'package:flutter/material.dart';
import 'package:flutter_application_4_geodesica/presentation/providers/messageProvider.dart';
import 'package:flutter_application_4_geodesica/presentation/providers/themeProvider.dart';
import 'package:flutter_application_4_geodesica/presentation/providers/userProvider.dart';
import 'package:flutter_application_4_geodesica/theme/theme.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:flutter_application_4_geodesica/presentation/screens/chatMain.dart';
import 'authS.dart';
import 'package:flutter_application_4_geodesica/presentation/screens/chat_list_screen.dart';
import 'registerS.dart';


void main() async{
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(create: (_) => AppThemeProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
        // Puedes agregar más providers aquí si los necesitas
      ],
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Obtenemos el provider usando Provider.of
    final themeProvider = Provider.of<AppThemeProvider>(context, listen: true);

    return MaterialApp(
      title: 'Mi Aplicación',
      debugShowCheckedModeBanner: false,
      theme:
          AppTheme(
            selectedColor: themeProvider.selectedColor,
            isDarkMode: false,
          ).getTheme(),
      darkTheme:
          AppTheme(
            selectedColor: themeProvider.selectedColor,
            isDarkMode: true,
          ).getTheme(),
      themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      initialRoute: '/',
      routes: {
        '/': (context) => AuthScreen(),
        '/register': (context) => RegisterScreen(),
        '/chat': (context) => const ChatScreen(),
        '/chat-list': (context) => const ChatListScreen(),
      },
    );
  }
}
