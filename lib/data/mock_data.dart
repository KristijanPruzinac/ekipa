import '../models/models.dart';

DateTime _nextSaturdayAt(int hour, int minute) {
  final now = DateTime.now();
  final daysUntilSat = (6 - now.weekday + 7) % 7 == 0 ? 7 : (6 - now.weekday + 7) % 7;
  final d = now.add(Duration(days: daysUntilSat));
  return DateTime(d.year, d.month, d.day, hour, minute);
}

/// Sample invitation used to explore the UI before the backend is wired.
final Meetup mockMeetup = Meetup(
  id: 'mtp_demo_1',
  status: GroupStatus.proposed,
  activitySlug: 'walk',
  activityLabel: 'Walking',
  venueName: 'Park by the Drava',
  venueNote: 'Meet at the main entrance, near the fountain.',
  city: 'Osijek',
  startsAt: _nextSaturdayAt(15, 0),
  durationMin: 90,
  isStanding: false,
  whatToExpect:
      'A relaxed 90-minute walk along the river with three other people. No pressure to keep talking — walking side by side does the work. You can head off whenever you like; nobody will ask why.',
  attendees: const [
    Attendee(id: 'u1', firstName: 'Lucija', blurb: 'Into photo walks and sci-fi. Prefers small, quiet groups.'),
    Attendee(id: 'u2', firstName: 'Marko', blurb: 'Bouldering and board games. Easy-going, happy in silence.'),
    Attendee(id: 'u3', firstName: 'Ivana', blurb: 'Loves nature and reading. New to the city.'),
  ],
);

/// A second, already-confirmed standing group to show Stage 2.
final Meetup mockStanding = mockMeetup.copyWith(
  id: 'mtp_demo_2',
  status: GroupStatus.confirmed,
  activitySlug: 'boardgames',
  activityLabel: 'Board games',
  venueName: 'Kocka board-game café',
  venueNote: 'Table booked under "Ekipa".',
  startsAt: _nextSaturdayAt(18, 0),
  isStanding: true,
  whatToExpect: 'Your regular group, every other Saturday. Same faces, a familiar table, no organizing on your part.',
);
