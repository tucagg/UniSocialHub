import 'package:flutter/material.dart';
import '../../../database/event_helper.dart';
import '../models/event_structure.dart';

class ManageEventsScreen extends StatefulWidget {
  const ManageEventsScreen({Key? key}) : super(key: key);

  @override
  State<ManageEventsScreen> createState() => _ManageEventsScreenState();
}

class _ManageEventsScreenState extends State<ManageEventsScreen> {
  final List<Event> _unapprovedEvents = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUnapprovedEvents();
  }

  Future<void> _fetchUnapprovedEvents() async {
    try {
      final unapproved = await EventHelper().getUnapprovedEvents();
      setState(() {
        _unapprovedEvents.clear();
        _unapprovedEvents.addAll(unapproved);
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _approveEvent(Event event) async {
    await EventHelper().updateEventApproval(event.id!, true);
    setState(() {
      _unapprovedEvents.remove(event);
    });
  }

  Future<void> _rejectEvent(Event event) async {
    await EventHelper().deleteEvent(event.id!);
    setState(() {
      _unapprovedEvents.remove(event);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Unapproved Events')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _unapprovedEvents.isEmpty
              ? const Center(child: Text('No events pending approval.'))
              : ListView.builder(
                  itemCount: _unapprovedEvents.length,
                  itemBuilder: (context, index) {
                    final event = _unapprovedEvents[index];
                    return Card(
                      child: ExpansionTile(
                        title: Text(event.title),
                        subtitle: Text(event.description),
                        children: [
                          Text('Date: ${event.dateTime}'),
                          Text('Location: ${event.location}'),
                          Text('Organizer: ${event.organizer}'),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.check),
                                onPressed: () => _approveEvent(event),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () => _rejectEvent(event),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}