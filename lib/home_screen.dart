import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:kuudere/history_tab.dart';
import 'package:kuudere/notification_page.dart';
import 'package:kuudere/services/realtime_service.dart';
import 'package:kuudere/watch_anime.dart';
import 'schedule_tab.dart';
import 'search_tab.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'anime_info.dart';
import 'package:kuudere/services/auth_service.dart';
import 'profile.dart';
import 'settings_tab.dart';
import 'watch_list_tab.dart';
import 'data.dart';

// Model class for anime data
class AnimeItem {
  final String id;
  final String title;
  final String english;
  final int epCount;
  final int subbedCount;
  final int dubbedCount;
  final String imageUrl;
  final String? bannerUrl;
  final String description;
  final double? malScore;
  final List<String> genres;
  final String type;

  AnimeItem({
    required this.id,
    required this.title,
    required this.english,
    required this.epCount,
    required this.subbedCount,
    required this.dubbedCount,
    required this.imageUrl,
    this.bannerUrl,
    required this.description,
    this.malScore,
    required this.genres,
    required this.type,
  });

  factory AnimeItem.fromJson(Map<String, dynamic> json) {
    return AnimeItem(
      id: json['id'] ?? '',
      title: json['english'] ?? json['romaji'] ?? '',
      english: json['english'] ?? '',
      epCount: json['epCount'] ?? 0,
      subbedCount: json['subbedCount'] ?? 0,
      dubbedCount: json['dubbedCount'] ?? 0,
      imageUrl: json['cover'] ?? '',
      bannerUrl: json['banner'],
      description: json['description'] ?? '',
      malScore: json['malScore']?.toDouble(),
      genres: List<String>.from(json['genres'] ?? []),
      type: json['type'] ?? '',
    );
  }
}

class ContinueWatchingItem {
  final String duration;
  final int episode;
  final String link;
  final String progress;
  final String thumbnail;
  final String title;

  ContinueWatchingItem({
    required this.duration,
    required this.episode,
    required this.link,
    required this.progress,
    required this.thumbnail,
    required this.title,
  });

