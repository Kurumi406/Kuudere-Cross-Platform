import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:kuudere/services/auth_service.dart';
import 'package:kuudere/services/realtime_service.dart';
import 'package:kuudere/watch_anime.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'data.dart';

class NotificationPage extends StatefulWidget {
  const NotificationPage({Key? key}) : super(key: key);

  @override
  _NotificationPageState createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  final authService = AuthService();
  List<NotificationItem> notifications = [];
  bool isLoading = false;
  bool hasMore = true;
  int currentPage = 1;
  String selectedFilter = 'Anime';
  final List<String> filters = ['Anime', 'Community', 'System'];
  final ScrollController _scrollController = ScrollController();
  bool _isLoadingMore = false;
  final RealtimeService _realtimeService = RealtimeService();

  @override
  void initState() {
    super.initState();
    _realtimeService.joinRoom("home");
    _scrollController.addListener(_onScroll);
    _fetchNotifications();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    if (maxScroll - currentScroll <= 200) {
      if (hasMore && !isLoading && !_isLoadingMore) {
        _loadMoreNotifications();
      }
    }
  }

  Future<void> _loadMoreNotifications() async {
    if (_isLoadingMore || !hasMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final sessionInfo = await authService.getStoredSession();
      if (sessionInfo != null) {
        final endpoint = _getEndpoint();
        final url = Uri.parse('$endpoint?page=${currentPage + 1}');
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
          final newNotifications = (data['notifications'] as List)
              .map((item) => NotificationItem.fromJson(item))
              .toList();
          if (mounted) {
            setState(() {
              notifications.addAll(newNotifications);
              hasMore = data['has_more'] ?? false;
              if (hasMore) {
                currentPage++;
              }
              _isLoadingMore = false;
            });
          }
        } else {
          throw Exception('Failed to load more notifications');
        }
      }
    } catch (e) {
      print('Error loading more notifications: $e');
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  Future<void> _fetchNotifications() async {
    if (isLoading) return;

    setState(() {
      isLoading = true;
      _isLoadingMore = false;
      currentPage = 1;
      notifications.clear();
    });

    try {
      final sessionInfo = await authService.getStoredSession();
      if (sessionInfo != null) {
        final endpoint = _getEndpoint();
        final url = Uri.parse('$endpoint?page=$currentPage');
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
          final newNotifications = (data['notifications'] as List)
              .map((item) => NotificationItem.fromJson(item))
              .toList();
          if (mounted) {
            setState(() {
              notifications = newNotifications;
              hasMore = data['has_more'] ?? false;
              isLoading = false;
            });
          }
        } else {
          throw Exception('Failed to load notifications');
        }
      }
    } catch (e) {
      print('Error fetching notifications: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  String _getEndpoint() {
    switch (selectedFilter.toLowerCase()) {
      case 'anime':
        return 'https://kuudere.to/api/notifications/anime';
      case 'community':
        return 'https://kuudere.to/api/notifications/community';
      case 'system':
        return 'https://kuudere.to/api/notifications/system';
      default:
        return 'https://kuudere.to/api/notifications/anime';
    }
  }

  void _onFilterChanged(String filter) {
    if (selectedFilter == filter) return;
    setState(() {
      selectedFilter = filter;
      notifications.clear();
      currentPage = 1;
      hasMore = true;
      isLoading = false;
      _isLoadingMore = false;
    });
    _fetchNotifications();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text('Notifications'),
      ),
      body: Column(
        children: [
          _buildFilterTabs(),
          Expanded(
            child: RefreshIndicator(
              color: Colors.red,
              onRefresh: () async {
                setState(() {
                  notifications.clear();
                  currentPage = 1;
                  hasMore = true;
                });
                await _fetchNotifications();
              },
              child: isLoading && notifications.isEmpty
                  ? Center(
                      child: LoadingAnimationWidget.threeArchedCircle(
                        color: Colors.red,
                        size: 50,
                      ),
                    )
                  : notifications.isEmpty
                      ? _buildEmptyState()
                      : NotificationList(
                          notifications: notifications,
                          isLoading: isLoading,
                          hasMore: hasMore,
                          scrollController: _scrollController,
                        ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTabs() {
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: filters.length,
        itemBuilder: (context, index) {
          final filter = filters[index];
          final isSelected = selectedFilter == filter;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              selected: isSelected,
              label: Text(filter),
              onSelected: (selected) {
                if (selected) {
                  _onFilterChanged(filter);
                }
              },
              backgroundColor: Colors.grey[900],
              selectedColor: Colors.red,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.grey,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.packageOpen, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'No Notifications',
            style: TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            'You have no notifications at the moment',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

class NotificationList extends StatelessWidget {
  final List<NotificationItem> notifications;
  final bool isLoading;
  final bool hasMore;
  final ScrollController scrollController;

  const NotificationList({
    Key? key,
    required this.notifications,
    required this.isLoading,
    required this.hasMore,
    required this.scrollController,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: scrollController,
      physics: AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.all(8),
      itemCount: notifications.length + (hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == notifications.length) {
          if (hasMore) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: LoadingAnimationWidget.threeArchedCircle(
                  color: Colors.red,
                  size: 50,
                ),
              ),
            );
          } else {
            return SizedBox.shrink();
          }
        }

        final notification = notifications[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: NotificationTile(notification: notification),
        );
      },
    );
  }
}

class NotificationTile extends StatelessWidget {
  final NotificationItem notification;
  static const String HOST = 'https://kuudere.to';

  const NotificationTile({Key? key, required this.notification}) : super(key: key);

  String _getImageUrl(String image) {
    if (image.startsWith('/static/')) {
      return '$HOST$image';
    }
    return image;
  }

  void _handleNotificationTap(BuildContext context) {
    if (notification.link.contains('/watch/')) {
      final uri = Uri.parse(notification.link);
      final pathSegments = uri.pathSegments;
      final queryParams = uri.queryParameters;

      if (pathSegments.length >= 3) {
        final id = pathSegments[1];
        final episodeNumber = int.tryParse(pathSegments[2]) ?? 1;
        final nid = queryParams['nid'] ?? '';
        final lang = queryParams['lang'] ?? '';
        final ntype = queryParams['type'] ?? '';

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => WatchAnimeScreen(
              id: id,
              episodeNumber: episodeNumber,
              nid: nid,
              lang: lang,
              ntype: ntype,
            ),
          ),
        );
      }
    } else {
      // Handle other types of notifications here
      print('Tapped on notification: ${notification.id}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final textColor = notification.isRead ? Colors.grey[500]! : Colors.white;
    final subtitleColor = notification.isRead ? Colors.grey[500]! : Colors.grey[400]!;

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => _handleNotificationTap(context),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.network(
                    _getImageUrl(notification.image),
                    width: 50,
                    height: 70,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 50,
                        height: 70,
                        color: Colors.grey[800],
                        child: Icon(
                          Icons.error_outline,
                          color: Colors.grey[600],
                        ),
                      );
                    },
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notification.message,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 4),
                      Text(
                        notification.time,
                        style: TextStyle(
                          color: subtitleColor,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!notification.isRead)
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class NotificationItem {
  final String id;
  final String image;
  final bool? isCommunity;
  final bool isRead;
  final String link;
  final String message;
  final String time;

  NotificationItem({
    required this.id,
    required this.image,
    required this.isCommunity,
    required this.isRead,
    required this.link,
    required this.message,
    required this.time,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: json['id'],
      image: json['image'],
      isCommunity: json['isCommunity'],
      isRead: json['isRead'],
      link: json['link'],
      message: json['message'],
      time: json['time'],
    );
  }
}
