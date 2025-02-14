import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:kuudere/history_tab.dart';
import 'package:kuudere/profile.dart';
import 'package:kuudere/contact_page.dart';
import 'package:kuudere/auth_screen.dart';
import 'dart:convert';
import 'package:kuudere/services/auth_service.dart';
import 'package:kuudere/services/realtime_service.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'data.dart';

class SettingsTab extends StatefulWidget {
  final VoidCallback onWatchlistTap;

  const SettingsTab({Key? key, required this.onWatchlistTap}) : super(key: key);

  @override
  _SettingsTabState createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  final authService = AuthService();
  final storage = FlutterSecureStorage();
  bool isLoading = true;
  bool isLoggingOut = false;
  String username = '';
  String email = '';
  String joinedDate = '';
  bool isVerified = false;
  final RealtimeService _realtimeService = RealtimeService();

  @override
  void initState() {
    super.initState();
    _realtimeService.joinRoom("profile");
    _fetchProfileData();
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
            username = data['username'];
            email = data['email'];
            joinedDate = data['joined'];
            isVerified = data['verified'];
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

  Future<void> _logout() async {
    setState(() {
      isLoggingOut = true;
    });

    try {
      final sessionInfo = await authService.getStoredSession();
      if (sessionInfo != null) {
        final url = Uri.parse('https://kuudere.to/logout');
        final response = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            "secret": SECRET,
            "key": sessionInfo.session,
            "sessionId": sessionInfo.sessionId,
          }),
        );

        if (response.statusCode == 200) {
          // Clear secure storage
          await storage.deleteAll();

          // Navigate to AuthScreen
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => AuthScreen()),
            (Route<dynamic> route) => false,
          );
        } else {
          throw Exception('Failed to logout');
        }
      }
    } catch (e) {
      print('Error logging out: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to logout. Please try again.')),
      );
    } finally {
      setState(() {
        isLoggingOut = false;
      });
    }
  }

  Widget _buildProfileSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Settings',
            style: TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          isLoading
              ? Center(
                  child: LoadingAnimationWidget.threeArchedCircle(
                    color: Colors.red,
                    size: 50,
                  ),
                )
              : Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                username,
                                style: TextStyle(
                                  color: Colors.yellow[400],
                                  fontSize: 24,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (isVerified)
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
                          const SizedBox(height: 4),
                          Text(
                            email,
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Joined ${_formatJoinedDate(joinedDate)}',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.purple[100],
                      child: const Icon(
                        Icons.person,
                        size: 30,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
        ],
      ),
    );
  }

  String _formatJoinedDate(String dateString) {
    if (dateString.isEmpty) return '';
    try {
      final date = DateTime.parse(dateString);
      final month = [
        'January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December'
      ][date.month - 1];
      return '$month ${date.day}, ${date.year}';
    } catch (e) {
      return dateString;
    }
  }

  Widget _buildActionButtons(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildActionButton(
            context,
            Icons.person,
            'My profile',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => ProfileEditPage()),
            ),
          ),
          const SizedBox(width: 8),
          _buildActionButton(
            context,
            Icons.bookmark,
            'Watch List',
            onTap: widget.onWatchlistTap,
          ),
          const SizedBox(width: 8),
          _buildActionButton(context,
           Icons.history,
           'History',
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => HistoryTab()),
            ),
           ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    IconData icon,
    String label, {
    VoidCallback? onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Card(
          margin: EdgeInsets.zero,
          color: const Color(0xFF2A2A2A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              children: [
                Icon(icon, color: Colors.white, size: 24),
                const SizedBox(height: 8),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItem(IconData icon, String title, {bool comingSoon = false}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(icon, color: Colors.white),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
          ),
        ),
        trailing: comingSoon
            ? Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Coming Soon',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            : const Icon(
                Icons.chevron_right,
                color: Colors.white,
              ),
        onTap: () {
          if (title == 'Contact') {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ContactPage(buildMenuItem: _buildMenuItem),
              ),
            );
          } else if (!comingSoon) {
            // Handle other menu items...
          }
        },
      ),
    );
  }

  Widget _buildLogoutButton() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(
          color: Colors.red.withOpacity(0.5),
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoggingOut ? null : _logout,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            width: double.infinity,
            alignment: Alignment.center,
            child: isLoggingOut
                ? LoadingAnimationWidget.threeArchedCircle(
                    color: Colors.red,
                    size: 24,
                  )
                : const Text(
                    'Log out',
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: ListView(
          children: [
            _buildProfileSection(),
            const SizedBox(height: 16),
            _buildActionButtons(context),
            const SizedBox(height: 24),
            _buildMenuItem(Icons.settings, 'General', comingSoon: true),
            _buildMenuItem(Icons.palette, 'User interface', comingSoon: true),
            _buildMenuItem(Icons.mail_outline, 'Contact'),
            _buildMenuItem(Icons.tv, 'TV Login', comingSoon: true),
            const SizedBox(height: 16),
            _buildLogoutButton(),
          ],
        ),
      ),
    );
  }
}

