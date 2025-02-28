import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:whatsup/authentication/emailverify.dart';
import '../home.dart';
import 'login.dart';

class Wrapper extends StatelessWidget {
  const Wrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
              child: CircularProgressIndicator()); // Show loading state
        }

        if (snapshot.hasData) {
          User? user = snapshot.data;

          // Check if email is verified
          if (user != null && user.emailVerified) {
            return WhatsAppClone(); // Navigate to home if verified
          } else {
            return EmailVerificationPage(); // Navigate to email verification page
          }
        } else {
          return LoginPage(); // Navigate to login/signup page
        }
      },
    );
  }
}
