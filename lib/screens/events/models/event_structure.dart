class Event {
  final String? id;
  final String title;
  final String description;
  final String dateTime;
  final String location;
  final String organizer;
  final String imageUrl;
  final List<String> participants;
  final String communityId; // Event's community ID
  final bool isApproved; // Event approval status

  Event({
    this.id,
    required this.title,
    required this.description,
    required this.dateTime,
    required this.location,
    required this.organizer,
    required this.imageUrl,
    required this.participants,
    required this.communityId,
    this.isApproved = false,
  });

}