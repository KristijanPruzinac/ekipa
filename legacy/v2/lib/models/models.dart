/// Domain types — mirror the Supabase schema in supabase/migrations.
library;

enum TalkLevel { chatty, balanced, quietCompany }

enum AvailabilitySlot { weekdayMorning, weekdayEvening, weekendDay, weekendEvening }

/// How the last meetup felt — the four-level reflection (see 0006). Only mutual
/// warmth (both people at [enjoyed] or above) seeds a future group; [ratherNot]
/// is a silent, permanent "never compose us again".
enum Sentiment { reallyEnjoyed, enjoyed, noPreference, ratherNot }

extension SentimentWire on Sentiment {
  /// The value stored in `reflections.sentiment`.
  String get wire => switch (this) {
        Sentiment.reallyEnjoyed => 'really_enjoyed',
        Sentiment.enjoyed => 'enjoyed',
        Sentiment.noPreference => 'no_preference',
        Sentiment.ratherNot => 'rather_not',
      };
}

class Profile {
  const Profile({
    required this.id,
    required this.firstName,
    required this.city,
    required this.gender,
    required this.activities,
    required this.availability,
    required this.groupSizePref,
    required this.talkLevel,
    required this.sameGenderOnly,
  });

  final String id;
  final String firstName;
  final String city;

  /// Used only for same-gender grouping and the pre-reveal group shape.
  /// Never shown as a label on a person.
  final String? gender;
  final List<String> activities; // activity slugs
  final List<AvailabilitySlot> availability;
  final int groupSizePref; // 2, 3, or 4
  final TalkLevel talkLevel;
  final bool sameGenderOnly;

  bool get isComplete => firstName.trim().isNotEmpty && city.trim().isNotEmpty;

  /// Maps a `profiles` row (supabase/migrations/0001_init.sql) to a [Profile].
  /// Availability isn't surfaced anywhere in the UI yet, so it's left empty
  /// here rather than adding unused string<->enum parsing.
  factory Profile.fromRow(Map<String, dynamic> row) => Profile(
        id: row['id'] as String,
        firstName: row['first_name'] as String? ?? '',
        city: (row['city'] as String? ?? '').isEmpty ? 'Osijek' : row['city'] as String,
        gender: row['gender'] as String?,
        activities: List<String>.from(row['activities'] as List? ?? const []),
        availability: const [],
        groupSizePref: row['group_size_pref'] as int? ?? 3,
        talkLevel: TalkLevel.values.firstWhere(
          (v) => v.name == _camelFromSnake(row['talk_level'] as String? ?? 'balanced'),
          orElse: () => TalkLevel.balanced,
        ),
        sameGenderOnly: row['same_gender_only'] as bool? ?? false,
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

/// A person as shown inside a confirmed invitation. First name only — no
/// blurb, no bio, nothing to pre-judge on. Resolved only inside the T−3h
/// reveal window (see 0007); before that the client holds none of this.
class Attendee {
  const Attendee({required this.id, required this.firstName});

  final String id;
  final String firstName;

  /// Maps a row from the `confirmed_attendees(m uuid)` RPC — the only path
  /// by which one user learns anything about another (see 0007).
  factory Attendee.fromRow(Map<String, dynamic> row) => Attendee(
        id: row['id'] as String,
        firstName: row['first_name'] as String,
      );
}

/// The *shape* of a confirmed group shown before the T−3h name reveal — counts
/// only, never identities (see `group_composition`, 0007).
class MeetupComposition {
  const MeetupComposition({
    required this.total,
    required this.women,
    required this.men,
    required this.other,
  });

  final int total;
  final int women;
  final int men;
  final int other;

  /// True when the group is a clean single-gender set — worth stating plainly
  /// to someone who asked for same-gender company.
  bool get isSingleGender =>
      (women == total || men == total) && total > 0;

  factory MeetupComposition.fromRow(Map<String, dynamic> row) => MeetupComposition(
        total: (row['total'] as num?)?.toInt() ?? 0,
        women: (row['women'] as num?)?.toInt() ?? 0,
        men: (row['men'] as num?)?.toInt() ?? 0,
        other: (row['other'] as num?)?.toInt() ?? 0,
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
    this.composition,
    this.expiresAt,
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

  /// The group's shape, shown once confirmed but before the T−3h name reveal.
  /// Null when the meetup isn't confirmed, or once [attendees] are revealed.
  final MeetupComposition? composition;

  /// When an unaccepted proposal quietly dies (see 0007). Null for meetups
  /// that are already confirmed or standing.
  final DateTime? expiresAt;

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
    MeetupComposition? composition,
    String myRsvp = 'pending',
  }) {
    final expires = row['expires_at'] as String?;
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
      composition: composition,
      expiresAt: expires == null ? null : DateTime.parse(expires).toLocal(),
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
    List<Attendee>? attendees,
    bool? isStanding,
    MeetupComposition? composition,
    String? whatToExpect,
    String? myRsvp,
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
      attendees: attendees ?? this.attendees,
      isStanding: isStanding ?? this.isStanding,
      composition: composition ?? this.composition,
      expiresAt: expiresAt,
      whatToExpect: whatToExpect ?? this.whatToExpect,
      myRsvp: myRsvp ?? this.myRsvp,
    );
  }
}
