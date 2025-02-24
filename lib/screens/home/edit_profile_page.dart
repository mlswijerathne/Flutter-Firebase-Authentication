import 'dart:convert';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../models/user_model.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  _EditProfilePageState createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late String _name;
  File? _newProfilePicture;
  bool _isLoading = false;

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _newProfilePicture = File(image.path);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.read<AuthService>();
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Profile'),
        actions: [
          IconButton(
            icon: Icon(Icons.save),
            onPressed: () => _updateProfile(currentUser!.uid),
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
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final user = snapshot.data;
                if (user == null) {
                  return Center(child: Text('No user data found'));
                }

                _name = user.name;

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
                  padding: EdgeInsets.all(16.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: _pickImage,
                          child: CircleAvatar(
                            radius: 50,
                            backgroundImage: _newProfilePicture != null
                                ? FileImage(_newProfilePicture!)
                                : profileImage,
                            child: (_newProfilePicture == null && profileImage == null)
                                ? Icon(Icons.add_a_photo, size: 50)
                                : null,
                          ),
                        ),
                        SizedBox(height: 20),
                        TextFormField(
                          initialValue: user.name,
                          decoration: InputDecoration(
                            labelText: 'Name',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) =>
                              value?.isEmpty ?? true ? 'Enter a name' : null,
                          onSaved: (value) => _name = value ?? '',
                        ),
                        SizedBox(height: 20),
                        _isLoading
                            ? CircularProgressIndicator()
                            : ElevatedButton(
                                onPressed: () => _updateProfile(currentUser.uid),
                                child: Text('Save Changes'),
                              ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Future<void> _updateProfile(String uid) async {
    if (_formKey.currentState?.validate() ?? false) {
      _formKey.currentState?.save();
      setState(() => _isLoading = true);
      try {
        await context.read<AuthService>().updateUserProfile(
              uid,
              _name,
              _newProfilePicture,
            );
        Navigator.pop(context);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }
}