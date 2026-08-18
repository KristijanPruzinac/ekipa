/// Adapters implementing `ekipa_core`'s ports against real infrastructure.
///
/// This is the only layer permitted to know that Supabase, Overpass or FCM
/// exist. The dependency rule points inward: this package depends on
/// `ekipa_core` because it implements interfaces the domain declares, and never
/// the reverse.
library;

export 'src/system_clock.dart';
