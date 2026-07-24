import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';
import 'supabase_client.dart';

/// Thin data-access layer over Supabase, matching the schema and RLS
/// policies in supabase/migrations/. Every method here relies on the server
/// to enforce the privacy invariants (invisible declines, one-way-private
/// reflections) — this class never filters for privacy, only for its own
/// convenience. Callers must check [isBackendConfigured] before using this;
/// it assumes an initialized Supabase client.
class EkipaRepository {
  const EkipaRepository();

  Stream<AuthState> get authStateChanges => supabase.auth.onAuthStateChange;

  Session? get currentSession => supabase.auth.currentSession;

  /// Sends a one-time SMS code. This is the *only* thing asked of a new user
  /// before Welcome — see docs/PLAN.md Phase 1.
  Future<void> requestPhoneCode(String phone) {
    return supabase.auth.signInWithOtp(phone: phone);
  }

  Future<void> verifyPhoneCode({required String phone, required String code}) {
    return supabase.auth.verifyOTP(type: OtpType.sms, phone: phone, token: code);
  }

  Future<void> signOut() => supabase.auth.signOut();

  Future<Profile?> myProfile() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return null;
    final row = await supabase.from('profiles').select().eq('id', uid).maybeSingle();
    return row == null ? null : Profile.fromRow(row);
  }

  /// Invitations visible to the current user, newest activity first: their
  /// own `meetup_members` rows joined to the meetup, excluding ones that
  /// have already completed or quietly died. Attendee identities only
  /// resolve once a meetup is confirmed — before that, RLS wouldn't return
  /// anyone else's row anyway, so this mirrors the server truth rather than
  /// hiding data the client could otherwise see.
  Future<List<Meetup>> myInvitations() async {
    final uid = supabase.auth.currentUser!.id;
    final rows = await supabase
        .from('meetup_members')
        .select('rsvp, meetups!inner(*)')
        .eq('user_id', uid)
        .filter('meetups.status', 'in', '(proposed,forming,confirmed)');

    final meetups = <Meetup>[];
    for (final row in rows as List) {
      final meetupRow = Map<String, dynamic>.from(row['meetups'] as Map);
      final id = meetupRow['id'] as String;
      final confirmed = meetupRow['status'] as String == 'confirmed';
      // Names only resolve inside the T−3h reveal window; the server returns an
      // empty set before then (see confirmed_attendees, 0007). When it does,
      // fall back to the group's shape so a confirmed meetup still says
      // something concrete about who's coming.
      final attendees = confirmed ? await _attendeesFor(id) : const <Attendee>[];
      final composition =
          confirmed && attendees.isEmpty ? await _compositionFor(id) : null;
      meetups.add(Meetup.fromRow(
        meetupRow,
        attendees: attendees,
        composition: composition,
        myRsvp: row['rsvp'] as String,
      ));
    }
    meetups.sort((a, b) => a.startsAt.compareTo(b.startsAt));
    return meetups;
  }

  Future<List<Attendee>> _attendeesFor(String meetupId) async {
    final rows = await supabase.rpc('confirmed_attendees', params: {'m': meetupId});
    return (rows as List).map((r) => Attendee.fromRow(Map<String, dynamic>.from(r as Map))).toList();
  }

  Future<MeetupComposition?> _compositionFor(String meetupId) async {
    final rows = await supabase.rpc('group_composition', params: {'m': meetupId});
    final list = rows as List;
    if (list.isEmpty) return null;
    return MeetupComposition.fromRow(Map<String, dynamic>.from(list.first as Map));
  }

  /// Writes only the current user's own RSVP. Whether that turns the
  /// proposal into a confirmed, visible meetup — or quietly cancels it — is
  /// decided server-side (see the `on_rsvp_change` trigger), never here.
  Future<void> respond(String meetupId, {required bool accept}) async {
    final uid = supabase.auth.currentUser!.id;
    await supabase
        .from('meetup_members')
        .update({'rsvp': accept ? 'yes' : 'no'})
        .eq('meetup_id', meetupId)
        .eq('user_id', uid);
  }

  /// [feelings] maps attendee id -> how the meetup felt. Only ever writes the
  /// current user's own reflections (see `reflections_rw_own`); a `rather_not`
  /// silently records a permanent exclusion server-side (see 0006).
  Future<void> submitReflection(String meetupId, Map<String, Sentiment> feelings) async {
    if (feelings.isEmpty) return;
    final uid = supabase.auth.currentUser!.id;
    final rows = feelings.entries
        .map((e) => {
              'meetup_id': meetupId,
              'rater_id': uid,
              'subject_id': e.key,
              'sentiment': e.value.wire,
            })
        .toList();
    await supabase.from('reflections').upsert(rows);
  }

  /// Persists the logistics captured in onboarding. Writes only the current
  /// user's own profile row (see `profiles_update_own`).
  Future<void> saveProfile({
    required String firstName,
    required String city,
    String? gender,
    required bool sameGenderOnly,
    required int groupSizePref,
    required List<String> activities,
  }) async {
    final uid = supabase.auth.currentUser!.id;
    await supabase.from('profiles').update({
      'first_name': firstName,
      'city': city,
      'gender': gender,
      'same_gender_only': sameGenderOnly,
      'group_size_pref': groupSizePref,
      'activities': activities,
    }).eq('id', uid);
  }
}

/// Single shared instance — the repository is stateless, so there's nothing
/// to gain from per-screen instantiation or a DI container here.
const repository = EkipaRepository();
