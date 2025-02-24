import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../models/user_model.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Future<void> _handleLogout() async {
    final authService = context.read<AuthService>();
    try {
      await authService.signOut();
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/sign-in',
        (route) => false,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error logging out: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.read<AuthService>();
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text('Profile'),
        actions: [
          IconButton(
            icon: Icon(Icons.edit),
            onPressed: () {
              Navigator.pushNamed(context, '/edit-profile').then((_) {
                // Refresh the user data when returning from edit profile
                setState(() {});
              });
            },
          ),
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: _handleLogout,
          ),
        ],
      ),
      body: currentUser == null
          ? Center(child: CircularProgressIndicator())
          : FutureBuilder<UserModel?>(
              future: authService.getUserData(currentUser.uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error: ${snapshot.error}'),
                  );
                }

                final user = snapshot.data;
                if (user == null) {
                  return Center(child: Text('No user data found'));
                }

                ImageProvider? profileImage;
                if (user.profilePicture != null && user.profilePicture!.isNotEmpty) {
                  try {
                    final bytes = base64Decode(user.profilePicture!);
                    profileImage = MemoryImage(bytes);
                  } catch (e) {
                    debugPrint('Error decoding profile picture: $e');
                  }
                }

                return SingleChildScrollView(
                  child: Column(
                    children: [
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Color(0xFFFFFFFF),
                        ),
                        child: Column(
                          children: [
                            const SizedBox(height: 20),
                            CircleAvatar(
                              radius: 50,
                              backgroundColor: Colors.grey[200],
                              backgroundImage: profileImage,
                              child: profileImage == null
                                  ? Icon(Icons.person, size: 50, color: Colors.grey[400])
                                  : null,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              user.name,
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              user.email,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            ListTile(
                              leading: Icon(Icons.edit, color: Theme.of(context).primaryColor),
                              title: Text('Edit Profile'),
                              trailing: Icon(Icons.arrow_forward_ios, size: 16),
                              onTap: () => Navigator.pushNamed(context, '/edit-profile').then((_) {
                                // Refresh the user data when returning from edit profile
                                setState(() {});
                              }),
                            ),
                            Divider(),
                            ListTile(
                              leading: Icon(Icons.logout, color: Colors.red),
                              title: Text('Logout'),
                              trailing: Icon(Icons.arrow_forward_ios, size: 16),
                              onTap: _handleLogout,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}