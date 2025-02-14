// video_server_service.dart
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class VideoServerService {
  static final VideoServerService _instance = VideoServerService._internal();
  factory VideoServerService() => _instance;
  VideoServerService._internal();

  final Map<String, String?> _extractedUrls = {};
  
  Future<String?> extractM3U8Url(String serverName, String dataLink) async {
    try {
      // Return cached URL if already extracted
      if (_extractedUrls.containsKey(dataLink)) {
        return _extractedUrls[dataLink];
      }

      String? extractedM3U8;
      
      final HeadlessInAppWebView headlessWebView = HeadlessInAppWebView(
        initialUrlRequest: URLRequest(url: WebUri(dataLink)),
        onLoadStop: (controller, url) {
          controller.addJavaScriptHandler(
            handlerName: "interceptRequest",
            callback: (args) {
              String requestUrl = args[0];
              if (requestUrl.contains(".m3u8") && requestUrl.contains("master")) {
                extractedM3U8 = requestUrl;
              }
            },
          );
        },
        shouldInterceptRequest: (controller, request) async {
          String requestUrl = request.url.toString();
          if (requestUrl.contains(".m3u8") && requestUrl.contains("master")) {
            extractedM3U8 = requestUrl;
          }
          return null;
        },
      );

      await headlessWebView.run();
      
      // Wait for URL extraction with timeout
      int attempts = 0;
      while (extractedM3U8 == null && attempts < 30) {
        await Future.delayed(const Duration(seconds: 1));
        attempts++;
      }

      await headlessWebView.dispose();

      // Only cache if URL was successfully extracted
      if (extractedM3U8 != null) {
        _extractedUrls[dataLink] = extractedM3U8;
      }
      
      return extractedM3U8;
    } catch (e) {
      print('Error extracting M3U8 for $serverName: $e');
      return null;
    }
  }

  void clearCache(String dataLink) {
    _extractedUrls.remove(dataLink);
  }

  void clearAllCache() {
    _extractedUrls.clear();
  }
}