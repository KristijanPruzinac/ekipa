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
