import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

void main() {
  runApp(MaterialApp(home: VideoPage()));
}

class VideoPage extends StatefulWidget {
  @override
  _VideoPageState createState() => _VideoPageState();
}

class _VideoPageState extends State<VideoPage> {
  InAppWebViewController? webViewController;
  String? extractedM3U8;
  bool isLoading = true;
  bool urlFound = false;

  Future<void> copyToClipboard() async {
    if (extractedM3U8 != null) {
      await Clipboard.setData(ClipboardData(text: extractedM3U8!));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('URL copied to clipboard'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("M3U8 Extractor")),
      body: Stack(
        children: [
          Opacity(
            opacity: 0,
            child: SizedBox(
              height: 1,
              width: 1,
              child: InAppWebView(
                initialUrlRequest: URLRequest(
                  url: WebUri("https://hlswish.com/e/erd0w0owgxjp"),
                ),
                onWebViewCreated: (controller) {
                  webViewController = controller;
                  
                  controller.addJavaScriptHandler(
                    handlerName: 'interceptRequest',
                    callback: (args) {
                      if (!urlFound && !mounted) return;
                      String requestUrl = args[0];
                      if (requestUrl.contains('.m3u8') && !urlFound) {
                        setState(() {
                          extractedM3U8 = requestUrl;
                          isLoading = false;
                          urlFound = true;
                        });
                        print("Extracted M3U8: $extractedM3U8");
                        // Stop further extraction attempts
                        controller.stopLoading();
                      }
                    },
                  );
                },
                onLoadStart: (controller, url) {
                  if (!urlFound) {
                    setState(() {
                      isLoading = true;
                    });
                  }
                },
                onLoadStop: (controller, url) async {
                  if (urlFound) return; // Skip if URL already found

                  await controller.evaluateJavascript(source: """
                    if (!window.extractionInitialized) {
                      window.extractionInitialized = true;
                      
                      (function() {
                        const XHR = XMLHttpRequest.prototype;
                        const open = XHR.open;
                        const send = XHR.send;
                        
                        XHR.open = function(method, url) {
                          this._url = url;
                          return open.apply(this, arguments);
                        };
                        
                        XHR.send = function() {
                          this.onreadystatechange = function() {
                            if (this.readyState === 4 && this._url.includes('.m3u8')) {
                              window.flutter_inappwebview.callHandler('interceptRequest', this._url);
                            }
                          };
                          return send.apply(this, arguments);
                        };
                        
                        const originalFetch = window.fetch;
                        window.fetch = function(input, init) {
                          return originalFetch(input, init).then(response => {
                            const url = typeof input === 'string' ? input : input.url;
                            if (url.includes('.m3u8')) {
                              window.flutter_inappwebview.callHandler('interceptRequest', url);
                            }
                            return response;
                          });
                        };
                      })();
                    }
                  """);

                  if (!urlFound) {
                    await Future.delayed(Duration(seconds: 2));

                    await controller.evaluateJavascript(source: """
                      function simulateClick(element) {
                        if (element) {
                          ['mousedown', 'mouseup', 'click'].forEach(eventType => {
                            element.dispatchEvent(new MouseEvent(eventType, {
                              view: window,
                              bubbles: true,
                              cancelable: true,
                              buttons: 1
                            }));
                          });
                        }
                      }

                      const selectors = [
                        '.plyr__video-wrapper',
                        '.plyr__poster',
                        '.plyr',
                        '#player',
                        '.player',
                        'video',
                        'iframe',
                        '[class*="player"]',
                        '[class*="video"]'
                      ];

                      selectors.forEach(selector => {
                        document.querySelectorAll(selector).forEach(simulateClick);
                      });

                      document.querySelectorAll('*').forEach(element => {
                        if (
                          element.getAttribute('role') === 'button' ||
                          element.tagName === 'BUTTON' ||
                          element.tagName === 'VIDEO' ||
                          element.onclick ||
                          window.getComputedStyle(element).cursor === 'pointer'
                        ) {
                          simulateClick(element);
                        }
                      });
                    """);
                  }
                },
                shouldInterceptRequest: (controller, request) async {
                  if (urlFound) return null;
                  
                  String requestUrl = request.url.toString();
                  if (requestUrl.contains(".m3u8")) {
                    setState(() {
                      extractedM3U8 = requestUrl;
                      isLoading = false;
                      urlFound = true;
                    });
                    controller.stopLoading();
                  }
                  return null;
                },
                shouldOverrideUrlLoading: (controller, navigationAction) async {
                  String url = navigationAction.request.url.toString();
                  if (!url.contains(".m3u8") && url != "https://hlswish.com/e/erd0w0owgxjp") {
                    return NavigationActionPolicy.CANCEL;
                  }
                  return NavigationActionPolicy.ALLOW;
                },
              ),
            ),
          ),
          Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isLoading) ...[
                    CircularProgressIndicator(),
                    SizedBox(height: 20),
                    Text("Extracting M3U8 URL...",
                        style: TextStyle(fontSize: 16))
                  ] else if (extractedM3U8 != null) ...[
                    Text("M3U8 URL Found:",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    SizedBox(height: 10),
                    SelectableText(
                      extractedM3U8!,
                      style: TextStyle(fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: copyToClipboard,
                      icon: Icon(Icons.copy),
                      label: Text("Copy to Clipboard"),
                    ),
                  ] else
                    Text("No M3U8 URL found",
                        style: TextStyle(fontSize: 16, color: Colors.red))
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}