import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:kuudere/notification_page.dart';
import 'package:kuudere/profile.dart';
import 'package:kuudere/services/auth_service.dart';
import 'package:kuudere/services/realtime_service.dart';
import 'dart:convert';
import 'dart:ui';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'watch_anime.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'data.dart';

class AnimeDetails {
  final String id;
  final String english;
  final String romaji;
  final String native;
  final String ageRating;
  final double? malScore;
  final int averageScore;
  final int duration;
  final List<String> genres;
  final String cover;
  final String banner;
  final String season;
  final String startDate;
  final String status;
  final List<String> synonyms;
  final List<String> studios;
  final String type;
  final int year;
  final int epCount;
  final int subbedCount;
  final int dubbedCount;
  final String description;
  final bool inWatchlist;
  final String views;
  final String likes;
  final String? folder;

  AnimeDetails({
    required this.id,
    required this.english,
    required this.romaji,
    required this.native,
    required this.ageRating,
    this.malScore,
    required this.averageScore,
    required this.duration,
    required this.genres,
    required this.cover,
    required this.banner,
    required this.season,
    required this.startDate,
    required this.status,
    required this.synonyms,
    required this.studios,
    required this.type,
    required this.year,
    required this.epCount,
    required this.subbedCount,
    required this.dubbedCount,
    required this.description,
    required this.inWatchlist,
    required this.views,
    required this.likes,
    this.folder,
  });

  factory AnimeDetails.fromJson(Map<String, dynamic> json) {
    final data = json['data'];

    if (data == null) {
      throw Exception("Invalid data: 'data' field is null");
    }

    return AnimeDetails(
      id: data['id'] ?? '',
      english: data['english'] ?? 'Unknown',
      romaji: data['romaji'] ?? 'Unknown',
      native: data['native'] ?? 'Unknown',
      ageRating: data['ageRating'] ?? 'Unknown',
      malScore: (data['malScore'] != null) ? data['malScore'].toDouble() : null,
      averageScore: data['averageScore'] ?? 0,
      duration: data['duration'] ?? 0,
      genres: data['genres'] != null ? List<String>.from(data['genres']) : [],
      cover: data['cover'] ?? '',
      banner: data['banner'] ?? '',
      season: data['season'] ?? 'Unknown',
      startDate: data['startDate'] ?? 'Unknown',
      status: data['status'] ?? 'Unknown',
      synonyms:
          data['synonyms'] != null ? List<String>.from(data['synonyms']) : [],
      studios:
          data['studios'] != null ? List<String>.from(data['studios']) : [],
      type: data['type'] ?? 'Unknown',
      year: data['year'] ?? 0,
      epCount: data['epCount'] ?? 0,
      subbedCount: data['subbedCount'] ?? 0,
      dubbedCount: data['dubbedCount'] ?? 0,
      description: data['description'] ?? 'No description available.',
      inWatchlist: data['in_watchlist'] ?? false,
      views: data['views'] ?? '0',
      likes: data['likes'] ?? '0',
      folder: data['folder'],
    );
  }
}

class AnimeInfoScreen extends StatefulWidget {
  final String animeId;

  const AnimeInfoScreen({Key? key, required this.animeId}) : super(key: key);

  @override
  _AnimeInfoScreenState createState() => _AnimeInfoScreenState();
}

class _AnimeInfoScreenState extends State<AnimeInfoScreen> {
  late Future<AnimeDetails> _animeDetails;
  bool isLoading = false;
  String notificationCount = '0';

  final authService = AuthService();
  final RealtimeService _realtimeService = RealtimeService();

  @override
  void initState() {
    super.initState();
    _realtimeService.joinRoom("/watch/${widget.animeId}/");
    fetchNotificationCount();
    _animeDetails = fetchAnimeDetails(widget.animeId);
  }

