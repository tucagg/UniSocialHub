// lib/screens/community/models/community_structure.dart

import 'package:flutter/material.dart';
import '../../events/models/event_structure.dart';

class Community {
  String id;
  String _name;
  String _description;
  String _photoUrl;
  List<String> members;
  List<String> admins;
  List<Event> events;

  Community({
    required this.id,
    required String name,
    required String description,
    required String photoUrl,
    required this.members,
    required this.admins,
    required this.events,
  })  : _name = name,
        _description = description,
        _photoUrl = photoUrl;

  String get name => _name;
  String get description => _description;
  String get photoUrl => _photoUrl;

  set name(String value) => _name = value;
  set description(String value) => _description = value;
  set photoUrl(String value) => _photoUrl = value;

  void addMember(String member) {
    members.add(member);
  }

  void addAdmin(String admin) {
    admins.add(admin);
  }
}
