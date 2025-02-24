import 'dart:io';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import '../models/user_model.dart';

class AuthService with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Convert File to base64 string
  Future<String?> encodeImage(File imageFile) async {
    try {
      final imageBytes = await imageFile.readAsBytes();
      final image = img.decodeImage(imageBytes);
      if (image == null) throw Exception('Could not decode image');
      final resizedImage = img.copyResize(
        image,
        width: 300,
        height: 300,
        interpolation: img.Interpolation.linear
      );
      final compressedBytes = img.encodeJpg(resizedImage, quality: 70);
      final base64String = base64Encode(compressedBytes);
      debugPrint('Image encoded successfully');
      return base64String;
    } catch (e) {
      debugPrint('Error encoding image: $e');
      return null;
    }
  }

  Future<UserCredential> signUpWithEmail(
    String email,
    String password,
    String name,
    File? profilePicture,
  ) async {
    try {
      final authResult = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      String? encodedImage;
      if (profilePicture != null) {
        encodedImage = await encodeImage(profilePicture);
      }

      UserModel newUser = UserModel(
        uid: authResult.user!.uid,
        name: name,
        email: email,
        profilePicture: encodedImage,
      );

      await _saveUserToFirestore(newUser, 3);
      debugPrint('User successfully created and stored in Firestore');
      notifyListeners();
      return authResult;
    } catch (e) {
      debugPrint('Error during sign up: $e');
      rethrow;
    }
  }

  Future<void> _saveUserToFirestore(UserModel user, int retryCount) async {
    for (int i = 0; i < retryCount; i++) {
      try {
        await _firestore
            .collection('users')
            .doc(user.uid)
            .set(user.toMap());
        return;
      } catch (e) {
        if (i == retryCount - 1) {
          throw Exception('Failed to save user data after $retryCount attempts');
        }
        await Future.delayed(Duration(seconds: 1));
      }
    }
  }

  Future<void> updateUserProfile(String uid, String name, File? newProfilePicture) async {
    try {
      Map<String, dynamic> updateData = {'name': name};

      if (newProfilePicture != null) {
        String? encodedImage = await encodeImage(newProfilePicture);
        if (encodedImage != null) {
          updateData['profilePicture'] = encodedImage;
        }
      }

      await _firestore
          .collection('users')
          .doc(uid)
          .update(updateData);

      notifyListeners();
    } catch (e) {
      debugPrint('Error updating profile: $e');
      rethrow;
    }
  }

  Future<UserCredential> signInWithEmail(String email, String password) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      debugPrint('User signed in: ${userCredential.user?.uid}');
      return userCredential;
    } catch (e) {
      debugPrint('Error signing in: $e');
      rethrow;
    }
  }

  Future<UserCredential> signInWithGoogle() async {
    try {
      await _googleSignIn.signOut();
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        throw Exception('Google sign in aborted by user');
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);

      // Convert Google photo URL to base64
      String? encodedImage;
      if (userCredential.user!.photoURL != null) {
        final response = await HttpClient().getUrl(Uri.parse(userCredential.user!.photoURL!));
        final request = await response.close();
        final bytes = await request.fold<List<int>>([], (acc, chunk) => acc..addAll(chunk));
        encodedImage = base64Encode(bytes);
      }

      final user = UserModel(
        uid: userCredential.user!.uid,
        name: userCredential.user!.displayName ?? 'No name',
        email: userCredential.user!.email ?? '',
        profilePicture: encodedImage,
      );

      await _saveUserToFirestore(user, 3);
      return userCredential;
    } catch (e) {
      debugPrint('Error in Google sign in: $e');
      if (e is PlatformException) {
        switch (e.code) {
          case 'sign_in_failed':
            throw Exception('Google Sign-In failed. Please check your internet connection and try again.');
          case 'network_error':
            throw Exception('Network error occurred. Please check your internet connection.');
          default:
            throw Exception('Google Sign-In error: ${e.message}');
        }
      }
      throw Exception('Failed to sign in with Google: ${e.toString()}');
    }
  }

  Future<void> signOut() async {
    await Future.wait([
      _auth.signOut(),
      _googleSignIn.signOut(),
    ]);
  }

  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      debugPrint('Error sending password reset email: $e');
      rethrow;
    }
  }

  Future<UserModel?> getUserData(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        debugPrint('User data fetched: ${doc.data()}');
        return UserModel.fromMap(doc.data()!);
      } else {
        debugPrint('User document does not exist');
        return null;
      }
    } catch (e) {
      debugPrint('Error getting user data: $e');
      return null;
    }
  }

  User? get currentUser => _auth.currentUser;
}