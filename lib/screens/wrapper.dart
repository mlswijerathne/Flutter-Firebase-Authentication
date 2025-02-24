import 'package:auth/screens/loading_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'auth/sign_in_page.dart';
import 'home/home_page.dart';

class Wrapper extends StatelessWidget {
  const Wrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return LoadingPage(); // Show loading page initially
        }
        if (snapshot.hasData) {
          return HomePage(); // User is logged in, show home page
        }
        return SignInPage(); // User is not logged in, show sign-in page
      },
    );
  }
}