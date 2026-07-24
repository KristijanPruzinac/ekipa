/// Domain types — mirror the Supabase schema in supabase/migrations.
library;

enum TalkLevel { chatty, balanced, quietCompany }

enum AvailabilitySlot { weekdayMorning, weekdayEvening, weekendDay, weekendEvening }

class Profile {
  const Profile({
    required this.id,
    required this.firstName,
    required this.city,
    required this.activities,
    required this.availability,
    required this.groupSizePref,
    required this.talkLevel,
    required this.sameGenderOnly,
    required this.blurb,
  });

  final String id;
  final String firstName;
  final String city;
  final List<String> activities; // activity slugs
  final List<AvailabilitySlot> availability;
  final int groupSizePref; // 2, 3, or 4
  final TalkLevel talkLevel;
  final bool sameGenderOnly;

  /// System-written one-liner shown to matched others. No free-text bio.
  final String blurb;

  /// Maps a `profiles` row (supabase/migrations/0001_init.sql) to a [Profile].
  /// Availability isn't surfaced anywhere in the UI yet, so it's left empty
  /// here rather than adding unused string<->enum parsing.
  factory Profile.fromRow(Map<String, dynamic> row) => Profile(
        id: row['id'] as String,
        firstName: row['first_name'] as String? ?? '',
        city: (row['city'] as String? ?? '').isEmpty ? 'Osijek' : row['city'] as String,
        activities: List<String>.from(row['activities'] as List? ?? const []),
        availability: const [],
        groupSizePref: row['group_size_pref'] as int? ?? 3,
        talkLevel: TalkLevel.values.firstWhere(
          (v) => v.name == _camelFromSnake(row['talk_level'] as String? ?? 'balanced'),
          orElse: () => TalkLevel.balanced,
        ),
        sameGenderOnly: row['same_gender_only'] as bool? ?? false,
        blurb: row['blurb'] as String? ?? '',
      );
}

String _camelFromSnake(String snake) {
  final parts = snake.split('_');
  return parts.first + parts.skip(1).map((p) => p.isEmpty ? p : '${p[0].toUpperCase()}${p.substring(1)}').join();
}

enum GroupStatus {
  proposed, // invites sent; members see only their own invite
  forming, // some yeses in; still hidden
  confirmed, // everyone accepted; now visible to all members
  completed,
  cancelled,
}

/// A person as shown inside a confirmed invitation. First name only.
class Attendee {
  const Attendee({required this.id, required this.firstName, required this.blurb});

  final String id;
  final String firstName;
  final String blurb;

  /// Maps a row from the `confirmed_attendees(m uuid)` RPC — the only path
  /// by which one user learns anything about another (see 0001_init.sql).
  factory Attendee.fromRow(Map<String, dynamic> row) => Attendee(
        id: row['id'] as String,
        firstName: row['first_name'] as String,
        blurb: row['blurb'] as String? ?? '',
      );
}

class Meetup {
  const Meetup({
    required this.id,
    required this.status,
    required this.activitySlug,
    required this.activityLabel,
    required this.venueName,
    required this.venueNote,
    required this.city,
    required this.startsAt,
    required this.durationMin,
    required this.attendees,
    required this.isStanding,
    required this.whatToExpect,
    this.myRsvp = 'pending',
  });

  final String id;
  final GroupStatus status;
  final String activitySlug;
  final String activityLabel;
  final String venueName;
  final String venueNote;
  final String city;
  final DateTime startsAt;
  final int durationMin;
  final List<Attendee> attendees;
  final bool isStanding;

  /// What actually happens — reduces ambiguity, the key anxiety tax.
  final String whatToExpect;

  /// This user's own answer: 'pending' / 'yes' / 'no'. Never anyone else's —
  /// that would defeat the invisible-decline invariant.
  final String myRsvp;

  /// Maps a `meetups` row (0001_init.sql) plus attendees resolved separately
  /// (via `confirmed_attendees`, empty until [status] is confirmed — RLS
  /// wouldn't return anyone else's row before then anyway) and this user's
  /// own `meetup_members.rsvp`.
  factory Meetup.fromRow(
    Map<String, dynamic> row, {
    required List<Attendee> attendees,
    String myRsvp = 'pending',
  }) {
    return Meetup(
      id: row['id'] as String,
      status: GroupStatus.values.firstWhere(
        (v) => v.name == row['status'] as String,
        orElse: () => GroupStatus.proposed,
      ),
      activitySlug: row['activity_slug'] as String,
      activityLabel: row['activity_label'] as String,
      venueName: row['venue_name'] as String,
      venueNote: row['venue_note'] as String? ?? '',
      city: row['city'] as String,
      startsAt: DateTime.parse(row['starts_at'] as String).toLocal(),
      durationMin: row['duration_min'] as int? ?? 90,
      attendees: attendees,
      isStanding: row['is_standing'] as bool? ?? false,
      whatToExpect: row['what_to_expect'] as String? ?? '',
      myRsvp: myRsvp,
    );
  }

  Meetup copyWith({
    String? id,
    GroupStatus? status,
    String? activitySlug,
    String? activityLabel,
    String? venueName,
    String? venueNote,
    DateTime? startsAt,
    bool? isStanding,
    String? whatToExpect,
  }) {
    return Meetup(
      id: id ?? this.id,
      status: status ?? this.status,
      activitySlug: activitySlug ?? this.activitySlug,
      activityLabel: activityLabel ?? this.activityLabel,
      venueName: venueName ?? this.venueName,
      venueNote: venueNote ?? this.venueNote,
      city: city,
      startsAt: startsAt ?? this.startsAt,
      durationMin: durationMin,
      attendees: attendees,
      isStanding: isStanding ?? this.isStanding,
      whatToExpect: whatToExpect ?? this.whatToExpect,
    );
  }
}
