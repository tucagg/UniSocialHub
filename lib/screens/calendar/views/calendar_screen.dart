import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../events/models/event_structure.dart';
import '../../events/views/event_details.dart';
import '../../../database/event_helper.dart';
import '../../../database/database_helper.dart';
import '../../../utils/image_cache_manager.dart';
import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  _CalendarScreenState createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _selectedDay = DateTime.now();
  DateTime _focusedDay = DateTime.now();

  final List<Event> _allEvents = [];
  final Map<String, Uint8List?> _eventImages = {};
  final List<Event> _joinedEvents = [];

  @override
  void initState() {
    super.initState();
    _fetchEvents();
    _fetchJoinedEvents();
  }

  // Normalize the date for accurate comparisons
  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  Future<void> _fetchEvents() async {
    try {
      final events = await EventHelper().getAllEvents();
      // Filter only approved events
      final approvedEvents = events.where((event) => event.isApproved).toList();

      for (final event in approvedEvents) {
        if (event.imageUrl.isNotEmpty) {
          final cachedImage =
              await ImageCacheManager.getCachedImage(event.imageUrl);
          if (cachedImage != null) {
            _eventImages[event.id!] = cachedImage;
          } else {
            final imageBytes =
                await DatabaseHelper().getImageFromS3(event.imageUrl);
            if (imageBytes != null) {
              await ImageCacheManager.cacheImage(event.imageUrl, imageBytes);
              _eventImages[event.id!] = imageBytes;
            }
          }
        }
      }
      setState(() {
        _allEvents.clear();
        _allEvents.addAll(approvedEvents);
      });
    } catch (e) {
      print('Error fetching events: $e');
    }
  }

  Future<void> _fetchJoinedEvents() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userData = await DatabaseHelper().getUserData(user.email!);
        final username = userData['username'];
        final events = await EventHelper().getAllEvents();
        // Filter only approved events before checking participants
        final approvedEvents =
            events.where((event) => event.isApproved).toList();

        final joinedEvents = approvedEvents
            .where((event) => event.participants.contains(username))
            .toList();
        setState(() {
          _joinedEvents.clear();
          _joinedEvents.addAll(joinedEvents);
        });
      }
    } catch (e) {
      print('Error fetching joined events: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Takvim'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Calendar segment
              TableCalendar(
                availableGestures: AvailableGestures.horizontalSwipe,
                firstDay: DateTime(2000),
                lastDay: DateTime(2100),
                focusedDay: _focusedDay,
                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    _selectedDay = _normalizeDate(selectedDay);
                    _focusedDay = focusedDay;
                  });
                },
                daysOfWeekStyle: DaysOfWeekStyle(
                  weekdayStyle: const TextStyle(color: Colors.red),
                  weekendStyle: const TextStyle(color: Colors.red),
                ),
                calendarStyle: CalendarStyle(
                  todayDecoration: const BoxDecoration(
                    color: Color(0xFF02367B),
                    shape: BoxShape.circle,
                  ),
                  selectedDecoration: const BoxDecoration(
                    color: Color(0xFFF6931F),
                    shape: BoxShape.circle,
                  ),
                  markerDecoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                ),
                headerStyle: const HeaderStyle(
                  formatButtonVisible: false,
                  titleCentered: true,
                ),
                eventLoader: (day) {
                  final joinedEventsForDay = _joinedEvents.where((event) {
                    final eventDate = DateTime.parse(event.dateTime);
                    return isSameDay(eventDate, day);
                  }).toList();

                  // Return a single item if there are joined events, or an empty list otherwise
                  return joinedEventsForDay.isNotEmpty
                      ? [joinedEventsForDay.first]
                      : [];
                },
              ),
              const SizedBox(height: 10),
              // Event list
              _buildEventList(),
            ],
          ),
        ),
      ),
    );
  }

  // Build a list of events for the selected date
  Widget _buildEventList() {
    final selectedEvents = _allEvents.where((event) {
      // Parse event dateTime to compare with _selectedDay
      final eventDate = DateTime.parse(event.dateTime);
      return isSameDay(eventDate, _selectedDay);
    }).toList();

    if (selectedEvents.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('Bugün için herhangi bir etkinlik yok.'),
        ),
      );
    }

    return ListView.builder(
      itemCount: selectedEvents.length,
      shrinkWrap: true, // Allows ListView to adjust to content size
      physics:
          const NeverScrollableScrollPhysics(), // Integrates with SingleChildScrollView
      itemBuilder: (context, index) {
        final event = selectedEvents[index];
        final isJoined =
            _joinedEvents.any((joinedEvent) => joinedEvent.id == event.id);
        return Card(
          color: isJoined
              ? Colors.green.withOpacity(0.6)
              : null, // Change background color if joined
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
          elevation: 4.0,
          child: ListTile(
            contentPadding: const EdgeInsets.all(16.0),
            leading: CircleAvatar(
              radius: 30,
              backgroundImage:
                  event.id != null && _eventImages[event.id!] != null
                      ? MemoryImage(_eventImages[event.id!]!)
                      : (event.imageUrl.isNotEmpty
                              ? NetworkImage(event.imageUrl)
                              : const AssetImage('assets/placeholder.jpg'))
                          as ImageProvider,
            ),
            title: Text(event.title),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.location_on,
                        size: 16, color: Colors.black54),
                    const SizedBox(width: 4),
                    Text(event.location,
                        style: const TextStyle(color: Colors.black54)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Organized by: ${event.organizer}',
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
            onTap: () {
              // Navigate to event details
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EventDetailsScreen(event: event),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
