import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:whatsup/authentication/Wrapper.dart';
import 'package:whatsup/home.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeNotifications();

  if (kIsWeb) {
    await Firebase.initializeApp(
      options: FirebaseOptions(
          ///
          /
          /
          /
          /
          /
          /
          
    );
  } else {
    await Firebase.initializeApp();
  }

  await Supabase.initialize(
    url: 'https://ptfaqewjxwzbzvyskjfx.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InB0ZmFxZXdqeHd6Ynp2eXNramZ4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDA1NDk1ODgsImV4cCI6MjA1NjEyNTU4OH0.ioY0tD0O7JsTMOsD3pUext8eiTZFC1mTXZzwJp_IPHo',
  );

  runApp(MyApp());
}

Future<void> initializeNotifications() async {
  const AndroidInitializationSettings androidSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  final InitializationSettings initializationSettings =
      InitializationSettings(android: androidSettings);

  await flutterLocalNotificationsPlugin.initialize(initializationSettings);
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      initialRoute: '/', // Start from the wrapper screen
      routes: {
        '/': (context) => Wrapper(),
        '/home': (context) => const WhatsAppClone(),
      },
    );
  }
}