  factory ContinueWatchingItem.fromJson(Map<String, dynamic> json) {
    return ContinueWatchingItem(
      duration: json['duration'] ?? '',
      episode: json['episode'] ?? 0,
      link: json['link'] ?? '',
      progress: json['progress'] ?? '',
      thumbnail: json['thumbnail'] ?? '',
      title: json['title'] ?? '',
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 1;
  ScrollController _scrollController = ScrollController();
  double _scrollProgress = 0.0;
  List<ContinueWatchingItem> continueWatching = [];
  List<AnimeItem> topAiring = [];
  List<AnimeItem> latestEpisodes = [];
  List<AnimeItem> newOnSite = [];
  List<AnimeItem> topUpcoming = [];
  bool isLoading = true;
  int ctotal = 0;
  final authService = AuthService();
  String notificationCount = '0';
  final RealtimeService _realtimeService = RealtimeService();

  @override
  void initState() {
    super.initState();
    _realtimeService.joinRoom("home");
    fetchNotificationCount();
    fetchData();
    _scrollController.addListener(() {
      // Calculate scroll progress over first 100 pixels of scroll
      final progress = (_scrollController.offset / 100).clamp(0.0, 1.0);
      if (progress != _scrollProgress) {
        setState(() {
          _scrollProgress = progress;
        });
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> fetchNotificationCount() async {
    try {
      final sessionInfo = await authService.getStoredSession();
      if (sessionInfo != null) {
        final url = Uri.parse('https://kuudere.to/api/notifications/count');
        final response = await http.post(
          url,
          headers: {
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            "secret": SECRET,
            "key": sessionInfo.session,
          }),
        );

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['success']) {
            setState(() {
              notificationCount = data['total'];
            });
          }
        }
      }
    } catch (e) {
      print('Error fetching notification count: $e');
    }
  }

  Color get _appBarColor {
    // Interpolate between transparent and solid color
    return Color.lerp(
      Colors.transparent,
      const Color(0xFF0B0B0B),
      _scrollProgress
    )!;
  }

    double get _appBarElevation {
    // Smoothly increase elevation
      return lerpDouble(0, 4, _scrollProgress)!;
    }

  Future<void> fetchData() async {
    setState(() {
      isLoading = true;
    });

    try {
      final sessionInfo = await authService.getStoredSession();
      if (sessionInfo != null) {
        // Fetch home data
        final homeUrl = Uri.parse('https://kuudere.to/home');
        final homeResponse = await http.post(
          homeUrl,
          headers: {
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            "secret": SECRET,
            "key": sessionInfo.session,
          }),
        );

        // Fetch continue watching data
        final continueWatchingUrl = Uri.parse('https://kuudere.to/api/continue-watching-home');
        final continueWatchingResponse = await http.post(
          continueWatchingUrl,
          headers: {
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            "secret": SECRET,
            "key": sessionInfo.session,
          }),
        );

        if (homeResponse.statusCode == 200 && continueWatchingResponse.statusCode == 200) {
          final homeData = json.decode(homeResponse.body);
          final continueWatchingData = json.decode(continueWatchingResponse.body);

          setState(() {
            topAiring = (homeData['topAired'] as List)
                .map((item) => AnimeItem.fromJson(item))
                .toList();

            latestEpisodes = (homeData['latestEps'] as List)
                .map((item) => AnimeItem.fromJson(item))
                .toList();

            newOnSite = (homeData['lastUpdated'] as List)
                .map((item) => AnimeItem.fromJson(item))
                .toList();

            topUpcoming = (homeData['topUpcoming'] as List)
                .map((item) => AnimeItem.fromJson(item))
                .toList();

            continueWatching = (continueWatchingData as List)
                .map((item) => ContinueWatchingItem.fromJson(item))
                .toList();

            ctotal = continueWatching.length;
            isLoading = false;
          });
        }
      }
    } catch (e) {
      print('Error fetching data: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  void _navigateToWatchlist() {
    setState(() {
      _currentIndex = 3; // Index of the Watchlist tab
    });
  }

  Widget _buildContinueWatchingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Continue Watching',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => HistoryTab()),
                  );
                },
                child: Text(
                  'View more >',
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 220,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: continueWatching.length,
            itemBuilder: (context, index) {
              final item = continueWatching[index];
              return Padding(
                padding: EdgeInsets.only(
                  left: index == 0 ? 16 : 8,
                  right: index == continueWatching.length - 1 ? 16 : 8,
                ),
                child: ContinueWatchingCard(
                  imageUrl: item.thumbnail,
                  title: item.title,
                  episodeNumber: item.episode,
                  currentTime: item.progress,
                  totalDuration: item.duration,
                  link: item.link,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isHomeTab = _currentIndex == 1;
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0B),
      extendBodyBehindAppBar: isHomeTab,
      appBar: AppBar(
        backgroundColor: isHomeTab ? _appBarColor : const Color(0xFF0B0B0B),
        elevation: isHomeTab ? _appBarElevation : 4,
        systemOverlayStyle: SystemUiOverlayStyle.light.copyWith(
          statusBarColor: isHomeTab 
            ? Color.lerp(
                Colors.transparent,
                const Color(0xFF0B0B0B),
                _scrollProgress
              )
            : const Color(0xFF0B0B0B),
        ),
        flexibleSpace: isHomeTab ? AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: 1 - _scrollProgress,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.8 * (1 - _scrollProgress)),
                  Colors.black.withOpacity(0.7 * (1 - _scrollProgress)),
                  Colors.black.withOpacity(0.5 * (1 - _scrollProgress)),
                  Colors.black.withOpacity(0.4 * (1 - _scrollProgress)),
                  Colors.black.withOpacity(0.2 * (1 - _scrollProgress)),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.2, 0.4, 0.6, 0.8, 1.0],
              ),
            ),
          ),
        ) : null,
        title: Row(
          children: [
            Image.network(
              'https://kuudere.to/static/logo.png',
              height: 20,
              fit: BoxFit.contain,
            ),
          ],
        ),
        actions: [
          Padding(
            padding: EdgeInsets.zero,
            child: Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications_outlined, color: Colors.white, size: 30),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => NotificationPage(),
                      ),
                    );
                  },
                ),
                if (notificationCount != '0')
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        notificationCount,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.account_circle, color: Colors.white, size: 30),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProfileEditPage(),
                ),
              );
            },
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          const ScheduleTab(),
          _buildHomeContent(),
          const SearchTab(),
          const WatchListTab(),
          SettingsTab(onWatchlistTap: _navigateToWatchlist),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.black,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.red,
        unselectedItemColor: Colors.grey,
        currentIndex: _currentIndex,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: 'Schedule',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: 'Search',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bookmark_outline),
            label: 'Watchlist',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            label: 'Settings',
          ),
        ],
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
    );
  }

  Widget _buildHomeContent() {
    if (isLoading) {
      return Center(
        child: LoadingAnimationWidget.threeArchedCircle(
          color: Colors.red,
          size: 50,
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: fetchData,
      color: Colors.red,
      child: SingleChildScrollView(
        controller: _scrollController,
        child: Column(
          children: [
            // Hero Carousel
            if (topAiring.isNotEmpty)
              Stack(
                children: [
                  // Top gradient for status bar and app bar area
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: MediaQuery.of(context).padding.top + kToolbarHeight + 40,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withOpacity(0.8),
                            Colors.black.withOpacity(0.6),
                            Colors.black.withOpacity(0.4),
                            Colors.transparent,
                          ],
                          stops: [0.0, 0.3, 0.6, 1.0],
                        ),
                      ),
                    ),
                  ),
                  CarouselSlider(
                    options: CarouselOptions(
                      height: MediaQuery.of(context).size.height * 0.75,
                      viewportFraction: 1.0,
                      enlargeCenterPage: false,
                      autoPlay: true,
                      autoPlayInterval: Duration(seconds: 5),
                      autoPlayAnimationDuration: Duration(milliseconds: 800),
                      autoPlayCurve: Curves.fastOutSlowIn,
                      padEnds: false,
                    ),
                    items: topAiring.map((item) {
                      return Builder(
                        builder: (BuildContext context) {
                          return GestureDetector(
                            onTap: () {
                            },
                            child: Container(
                              width: MediaQuery.of(context).size.width,
                              decoration: BoxDecoration(
                                image: DecorationImage(
                                  image: NetworkImage(item.imageUrl),
                                  fit: BoxFit.cover,
                                ),
                              ),
                              child: Stack(
                                children: [
                                  // Main gradient overlay
                                  Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Colors.black.withOpacity(0.6),
                                          Colors.transparent,
                                          Colors.black.withOpacity(0.3),
                                          Colors.black.withOpacity(0.7),
                                          Colors.black.withOpacity(0.9),
                                          Colors.black,
                                        ],
                                        stops: [0.0, 0.2, 0.4, 0.6, 0.8, 1.0],
                                      ),
                                    ),
                                  ),
                                  // Content
                                  Padding(
                                    padding: EdgeInsets.fromLTRB(
                                      20,
                                      MediaQuery.of(context).padding.top + kToolbarHeight + 40,
                                      20,
                                      20,
                                    ),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Age rating and type tags
                                        Row(
                                          children: [
                                            _buildTag('16+'),
                                            const SizedBox(width: 8),
                                            _buildTag(
                                              '${item.type}'
                                              '${item.subbedCount > 0 ? ' | SUB' : ''}'
                                              '${item.dubbedCount > 0 ? ' | DUB' : ''}',
                                            ),
                                          ],
                                        ),

                                        const SizedBox(height: 12),
                                        // Title
                                        Text(
                                          item.title,
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 28,
                                            fontWeight: FontWeight.bold,
                                            height: 1.2,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 12),
                                        // Description
                                        Text(
                                          item.description,
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(0.9),
                                            fontSize: 14,
                                            height: 1.5,
                                          ),
                                          maxLines: 3,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 20),
                                        // Watch button
                                        Row(
                                          children: [
                                            Expanded(
                                              child: ElevatedButton.icon(
                                                onPressed: () {
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (context) => WatchAnimeScreen(id: item.id),
                                                    ),
                                                  );                                                 
                                                },
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.redAccent,
                                                  padding: EdgeInsets.symmetric(
                                                    vertical: 16,
                                                    horizontal: 24,
                                                  ),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                ),
                                                icon: Icon(Icons.play_arrow, color: Colors.white),
                                                label: Text(
                                                  'Watch Now',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Container(
                                              decoration: BoxDecoration(
                                                border: Border.all(color: Colors.white),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: IconButton(
                                                onPressed: () {
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (context) => AnimeInfoScreen(animeId: item.id),
                                                    ),
                                                  );                                                  
                                                },
                                                icon: Icon(
                                                  Icons.info_outline,
                                                  color: Colors.white,
                                                  size: 24,
                                                ),
                                                style: IconButton.styleFrom(
                                                  padding: EdgeInsets.all(12),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),

            // Continue Watching Section (if ctotal > 0)
            if (ctotal > 0) _buildContinueWatchingSection(),

            // Latest Episodes Section
            _buildResponsiveSection(
              context: context,
              title: 'Latest Episodes',
              items: latestEpisodes,
            ),

            // New On Site Section
            _buildResponsiveSection(
              context: context,
              title: 'New On App',
              items: newOnSite,
            ),

            // Top Upcoming Section
            _buildResponsiveSection(
              context: context,
              title: 'Top Upcoming',
              items: topUpcoming,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResponsiveSection({
    required BuildContext context,
    required String title,
    required List<AnimeItem> items,
  }) {
    final isXlScreen = MediaQuery.of(context).size.width >= 1280;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                    color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              TextButton(
                onPressed: () {},
                child: const Text('View more >',
                    style: TextStyle(color: Colors.grey, fontSize: 14)),
              ),
            ],
          ),
        ),
        SizedBox(
          height: isXlScreen ? 280 : 240,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            itemBuilder: (context, index) => Padding(
              padding: EdgeInsets.only(
                left: index == 0 ? 16 : 8,
                right: index == items.length - 1 ? 16 : 8,
              ),
              child: SizedBox(
                width: isXlScreen ? 200 : 160,
                child: GestureDetector(
                  onTap: () {
                    if (title == 'Latest Episodes') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => WatchAnimeScreen(
                            id: items[index].id,
                            episodeNumber: items[index].epCount,
                            lang: 'sub', // You may need to adjust this based on your data
                          ),
                        ),
                      );
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AnimeInfoScreen(animeId: items[index].id),
                        ),
                      );
                    }
                  },
                  child: AnimeCard(item: items[index]),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 0.5,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class ContinueWatchingCard extends StatefulWidget {
  final String imageUrl;
  final String title;
  final int episodeNumber;
  final String currentTime;
  final String totalDuration;
  final String link;

  const ContinueWatchingCard({
    Key? key,
    required this.imageUrl,
    required this.title,
    required this.episodeNumber,
    required this.currentTime,
    required this.totalDuration,
    required this.link,
  }) : super(key: key);

  @override
  _ContinueWatchingCardState createState() => _ContinueWatchingCardState();
}

class _ContinueWatchingCardState extends State<ContinueWatchingCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: () {
          final uri = Uri.parse(widget.link);
          final lang = uri.queryParameters['lang'];
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => WatchAnimeScreen(
                id: widget.link.split('/')[2],
                episodeNumber: widget.episodeNumber,
                lang: lang,
              ),
            ),
          );
        },
        child: Container(
          width: 280,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 157.5, // 16:9 aspect ratio
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Stack(
                    children: [
                      // Image with scale animation
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        transform: Matrix4.identity()
                          ..scale(_isHovered ? 1.05 : 1.0),
                        child: Image.network(
                          widget.imageUrl,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                        ),
                      ),

                      // Play button overlay
                      AnimatedOpacity(
                        duration: const Duration(milliseconds: 300),
                        opacity: _isHovered ? 1.0 : 0.0,
                        child: Container(
                          color: Colors.black.withOpacity(0.5),
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.play_arrow,
                                color: Colors.grey,
                                size: 24,
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Delete button
                      Positioned(
                        top: 8,
                        right: 8,
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 300),
                          opacity: _isHovered ? 1.0 : 0.0,
                          child: Material(
                            color: Colors.black.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(8),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: () {
                                // Handle delete
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Episode number
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'EP ${widget.episodeNumber}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),

                      // Progress bar
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          height: 4,
                          child: ClipRRect(
                            borderRadius: const BorderRadius.only(
                              bottomLeft: Radius.circular(8),
                              bottomRight: Radius.circular(8),
                            ),
                            child: LinearProgressIndicator(
                              value: _calculateProgress(),
                              backgroundColor: Colors.grey[600],
                              valueColor: const AlwaysStoppedAnimation<Color>(Colors.red),
                            ),
                          ),
                        ),
                      ),

                      // Duration
                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${widget.currentTime}/${widget.totalDuration}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  double _calculateProgress() {
    try {
      List<String> currentParts = widget.currentTime.split(':');
      List<String> totalParts = widget.totalDuration.split(':');

      double currentSeconds = double.parse(currentParts[0]) * 60 + double.parse(currentParts[1]);
      double totalSeconds = double.parse(totalParts[0]) * 60 + double.parse(totalParts[1]);

      return currentSeconds / totalSeconds;
    } catch (e) {
      print('Error calculating progress: $e');
      return 0.0;
    }
  }
}

class AnimeCard extends StatefulWidget {
  final AnimeItem item;

  const AnimeCard({Key? key, required this.item}) : super(key: key);

  @override
  _AnimeCardState createState() => _AnimeCardState();
}

class _AnimeCardState extends State<AnimeCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        transform: Matrix4.identity()..scale(_isHovered ? 1.05 : 1.0),
        child: AspectRatio(
          aspectRatio: 3 / 4,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    widget.item.imageUrl,
                    fit: BoxFit.cover,
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.5),
                          Colors.black.withOpacity(0.8),
                        ],
                        stops: const [0.0, 0.5, 1.0],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 8,
                    top: 8,
                    child: Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        _buildTag(widget.item.type),
                        _buildTag(
                          '${widget.item.epCount}',
                          icon: _buildSvgIcon(_episodesSvg,
                              color: Colors.yellow[400]!),
                        ),
                        _buildTag(
                          '${widget.item.dubbedCount}',
                          icon: _buildSvgIcon(_audioSvg,
                              color: Colors.blue[400]!),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    left: 8,
                    right: 8,
                    bottom: 8,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.item.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Episodes ${widget.item.epCount}',
                          style: TextStyle(
                            color: Colors.grey[300],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTag(String text, {Widget? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            icon,
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSvgIcon(String svgString, {required Color color}) {
    return SvgPicture.string(
      svgString,
      width: 12,
      height: 12,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );
  }
}

// SVG strings remain unchanged
const String _episodesSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
  <rect x="2" y="2" width="20" height="20" rx="2.18" ry="2.18"></rect>
  <line x1="7" y1="2" x2="7" y2="22"></line>
  <line x1="17" y1="2" x2="17" y2="22"></line>
  <line x1="2" y1="12" x2="22" y2="12"></line>
  <line x1="2" y1="7" x2="7" y2="7"></line>
  <line x1="2" y1="17" x2="7" y2="17"></line>
  <line x1="17" y1="17" x2="22" y2="17"></line>
  <line x1="17" y1="7" x2="22" y2="7"></line>
</svg>
''';

const String _audioSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
  <path d="M12 1a3 3 0 0 0-3 3v8a3 3 0 0 0 6 0V4a3 3 0 0 0-3-3z"></path>
  <path d="M19 10v2a7 7 0 0 1-14 0v-2"></path>
  <line x1="12" y1="19" x2="12" y2="23"></line>
  <line x1="8" y1="23" x2="16" y2="23"></line>
</svg>
''';