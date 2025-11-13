import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
//import 'firebase_options.dart';
import 'screens/auth_screen.dart';
import 'screens/chat_list_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WhatsApp Clone',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.green,
        primaryColor: Color(0xFF075E54),
        colorScheme: ColorScheme.fromSeed(
          seedColor: Color(0xFF075E54),
          primary: Color(0xFF075E54),
          secondary: Color(0xFF25D366),
        ),
        useMaterial3: true,
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              backgroundColor: Colors.white,
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.message,
                      size: 64,
                      color: Color(0xFF25D366),
                    ),
                    SizedBox(height: 20),
                    CircularProgressIndicator(
                      color: Color(0xFF25D366),
                    ),
                  ],
                ),
              ),
            );
          }
          
          if (snapshot.hasError) {
            return const AuthScreen();
          }
          
          if (snapshot.hasData && snapshot.data != null) {
            return const ChatListScreen();
          }
          
          return const AuthScreen();
        },
      ),
    );
  }
}