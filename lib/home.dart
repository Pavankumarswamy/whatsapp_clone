import 'package:flutter/material.dart';
import 'package:whatsup/screens/home.dart';
import 'package:permission_handler/permission_handler.dart';

class WhatsAppClone extends StatefulWidget {
  const WhatsAppClone({super.key});

  @override
  State<WhatsAppClone> createState() => _WhatsAppCloneState();
}

class _WhatsAppCloneState extends State<WhatsAppClone> {
  @override
  void initState() {
    super.initState();
    _requestPermissions(); // Request permissions when the app starts
  }

  Future<void> _requestPermissions() async {
    // Request notification permission
    PermissionStatus notificationStatus =
        await Permission.notification.request();
    if (notificationStatus.isDenied) {
      _showPermissionDialog(
        'Notification Permission',
        'Please allow notifications to receive chat updates.',
        Permission.notification,
      );
    } else if (notificationStatus.isPermanentlyDenied) {
      _showSettingsDialog(
        'Notification Permission',
        'Notification permission is permanently denied. Please enable it in settings.',
      );
    }

    // Request contacts permission
    PermissionStatus contactsStatus = await Permission.contacts.request();
    if (contactsStatus.isDenied) {
      _showPermissionDialog(
        'Contacts Permission',
        'Please allow access to contacts to sync your contact list.',
        Permission.contacts,
      );
    } else if (contactsStatus.isPermanentlyDenied) {
      _showSettingsDialog(
        'Contacts Permission',
        'Contacts permission is permanently denied. Please enable it in settings.',
      );
    }
  }

  void _showPermissionDialog(
      String title, String message, Permission permission) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await permission.request();
            },
            child: const Text('Request Again'),
          ),
        ],
      ),
    );
  }

  void _showSettingsDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings(); // Opens app settings
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Whatsup',
      theme: ThemeData(
        primaryColor: const Color(0xFF075E54),
        scaffoldBackgroundColor: const Color(0xFFECE5DD),
        appBarTheme: const AppBarTheme(
          color: Color(0xFF075E54),
          titleTextStyle: TextStyle(color: Colors.white, fontSize: 20),
          iconTheme: IconThemeData(color: Colors.white),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Color(0xFF25D366),
        ),
      ),
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
