import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:kuudere/services/realtime_service.dart';
import 'package:kuudere/watch_anime.dart';
import 'dart:convert';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:kuudere/services/auth_service.dart';
import 'package:kuudere/anime_info.dart';
import 'data.dart';

class HistoryTab extends StatefulWidget {
  const HistoryTab({Key? key}) : super(key: key);

  @override
  _HistoryTabState createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab> {
  final authService = AuthService();
  List<HistoryItem> historyList = [];
  int currentPage = 1;
  int totalPages = 1;
  bool isLoading = false;
  ScrollController _scrollController = ScrollController();
  final RealtimeService _realtimeService = RealtimeService();


  @override
  void initState() {
    _realtimeService.joinRoom("profile");
    super.initState();
    fetchHistory();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels == _scrollController.position.maxScrollExtent) {
      if (currentPage < totalPages && !isLoading) {
        fetchHistory(page: currentPage + 1);
      }
    }
  }

  Future<void> fetchHistory({int page = 1}) async {
    if (isLoading) return;

    setState(() {
      isLoading = true;
    });

    final url = Uri.parse('https://kuudere.to/api/continue-watching?page=$page');

    try {
      final sessionInfo = await authService.getStoredSession();
      if (sessionInfo != null) {
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
            if (page == 1) {
              historyList = (data['data'] as List).map((item) => HistoryItem.fromJson(item)).toList();
            } else {
              historyList.addAll((data['data'] as List).map((item) => HistoryItem.fromJson(item)).toList());
            }
            currentPage = data['current_page'];
            totalPages = data['total_pages'];
            isLoading = false;
          });
        } else {
          throw Exception('Failed to load history');
        }
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      print('Error fetching history: $e');
    }
  }

  Widget _buildHistoryList() {
    if (historyList.isEmpty && !isLoading) {
      return Expanded(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.movie_filter, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'No history yet',
                style: TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'Start watching to see your history',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return Expanded(
      child: ListView.builder(
        controller: _scrollController,
        itemCount: historyList.length + (isLoading ? 1 : 0),
        itemBuilder: (context, index) {
          if (index < historyList.length) {
            return HistoryCard(item: historyList[index]);
          } else {
            return Center(
              child: LoadingAnimationWidget.threeArchedCircle(
                color: Colors.red,
                size: 50,
              ),
            );
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Continue Watching',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.search, color: Colors.white),
            onPressed: () {
              // Implement search functionality
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildHistoryList(),
          ],
        ),
      ),
    );
  }
}

class HistoryCard extends StatelessWidget {
  final HistoryItem item;

  const HistoryCard({Key? key, required this.item}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        final uri = Uri.parse(item.link);
        final lang = uri.queryParameters['lang'];
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => WatchAnimeScreen(id: item.link.split('/')[2], episodeNumber: item.episode,lang: lang,),
          ),
        );
      },
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                bottomLeft: Radius.circular(12),
              ),
              child: Image.network(
                item.thumbnail,
                width: 100,
                height: 150,
                fit: BoxFit.cover,
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Episode ${item.episode}',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Progress: ${item.progress} / ${item.duration}',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: _calculateProgress(item.progress, item.duration),
                      backgroundColor: Colors.grey[700],
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _calculateProgress(String progress, String duration) {
    List<int> progressParts = progress.split(':').map(int.parse).toList();
    List<int> durationParts = duration.split(':').map(int.parse).toList();

    int progressSeconds = progressParts[0] * 60 + progressParts[1];
    int durationSeconds = durationParts[0] * 60 + durationParts[1];

    return progressSeconds / durationSeconds;
  }
}

class HistoryItem {
  final String duration;
  final int episode;
  final String link;
  final String progress;
  final String thumbnail;
  final String title;

  HistoryItem({
    required this.duration,
    required this.episode,
    required this.link,
    required this.progress,
    required this.thumbnail,
    required this.title,
  });

  factory HistoryItem.fromJson(Map<String, dynamic> json) {
    return HistoryItem(
      duration: json['duration'],
      episode: json['episode'],
      link: json['link'],
      progress: json['progress'],
      thumbnail: json['thumbnail'],
      title: json['title'],
    );
  }
}

