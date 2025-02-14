import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:kuudere/data.dart';
import 'package:kuudere/services/auth_service.dart';
import 'package:kuudere/services/realtime_service.dart';

class ScheduleTab extends StatefulWidget {
  const ScheduleTab({Key? key}) : super(key: key);

  @override
  _ScheduleTabState createState() => _ScheduleTabState();
}

class _ScheduleTabState extends State<ScheduleTab> {
  late Future<Map<String, List<AnimeSchedule>>> _scheduleData;
  final RealtimeService _realtimeService = RealtimeService();
  final authService = AuthService();
  
  @override
  void initState() {
    super.initState();
    _scheduleData = fetchScheduleData();
    _realtimeService.joinRoom('countdowns');
  }

  Future<Map<String, List<AnimeSchedule>>> fetchScheduleData() async {
    final String currentTimeZone = await FlutterTimezone.getLocalTimezone();
    final sessionInfo = await authService.getStoredSession();

    if (sessionInfo == null) {
      throw Exception('No session found');
    }

    final url = Uri.parse('https://kuudere.to/api/schedule');

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "secret": SECRET,
          "key": sessionInfo.session,
          "timezone": currentTimeZone, // Added timezone in request body
        }),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = json.decode(response.body);
        final Map<String, List<AnimeSchedule>> scheduleData = {};

        jsonData.forEach((date, animeList) {
          scheduleData[date] = (animeList as List)
              .map((anime) => AnimeSchedule.fromJson(anime))
              .toList();
        });

        return scheduleData;
      } else {
        throw Exception(
            'Failed to load schedule data (Status: ${response.statusCode})');
      }
    } catch (e) {
      throw Exception('Error fetching data: $e');
    }
  }

  void retryFetchingData() {
    setState(() {
      _scheduleData = fetchScheduleData();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, List<AnimeSchedule>>>(
      future: _scheduleData,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Error: ${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red, fontSize: 16),
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: retryFetchingData,
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'No schedule data available.',
                  style: TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: retryFetchingData,
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        final scheduleData = snapshot.data!;
        final sortedDates = scheduleData.keys.toList()..sort();
        final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

        return ListView.builder(
          itemCount: sortedDates.length,
          itemBuilder: (context, index) {
            final date = sortedDates[index];
            final animeList = scheduleData[date]!;
            final isToday = date == today;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  color: isToday
                      ? Colors.transparent.withOpacity(0.2)
                      : Colors.transparent,
                  child: Text(
                    '${DateFormat('EEEE, MMMM d, yyyy').format(DateTime.parse(date))}${isToday ? ' (Today)' : ''}',
                    style: TextStyle(
                      color: Colors.white, // You can adjust this if needed
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ...animeList.map((anime) =>
                    AnimeScheduleCard(anime: anime, isToday: isToday)),
              ],
            );
          },
        );
      },
    );
  }
}

class AnimeScheduleCard extends StatelessWidget {
  final AnimeSchedule anime;
  final bool isToday;

  const AnimeScheduleCard(
      {Key? key, required this.anime, required this.isToday})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: isToday ? Colors.red.withOpacity(0.1) : Colors.grey[900],
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        title: Text(
          anime.title,
          style:
              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          'Episode ${anime.episode}',
          style: TextStyle(color: Colors.grey[400]),
        ),
        trailing: Text(
          anime.time,
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
      ),
    );
  }
}

class AnimeSchedule {
  final String title;
  final int episode;
  final String time;

  AnimeSchedule(
      {required this.title, required this.episode, required this.time});

  factory AnimeSchedule.fromJson(Map<String, dynamic> json) {
    return AnimeSchedule(
      title: json['title'],
      episode: json['episode'],
      time: json['time'],
    );
  }
}
