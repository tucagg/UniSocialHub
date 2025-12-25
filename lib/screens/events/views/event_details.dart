import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // intl paketi import edildi
import 'package:gtu/screens/forum/views/forum_screen.dart';
import '../../../database/database_helper.dart';
import '../../../database/event_helper.dart'; // Add this import
import '../../../utils/image_cache_manager.dart';
import '../../events/models/event_structure.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Add this import
import 'edit_event_screen.dart'; // Add this import

class EventDetailsScreen extends StatefulWidget {
  final Event event;

  const EventDetailsScreen({Key? key, required this.event}) : super(key: key);

  @override
  _EventDetailsScreenState createState() => _EventDetailsScreenState();
}

class _EventDetailsScreenState extends State<EventDetailsScreen> {
  Uint8List? _eventImageBytes;
  bool _isLoading = true;
  bool _isParticipant = false;
  bool _isJoinLoading = false;
  final EventHelper _eventHelper = EventHelper();
  String? _currentUsername;
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  int _currentAuthorityLevel = 0; // Add this line

  @override
  void initState() {
    super.initState();
    _loadEventImage();
    _loadCurrentUser(); // Move this line before _checkParticipantStatus
  }

  Future<void> _loadEventImage() async {
    try {
      setState(() {
        _isLoading = true;  // Başlangıçta yükleme durumunu true yap
      });

      if (widget.event.imageUrl.isNotEmpty) {
        Uint8List? cachedImage =
            await ImageCacheManager.getCachedImage(widget.event.imageUrl);
        if (cachedImage != null) {
          setState(() {
            _eventImageBytes = cachedImage;
            _isLoading = false;
          });
          return;
        }

        Uint8List? imageBytes =
            await DatabaseHelper().getImageFromS3(widget.event.imageUrl);
        if (imageBytes != null) {
          await ImageCacheManager.cacheImage(widget.event.imageUrl, imageBytes);
          setState(() {
            _eventImageBytes = imageBytes;
            _isLoading = false;
          });
        } else {
          setState(() {
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Etkinlik resmi yüklenirken hata: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _checkParticipantStatus() async {
    if (_currentUsername != null && widget.event.id != null) {
      try {
        final isParticipant = await _eventHelper.isUserParticipant(
          widget.event.id!,
          _currentUsername!,
        );
        setState(() {
          _isParticipant = isParticipant;
        });
      } catch (e) {
        print('Error checking participant status: $e');
      }
    }
  }

  Future<void> _loadCurrentUser() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userData = await _databaseHelper.getUserData(user.email!);
        setState(() {
          _currentUsername = userData['username'];
          _currentAuthorityLevel =
              userData['authority_level'] ?? 0; // Add this line
        });
        _checkParticipantStatus(); // Call _checkParticipantStatus here
      }
    } catch (e) {
      print('Error loading user data: $e');
    }
  }

  // Tarih ve saat formatlama
  String _formatDateTime(String dateTimeString) {
    try {
      final DateTime parsedDateTime = DateTime.parse(dateTimeString);
      final DateFormat formatter = DateFormat('dd MMMM yyyy, HH:mm');
      return formatter.format(parsedDateTime);
    } catch (e) {
      print('Tarih formatlama hatası: $e');
      return dateTimeString; // Formatlama başarısız olursa orijinal string döner
    }
  }

  bool _isEventActive() {
    final eventDate = DateTime.parse(widget.event.dateTime);
    return eventDate.isAfter(DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200.0,
            floating: false,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _eventImageBytes != null
                      ? Image.memory(
                          _eventImageBytes!,
                          fit: BoxFit.cover,
                        )
                      : Image.asset(
                          "assets/logo/kelebek.PNG",
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Colors.grey[300],
                              child: const Icon(Icons.image_not_supported, size: 50),
                            );
                          },
                        ),
              title: Text(
                widget.event.title,
                style: const TextStyle(
                  shadows: [Shadow(color: Colors.black54, blurRadius: 2)],
                ),
              ),
            ),
            actions: [
              if (_currentAuthorityLevel >= 1) // Add this condition
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            EditEventScreen(event: widget.event),
                      ),
                    );
                  },
                ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildEventHeader(),
                  const Divider(height: 32),
                  _buildDescription(),
                  const SizedBox(height: 24),
                  _buildLocationSection(),
                  const SizedBox(height: 24),
                  _buildDateTimeSection(),
                  const SizedBox(height: 32),
                  _buildJoinButton(context),
                  const SizedBox(height: 16),
                  _buildGoToForumButton(context),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventHeader() {
    return Row(
      children: [
        CircleAvatar(
          radius: 24,
          backgroundImage: _eventImageBytes != null
              ? MemoryImage(_eventImageBytes!)
              : AssetImage("assets/logo/kelebek.PNG") as ImageProvider,
          onBackgroundImageError: (exception, stackTrace) {
            setState(() {
              _eventImageBytes = null;
            });
          },
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Organized by',
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
              Text(
                widget.event.organizer,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        _buildStatusChip(),
      ],
    );
  }

  Widget _buildStatusChip() {
    final bool isActive = _isEventActive();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isActive 
            ? Colors.blue.withOpacity(0.1)
            : Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: isActive ? Colors.blue : Colors.grey,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            isActive ? 'Active' : 'Inactive',

            style: TextStyle(
              color: isActive ? Colors.blue : Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescription() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'About Event',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Text(
          widget.event.description,
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[800],
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildLocationSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.location_on, color: Colors.redAccent),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Location',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.event.location,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          // IconButton(
          //   icon: const Icon(Icons.map_outlined),
          //   onPressed: () {
          //     // Harita işlevi burada eklenebilir
          //   },
          // ),
        ],
      ),
    );
  }

  Widget _buildDateTimeSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.calendar_today, color: Colors.blue),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Date & Time',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDateTime(widget.event.dateTime),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          // IconButton(
          //   icon: const Icon(Icons.calendar_month_outlined),
          //   onPressed: () {
          //     // Takvim işlevi burada eklenebilir
          //   },
          // ),
        ],
      ),
    );
  }

  Widget _buildJoinButton(BuildContext context) {
    if (_currentUsername == null) {
      return const SizedBox(); // Hide button if user is not logged in
    }

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: _isParticipant ? Colors.red : Colors.blue,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        onPressed: _isJoinLoading
            ? null
            : () async {
                if (widget.event.id == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Invalid event ID')),
                  );
                  return;
                }

                setState(() {
                  _isJoinLoading = true;
                });

                try {
                  if (_isParticipant) {
                    await _eventHelper.removeParticipant(
                      widget.event.id!,
                      _currentUsername!,
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Successfully left the event'),
                      ),
                    );
                  } else {
                    await _eventHelper.addParticipant(
                      widget.event.id!,
                      _currentUsername!,
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Successfully joined the event'),
                      ),
                    );
                  }
                  setState(() {
                    _isParticipant = !_isParticipant;
                  });
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                } finally {
                  setState(() {
                    _isJoinLoading = false;
                  });
                }
              },
        child: _isJoinLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(color: Colors.white),
              )
            : Text(
                _isParticipant ? 'Leave Event' : 'Join Event',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }

  Widget _buildGoToForumButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ForumScreen(event: widget.event),
            ),
          );
        },
        child: const Text(
          'Go to Forum',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
