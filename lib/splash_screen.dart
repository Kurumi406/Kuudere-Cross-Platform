import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:kuudere/services/realtime_service.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:kuudere/auth_screen.dart';
import 'package:kuudere/services/auth_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:version/version.dart';
import 'home_screen.dart';
import 'package:version/version.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final String _apiUrl = 'https://kuudere.to/user';
  final String _versionUrl = 'https://kuudere.to/version';
  final authService = AuthService();
  final RealtimeService _realtimeService = RealtimeService();
  
  @override
  void initState() {
    super.initState();
    _realtimeService.joinRoom("/");
    _startSplashSequence();
  }

  Future<void> _startSplashSequence() async {
    await Future.delayed(const Duration(seconds: 3));
    await _checkVersion();
  }



  Future<void> _checkVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = Version.parse(packageInfo.version);
      final buildVersion = int.tryParse(packageInfo.buildNumber) ?? 0;
      final response = await http.get(Uri.parse(_versionUrl));

      if (response.statusCode >= 500) {
        _showUpdateDialog(isServerOffline: true);
        return;
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final apiVersion = Version.parse(data['version']);
        final apiBuildVersion = int.tryParse(data['build'].toString()) ?? 0;

        // Proper version comparison
        if (apiVersion > currentVersion || apiBuildVersion > buildVersion) {
          _showUpdateDialog(data: data);
          return;
        }

        await _checkSession();
      } else {
        debugPrint('Version check failed: ${response.statusCode}');
        await _checkSession();
      }
    } catch (e) {
      debugPrint('Version check error: $e');
      _showUpdateDialog(isServerOffline: true);
    }
  }

  void _showUpdateDialog({Map<String, dynamic>? data, bool isServerOffline = false}) {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (context) => WillPopScope(
        onWillPop: () async => false,
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1A1A1A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[600],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Icon(
                                isServerOffline ? Icons.cloud_off : Icons.system_update,
                                color: const Color.fromARGB(255, 255, 0, 0),
                                size: 24,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Text(
                            isServerOffline ? 'System Failure' : 'New Update Is Available',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'Inter',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Text(
                        isServerOffline ? 'Affected Version' : "What's new?",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          fontFamily: 'Inter',
                        ),
                      ),
                      const SizedBox(height: 8),
                      FutureBuilder<PackageInfo>(
                        future: PackageInfo.fromPlatform(),
                        builder: (context, snapshot) {
                          final version = snapshot.data?.version ?? 'Unknown';
                          final buildNumber = snapshot.data?.buildNumber ?? 'Unknown';
                          return Text(
                            isServerOffline 
                              ? 'Version $version Build $buildNumber' 
                              : 'Version ${data?['version'] ?? version} Build ${data?['build'] ?? buildNumber}',
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 16,
                              fontFamily: 'Inter',
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      if (isServerOffline)
                        _buildBulletPoint('The server is currently unavailable.')
                      else if (data != null && data['Message'] != null)
                        ...List<Widget>.from(
                          (data['Message'] as List).map(
                            (message) => _buildBulletPoint(message.toString()),
                          ),
                        ),
                      const SizedBox(height: 16),
                      if (!isServerOffline) ...[
                        Text(
                          '* If automatic update method doesn\'t work for you then you can also update yourself by visiting',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 14,
                            height: 1.4,
                            fontFamily: 'Inter',
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'https://kuudere.to/download',
                          style: TextStyle(
                            color: Color.fromARGB(255, 255, 0, 0),
                            fontSize: 14,
                            fontFamily: 'Inter',
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      _buildButton(
                        text: isServerOffline ? 'Close App' : 'Update now',
                        onPressed: isServerOffline
                            ? () => SystemNavigator.pop()
                            : () async {
                                const updateUrl = 'https://kuudere.to/download';
                                if (await canLaunch(updateUrl)) {
                                  await launch(updateUrl);
                                }
                              },
                        isPrimary: true,
                      ),
                      if (!isServerOffline) ...[
                        const SizedBox(height: 12),
                        _buildButton(
                          text: 'Skip this version',
                          onPressed: () => SystemNavigator.pop(),
                          isPrimary: false,
                        ),
                      ],
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '•  ',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 16,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 16,
                height: 1.4,
                fontFamily: 'Inter',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildButton({
    required String text,
    required VoidCallback onPressed,
    required bool isPrimary,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isPrimary ? const Color.fromARGB(255, 255, 30, 0) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: !isPrimary
              ? Border.all(color: Colors.white.withOpacity(0.1), width: 1)
              : null,
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isPrimary ? const Color.fromARGB(255, 255, 255, 255) : Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            fontFamily: 'Inter',
          ),
        ),
      ),
    );
  }

  Future<void> _checkSession() async {
    try {
      final sessionInfo = await authService.getStoredSession();
      if (sessionInfo != null) {
        final response = await http.post(
          Uri.parse(_apiUrl),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'key': sessionInfo.session}),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['success']) {
            _navigateToHome();
            return;
          }
        }
        
        if (authService.isSessionExpired(sessionInfo)) {
          _navigateToAuth();
          return;
        }
      }
      _navigateToAuth();
    } catch (e) {
      debugPrint('Session check error: $e');
      _navigateToAuth();
    }
  }

  void _navigateToAuth() {
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const AuthScreen()),
      );
    }
  }

  void _navigateToHome() {
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        backgroundColor: const Color(0xFF0B0B0B),
        body: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.max,
            children: [
              Flexible(
                child: Align(
                  alignment: AlignmentDirectional.center,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: CachedNetworkImage(
                      imageUrl: 'https://kuudere.to/static/favicon.png',
                      width: 150,
                      height: 150,
                      fit: BoxFit.fill,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Kuudere Official',
                style: TextStyle(
                  fontFamily: 'Inter',
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}