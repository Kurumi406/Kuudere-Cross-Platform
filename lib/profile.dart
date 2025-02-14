import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:kuudere/services/auth_service.dart';
import 'package:kuudere/services/realtime_service.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:intl/intl.dart';
import 'data.dart';

class ProfileEditPage extends StatefulWidget {
  const ProfileEditPage({Key? key}) : super(key: key);

  @override
  _ProfileEditPageState createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends State<ProfileEditPage> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final authService = AuthService();
  bool isLoading = true;
  bool isSaving = false;
  bool showPasswordUpdate = false;

  late TextEditingController _emailController;
  late TextEditingController _usernameController;
  late TextEditingController _currentPasswordController;
  late TextEditingController _newPasswordController;
  late TextEditingController _repeatPasswordController;
  late String _joinedDate;
  late bool _isVerified;

  late AnimationController _expandController;
  late Animation<double> _expandAnimation;
  final RealtimeService _realtimeService = RealtimeService();

  @override
  void initState() {
    super.initState();
    _realtimeService.joinRoom("profile");
    _emailController = TextEditingController();
    _usernameController = TextEditingController();
    _currentPasswordController = TextEditingController();
    _newPasswordController = TextEditingController();
    _repeatPasswordController = TextEditingController();
    _expandController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 300),
    );
    _expandAnimation = CurvedAnimation(
      parent: _expandController,
      curve: Curves.easeInOut,
    );
    _fetchProfileData();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _usernameController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _repeatPasswordController.dispose();
    _expandController.dispose();
    super.dispose();
  }

  Future<void> _fetchProfileData() async {
    setState(() {
      isLoading = true;
    });

    try {
      final sessionInfo = await authService.getStoredSession();
      if (sessionInfo != null) {
        final url = Uri.parse('https://kuudere.to/api/profile');
        final response = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            "secret": SECRET,
            "key": sessionInfo.session,
          }),
        );

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          setState(() {
            _emailController.text = data['email'];
            _usernameController.text = data['username'];
            _joinedDate = data['joined'];
            _isVerified = data['verified'];
            isLoading = false;
          });
        } else {
          throw Exception('Failed to load profile data');
        }
      }
    } catch (e) {
      print('Error fetching profile data: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _saveProfileData() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        isSaving = true;
      });

      try {
        final sessionInfo = await authService.getStoredSession();
        if (sessionInfo != null) {
          final url = Uri.parse('https://kuudere.to/update/profile');
          final body = {
            "secret": SECRET,
            "key": sessionInfo.session,
            "username": _usernameController.text,
          };

          if (showPasswordUpdate) {
            body["oldPassword"] = _currentPasswordController.text;
            body["newPassword"] = _newPasswordController.text;
            body["confirmNewPassword"] = _repeatPasswordController.text;
          }

          final response = await http.post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: json.encode(body),
          );

          if (response.statusCode == 200) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Profile updated successfully')),
            );
            // Clear password fields after successful update
            _currentPasswordController.clear();
            _newPasswordController.clear();
            _repeatPasswordController.clear();
            setState(() {
              showPasswordUpdate = false;
            });
          } else {
            throw Exception('Failed to update profile');
          }
        }
      } catch (e) {
        print('Error updating profile: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update profile')),
        );
      } finally {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('Edit Profile'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: isLoading
          ? Center(
              child: LoadingAnimationWidget.threeArchedCircle(
                color: Colors.red,
                size: 50,
              ),
            )
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildProfileHeader(),
                      SizedBox(height: 24),
                      _buildTextField(
                        controller: _emailController,
                        label: 'Email',
                        enabled: false,
                      ),
                      SizedBox(height: 16),
                      _buildTextField(
                        controller: _usernameController,
                        label: 'Username',
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your username';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 24),
                      _buildUpdatePasswordSection(),
                    ],
                  ),
                ),
              ),
            ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.all(16.0),
        child: _buildSaveButton(),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Row(
      children: [
        CircleAvatar(
          radius: 40,
          backgroundColor: Colors.purple[100],
          child: Icon(
            Icons.person,
            size: 40,
            color: Colors.black54,
          ),
        ),
        SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    _usernameController.text,
                    style: TextStyle(
                      color: Colors.yellow[400],
                      fontSize: 24,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (_isVerified)
                    Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: Icon(
                        Icons.verified,
                        color: Colors.blue,
                        size: 20,
                      ),
                    ),
                ],
              ),
              SizedBox(height: 4),
              Text(
                _emailController.text,
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 16,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Joined ${_formatJoinedDate(_joinedDate)}',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatJoinedDate(String dateString) {
    final date = DateTime.parse(dateString);
    final formatter = DateFormat('MMMM d, yyyy');
    return formatter.format(date);
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    bool enabled = true,
    String? Function(String?)? validator,
    bool obscureText = false,
  }) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      obscureText: obscureText,
      style: TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.grey),
          borderRadius: BorderRadius.circular(8),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.red),
          borderRadius: BorderRadius.circular(8),
        ),
        errorBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.red),
          borderRadius: BorderRadius.circular(8),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.red),
          borderRadius: BorderRadius.circular(8),
        ),
        disabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.grey.shade800),
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      validator: validator,
    );
  }

  void _togglePasswordSection() {
    setState(() {
      showPasswordUpdate = !showPasswordUpdate;
      if (showPasswordUpdate) {
        _expandController.forward();
      } else {
        _expandController.reverse();
      }
    });
  }

  Widget _buildUpdatePasswordSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: _togglePasswordSection,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              children: [
                Icon(
                  Icons.lock,
                  color: Color(0xFFFF0080),
                  size: 20,
                ),
                SizedBox(width: 8),
                Text(
                  'Change password',
                  style: TextStyle(
                    color: Color(0xFFFF0080),
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Spacer(),
                AnimatedRotation(
                  duration: Duration(milliseconds: 300),
                  turns: showPasswordUpdate ? 0.5 : 0,
                  child: Icon(
                    Icons.keyboard_arrow_down,
                    color: Color(0xFFFF0080),
                  ),
                ),
              ],
            ),
          ),
        ),
        SizeTransition(
          sizeFactor: _expandAnimation,
          child: Column(
            children: [
              SizedBox(height: 16),
              _buildTextField(
                controller: _currentPasswordController,
                label: 'Current Password',
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your current password';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              _buildTextField(
                controller: _newPasswordController,
                label: 'New Password',
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a new password';
                  }
                  if (value.length < 8) {
                    return 'Password must be at least 8 characters long';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              _buildTextField(
                controller: _repeatPasswordController,
                label: 'Repeat New Password',
                obscureText: true,
                validator: (value) {
                  if (value != _newPasswordController.text) {
                    return 'Passwords do not match';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isSaving ? null : _saveProfileData,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red,
          padding: EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: isSaving
            ? LoadingAnimationWidget.threeArchedCircle(
                color: Colors.white,
                size: 24,
              )
            : Text(
                'Save Changes',
                style: TextStyle(fontSize: 18),
              ),
      ),
    );
  }
}

