import 'repository.dart';

/// Caches whether the signed-in user has finished the logistics onboarding, so
/// the router's redirect can gate on it without hitting the database on every
/// navigation. Invalidated on sign-out; marked complete the moment onboarding
/// saves, so the redirect off `/onboarding` doesn't need another round-trip.
class ProfileStatus {
  bool? _complete;

  Future<bool> isComplete() async {
    final cached = _complete;
    if (cached != null) return cached;
    final profile = await repository.myProfile();
    final result = profile?.isComplete ?? false;
    _complete = result;
    return result;
  }

  void markComplete() => _complete = true;

  void invalidate() => _complete = null;
}

final profileStatus = ProfileStatus();
