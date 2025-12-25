import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart'; // Tarih formatlama için intl paketi
import '../../events/models/event_structure.dart';
import 'create_event_screen.dart';
import '../../../database/community_helper.dart';
import '../../../database/event_helper.dart';
import '../../../database/database_helper.dart';
import '../../../utils/image_cache_manager.dart';
import 'event_details.dart';
import 'manage_events_screen.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  _EventsScreenState createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  final List<Event> _events = [];
  final Map<String, Uint8List?> _eventImages = {};
  bool _isLoading = true;
  String? _currentUsername;
  int _currentAuthorityLevel = 0;
  final DatabaseHelper _databaseHelper = DatabaseHelper();

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _fetchEvents();
  }

  Future<void> _loadCurrentUser() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userData = await _databaseHelper.getUserData(user.email!);
        setState(() {
          _currentUsername = userData['username'];
          _currentAuthorityLevel = userData['authority_level'] ?? 0;
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading user data: $e')),
      );
    }
  }

  Future<void> _fetchEvents() async {
    try {
      final List<Event> events = await EventHelper().getEventsBasedOnAuthority(
        currentAuthorityLevel: _currentAuthorityLevel,
      );

      for (final event in events) {
        if (event.imageUrl.isNotEmpty) {
          final Uint8List? cachedImage =
              await ImageCacheManager.getCachedImage(event.imageUrl);

          if (cachedImage != null) {
            _eventImages[event.id!] = cachedImage;
          } else {
            final Uint8List? imageBytes =
                await _databaseHelper.getImageFromS3(event.imageUrl);
            if (imageBytes != null) {
              await ImageCacheManager.cacheImage(event.imageUrl, imageBytes);
              _eventImages[event.id!] = imageBytes;
            }
          }
        }
      }

      setState(() {
        _events.clear();
        _events.addAll(events);
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching events: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _addNewEvent() async {
    if (_currentAuthorityLevel < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Insufficient authority to add events.')),
      );
      return;
    }

    try {
      final communityId = await CommunityHelper().getAdminCommunityIdForUser(
        _currentUsername!,
      );

      if (communityId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'You are not an admin of any community, cannot add events.'),
          ),
        );
        return;
      }

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CreateEventScreen(
            communityId: communityId,
            organizer: _currentUsername!,
            onSave: (newEvent) {
              // Do not add the event to _events here until it's approved
            },
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding event: $e')),
      );
    }
  }

  // Tarihi formatlama fonksiyonu
  String _formatDateTime(String dateTime) {
    try {
      final DateTime parsedDateTime = DateTime.parse(dateTime);
      final DateFormat formatter = DateFormat('dd MMMM yyyy, HH:mm');
      return formatter.format(parsedDateTime);
    } catch (e) {
      print('Date formatting error: $e');
      return dateTime;
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      initialIndex: 0,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Events'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'All Events'),
              Tab(text: 'Joined Events'),
            ],
          ),
          actions: [
            if (_currentAuthorityLevel >= 1)
              IconButton(
                icon: const Icon(Icons.build),
                tooltip: 'Manage Unapproved Events',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ManageEventsScreen(),
                    ),
                  );
                },
              ),
            if (_currentAuthorityLevel >= 1) // Changed from >= 2
              IconButton(
                icon: const Icon(Icons.add),
                tooltip: 'Add New Event',
                onPressed: _addNewEvent,
              ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _buildAllEventsList(),
                  _buildJoinedEventsList(),
                ],
              ),
      ),
    );
  }

  Widget _buildJoinedEventsList() {
    final now = DateTime.now();
    final joinedEvents = _events
        .where((e) => e.participants.contains(_currentUsername))
        .toList();

    final upcomingEvents = joinedEvents
        .where((e) => DateTime.parse(e.dateTime).isAfter(now))
        .toList();
    final passedEvents = joinedEvents
        .where((e) => DateTime.parse(e.dateTime).isBefore(now))
        .toList();

    if (joinedEvents.isEmpty) {
      return const Center(child: Text('No joined events.'));
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Upcoming events
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text('Upcoming Joined Events',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: upcomingEvents.length,
            itemBuilder: (context, index) {
              final event = upcomingEvents[index];
              final imageBytes = _eventImages[event.id!];
              return Card(
                margin: const EdgeInsets.only(bottom: 16.0),
                child: ListTile(
                  leading: SizedBox(
                    width: 50,
                    height: 50,
                    child: imageBytes != null
                        ? Image.memory(
                            imageBytes,
                            fit: BoxFit.cover,
                          )
                        : event.imageUrl.isNotEmpty
                            ? Image.network(
                                event.imageUrl,
                                errorBuilder: (context, error, stackTrace) =>
                                    const Icon(Icons.broken_image),
                                fit: BoxFit.cover,
                              )
                            : const Icon(Icons.event, size: 50),
                  ),
                  title: Text(event.title),
                  subtitle: Text(_formatDateTime(event.dateTime)),
                  onTap: () {
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
          ),
          // Passed events
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text('Passed Joined Events',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: passedEvents.length,
            itemBuilder: (context, index) {
              final event = passedEvents[index];
              final imageBytes = _eventImages[event.id!];
              return Card(
                margin: const EdgeInsets.only(bottom: 16.0),
                child: ListTile(
                  leading: SizedBox(
                    width: 50,
                    height: 50,
                    child: imageBytes != null
                        ? Image.memory(
                            imageBytes,
                            fit: BoxFit.cover,
                          )
                        : event.imageUrl.isNotEmpty
                            ? Image.network(
                                event.imageUrl,
                                errorBuilder: (context, error, stackTrace) =>
                                    const Icon(Icons.broken_image),
                                fit: BoxFit.cover,
                              )
                            : const Icon(Icons.event, size: 50),
                  ),
                  title: Text(event.title),
                  subtitle: Text(_formatDateTime(event.dateTime)),
                  onTap: () {
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
          ),
        ],
      ),
    );
  }

  Widget _buildAllEventsList() {
    if (_events.isEmpty) {
      return const Center(child: Text('No events found.'));
    }

    final now = DateTime.now();
    final upcomingEvents = _events
        .where((e) => DateTime.parse(e.dateTime).isAfter(now))
        .toList();
    final passedEvents = _events
        .where((e) => DateTime.parse(e.dateTime).isBefore(now))
        .toList();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Upcoming events
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text('Upcoming Events',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: upcomingEvents.length,
            itemBuilder: (context, index) {
              final event = upcomingEvents[index];
              final imageBytes = _eventImages[event.id!];
              return Card(
                margin: const EdgeInsets.only(bottom: 16.0),
                child: ListTile(
                  leading: SizedBox(
                    width: 50,
                    height: 50,
                    child: imageBytes != null
                        ? Image.memory(
                            imageBytes,
                            fit: BoxFit.cover,
                          )
                        : event.imageUrl.isNotEmpty
                            ? Image.network(
                                event.imageUrl,
                                errorBuilder: (context, error, stackTrace) =>
                                    const Icon(Icons.broken_image),
                                fit: BoxFit.cover,
                              )
                            : const Icon(Icons.event, size: 50),
                  ),
                  title: Text(event.title),
                  subtitle: Text(_formatDateTime(event.dateTime)),
                  onTap: () {
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
          ),

          // Passed events
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text('Passed Events',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: passedEvents.length,
            itemBuilder: (context, index) {
              final event = passedEvents[index];
              final imageBytes = _eventImages[event.id!];
              return Card(
                margin: const EdgeInsets.only(bottom: 16.0),
                child: ListTile(
                  leading: SizedBox(
                    width: 50,
                    height: 50,
                    child: imageBytes != null
                        ? Image.memory(
                            imageBytes,
                            fit: BoxFit.cover,
                          )
                        : event.imageUrl.isNotEmpty
                            ? Image.network(
                                event.imageUrl,
                                errorBuilder: (context, error, stackTrace) =>
                                    const Icon(Icons.broken_image),
                                fit: BoxFit.cover,
                              )
                            : const Icon(Icons.event, size: 50),
                  ),
                  title: Text(event.title),
                  subtitle: Text(_formatDateTime(event.dateTime)),
                  onTap: () {
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
          ),
        ],
      ),
    );
  }
}
