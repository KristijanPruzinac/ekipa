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
      final attendees = await _attendeesFor(
        meetupRow['id'] as String,
        meetupRow['status'] as String,
      );
      meetups.add(Meetup.fromRow(meetupRow, attendees: attendees, myRsvp: row['rsvp'] as String));
    }
    meetups.sort((a, b) => a.startsAt.compareTo(b.startsAt));
    return meetups;
  }

  Future<List<Attendee>> _attendeesFor(String meetupId, String status) async {
    if (status != 'confirmed') return const [];
    final rows = await supabase.rpc('confirmed_attendees', params: {'m': meetupId});
    return (rows as List).map((r) => Attendee.fromRow(Map<String, dynamic>.from(r as Map))).toList();
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

  /// [decisions] maps attendee id -> "would see them again". Only ever
  /// writes the current user's own reflections — see `reflections_rw_own`.
  Future<void> submitReflection(String meetupId, Map<String, bool> decisions) async {
    if (decisions.isEmpty) return;
    final uid = supabase.auth.currentUser!.id;
    final rows = decisions.entries
        .map((e) => {
              'meetup_id': meetupId,
              'rater_id': uid,
              'subject_id': e.key,
              'would_meet_again': e.value,
            })
        .toList();
    await supabase.from('reflections').upsert(rows);
  }
}

/// Single shared instance — the repository is stateless, so there's nothing
/// to gain from per-screen instantiation or a DI container here.
const repository = EkipaRepository();