  Future<AnimeDetails> fetchAnimeDetails(String id) async {
    final authService = AuthService();
    final url = Uri.parse('https://kuudere.to/anime/$id');

    print('Fetching anime details from URL: $url');

    try {
      final sessionInfo = await authService.getStoredSession();

      if (sessionInfo == null) {
        throw Exception('No session information found.');
      }

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

      print('Response status code: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        return AnimeDetails.fromJson(json.decode(response.body));
      } else {
        throw Exception(
            'Failed to load anime details. Status code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching anime details: $e');
      throw Exception('Failed to load anime details: $e');
    }
  }

  Future<void> fetchNotificationCount() async {
    try {
      final sessionInfo = await authService.getStoredSession();
      if (sessionInfo != null) {
        final url =
            Uri.parse('https://kuudere.to/api/notifications/count');
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

  Future<void> _updateWatchlistStatus(
      AnimeDetails anime, String newStatus) async {
    setState(() {
      isLoading = true;
    });

    final authService = AuthService();
    final sessionInfo = await authService.getStoredSession();

    if (sessionInfo == null) {
      setState(() {
        isLoading = false;
      });
      return;
    }

    String encodedStatus = Uri.encodeComponent(newStatus);

    final url = Uri.parse(
        'https://kuudere.to/add-to-watchlist/$encodedStatus/${anime.id}');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          "secret": SECRET,
          "key": sessionInfo.session,
        }),
      );

      if (response.statusCode == 200) {
        setState(() {
          _animeDetails = Future.value(AnimeDetails(
            id: anime.id,
            english: anime.english,
            romaji: anime.romaji,
            native: anime.native,
            ageRating: anime.ageRating,
            malScore: anime.malScore,
            averageScore: anime.averageScore,
            duration: anime.duration,
            genres: anime.genres,
            cover: anime.cover,
            banner: anime.banner,
            season: anime.season,
            startDate: anime.startDate,
            status: anime.status,
            synonyms: anime.synonyms,
            studios: anime.studios,
            type: anime.type,
            year: anime.year,
            epCount: anime.epCount,
            subbedCount: anime.subbedCount,
            dubbedCount: anime.dubbedCount,
            description: anime.description,
            inWatchlist: newStatus != 'Remove',
            views: anime.views,
            likes: anime.likes,
            folder: newStatus != 'Remove' ? newStatus : null,
          ));
          isLoading = false;
        });
      } else {
        print(
            'Failed to update watchlist. Status code: ${response.statusCode}');
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error updating watchlist: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  Widget _buildWatchlistButton(AnimeDetails anime) {
    return PopupMenuButton<String>(
      onSelected: (String result) {
        _updateWatchlistStatus(anime, result);
      },
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        ...<String>[
          'Watching',
          'On Hold',
          'Plan To Watch',
          'Dropped',
          'Completed'
        ].map(
          (String value) => PopupMenuItem<String>(
            value: value,
            child: Row(
              children: [
                Text(value),
                if (anime.folder == value) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.check, color: Colors.green, size: 16),
                ],
              ],
            ),
          ),
        ),
        const PopupMenuItem<String>(
          value: 'Remove',
          child: Text('Remove'),
        ),
      ],
      child: OutlinedButton.icon(
        icon: Icon(
          anime.inWatchlist ? Icons.bookmark : Icons.bookmark_border,
          color: Colors.red,
        ),
        label: Text(
          anime.inWatchlist
              ? (anime.folder ?? 'In Watchlist')
              : 'Add to Watchlist',
          style: const TextStyle(color: Colors.red),
        ),
        onPressed: null,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Colors.red),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          backgroundColor:
              anime.inWatchlist ? Colors.red.withOpacity(0.1) : null,
        ),
      ),
    );
  }

  Widget _buildBannerImage(String bannerUrl, {required double height}) {
    if (bannerUrl.toLowerCase().endsWith('.svg')) {
      return SvgPicture.network(
        bannerUrl,
        height: height,
        width: double.infinity,
        fit: BoxFit.cover,
        placeholderBuilder: (BuildContext context) => _buildPlaceholder(height),
        errorBuilder:
            (BuildContext context, Object exception, StackTrace? stackTrace) {
          print('Error loading SVG: $exception');
          return _buildPlaceholder(height);
        },
      );
    } else {
      return Image.network(
        bannerUrl,
        height: height,
        width: double.infinity,
        fit: BoxFit.cover,
        loadingBuilder: (BuildContext context, Widget child,
            ImageChunkEvent? loadingProgress) {
          if (loadingProgress == null) return child;
          return _buildPlaceholder(height);
        },
        errorBuilder:
            (BuildContext context, Object error, StackTrace? stackTrace) {
          print('Error loading image: $error');
          return _buildPlaceholder(height);
        },
      );
    }
  }

  Widget _buildPlaceholder(double height) {
    return Container(
      height: height,
      color: Colors.grey[800],
      child: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget _buildMobileLayout(AnimeDetails anime) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Stack(
            children: [
              _buildBannerImage(anime.banner, height: 300),
              Container(
                height: 300,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.7),
                      Colors.black,
                    ],
                    stops: const [0.0, 0.7, 1.0],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 200, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            anime.cover,
                            height: 180,
                            width: 120,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                anime.english,
                                maxLines: 2,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(Icons.remove_red_eye,
                                      size: 16, color: Colors.grey[400]),
                                  const SizedBox(width: 4),
                                  Text(
                                    anime.views,
                                    style: TextStyle(
                                        color: Colors.grey[400], fontSize: 14),
                                  ),
                                  const SizedBox(width: 16),
                                  Icon(Icons.favorite,
                                      size: 16, color: Colors.grey[400]),
                                  const SizedBox(width: 4),
                                  Text(
                                    anime.likes,
                                    style: TextStyle(
                                        color: Colors.grey[400], fontSize: 14),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  anime.status,
                                  style: const TextStyle(
                                    color: Colors.green,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        if (anime.subbedCount > 0)
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.play_arrow),
                              label: const Text('Watch Now'),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        WatchAnimeScreen(id: anime.id),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                              ),
                            ),
                          ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildWatchlistButton(anime),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      anime.description,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Genres',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: anime.genres
                          .map(
                            (genre) => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.grey[900],
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                genre,
                                style: const TextStyle(color: Colors.white70),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Studios',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: anime.studios
                          .map(
                            (studio) => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.grey[900],
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                studio,
                                style: const TextStyle(color: Colors.white70),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopLayout(AnimeDetails anime) {
    return SingleChildScrollView(
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              _buildBannerImage(anime.banner, height: 500),
              Container(
                height: 500,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.9),
                    ],
                    stops: const [0.0, 0.8],
                  ),
                ),
              ),
              Positioned(
                top: 300,
                left: 40,
                right: 40,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          anime.cover,
                          height: 280,
                          width: 200,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              anime.english,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.remove_red_eye,
                                        size: 16, color: Colors.grey[400]),
                                    const SizedBox(width: 4),
                                    Text(
                                      anime.views,
                                      style: TextStyle(
                                        color: Colors.grey[400],
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 16),
                                Row(
                                  children: [
                                    Icon(Icons.favorite,
                                        size: 16, color: Colors.grey[400]),
                                    const SizedBox(width: 4),
                                    Text(
                                      anime.likes,
                                      style: TextStyle(
                                        color: Colors.grey[400],
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 16),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    anime.status,
                                    style: const TextStyle(
                                      color: Colors.green,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            Row(
                              children: [
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.play_arrow),
                                  label: const Text('Watch Now'),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => WatchAnimeScreen(
                                            id: anime.id, episodeNumber: 1),
                                      ),
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 12,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                _buildWatchlistButton(anime),
                              ],
                            ),
                            const SizedBox(height: 24),
                            Text(
                              anime.description,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Genres',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: anime.genres
                                            .map(
                                              (genre) => Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 12,
                                                  vertical: 6,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.grey[900],
                                                  borderRadius:
                                                      BorderRadius.circular(16),
                                                ),
                                                child: Text(
                                                  genre,
                                                  style: const TextStyle(
                                                    color: Colors.white70,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ),
                                            )
                                            .toList(),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 24),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Studios',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: anime.studios
                                            .map(
                                              (studio) => Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 12,
                                                  vertical: 6,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.grey[900],
                                                  borderRadius:
                                                      BorderRadius.circular(16),
                                                ),
                                                child: Text(
                                                  studio,
                                                  style: const TextStyle(
                                                    color: Colors.white70,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ),
                                            )
                                            .toList(),
                                      ),
                                    ],
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
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 1024;

    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0B),
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: AppBar(
              backgroundColor: Colors.black.withOpacity(0.2),
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
              title: Image.network(
                'https://kuudere.to/static/logo.png',
                height: 20,
                fit: BoxFit.contain,
              ),
              actions: [
                Padding(
                  padding: EdgeInsets.zero,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.notifications_outlined,
                            color: Colors.white, size: 30),
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
                  icon: const Icon(Icons.account_circle,
                      color: Colors.white, size: 30),
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
          ),
        ),
      ),
      body: Stack(
        children: [
          FutureBuilder<AnimeDetails>(
            future: _animeDetails,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(
                  child: LoadingAnimationWidget.threeArchedCircle(
                    color: Colors.red,
                    size: 50,
                  ),
                );
              } else if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Error: ${snapshot.error}',
                    style: const TextStyle(color: Colors.white),
                  ),
                );
              } else if (snapshot.hasData) {
                return isDesktop
                    ? _buildDesktopLayout(snapshot.data!)
                    : _buildMobileLayout(snapshot.data!);
              } else {
                return const Center(
                  child: Text(
                    'No data available',
                    style: TextStyle(color: Colors.white),
                  ),
                );
              }
            },
          ),
          if (isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: Center(
                child: LoadingAnimationWidget.threeArchedCircle(
                  color: Colors.red,
                  size: 50,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
