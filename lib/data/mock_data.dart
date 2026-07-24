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
  // A proposed meetup reveals no one — not who else was invited, not who
  // declined. First name is the only identity data, and it arrives later.
  attendees: const [],
);

/// A second, already-confirmed standing group to show Stage 2. It's your
/// regular group, so the first names are already known to you.
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
  attendees: const [
    Attendee(id: 'u1', firstName: 'Lucija'),
    Attendee(id: 'u2', firstName: 'Marko'),
    Attendee(id: 'u3', firstName: 'Ivana'),
  ],
  myRsvp: 'yes',
);

/// A confirmed group that hasn't hit the T−3h name reveal yet — shows its
/// shape (how many, what mix) but no names. Demonstrates the reveal gate.
final Meetup mockFormingConfirmed = mockMeetup.copyWith(
  id: 'mtp_demo_3',
  status: GroupStatus.confirmed,
  activitySlug: 'coffee_quiet',
  activityLabel: 'Coffee',
  venueName: 'Kava bar Cvajner',
  venueNote: 'Corner table by the window.',
  startsAt: _nextSaturdayAt(11, 0),
  whatToExpect:
      'A calm hour over coffee with three others. Come as you are; leave when you like.',
  attendees: const [],
  composition: const MeetupComposition(total: 4, women: 2, men: 2, other: 0),
  myRsvp: 'yes',
);
