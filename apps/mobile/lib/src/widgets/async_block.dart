import 'package:ekipa_ui/ekipa_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/src/data/member_gateway.dart';

/// Renders an [AsyncValue] with the same three answers everywhere.
///
/// **Intention — loading, refused and broken are three different sentences and
/// the difference matters.** A screen that renders every failure as "something
/// went wrong" teaches people that the app is unreliable, when most of what
/// they will actually hit is a *refusal* — a confirmation window that closed, a
/// rating still owed — which is the app working correctly and having something
/// specific to say.
///
/// The refusal's words come from the server, never from here. See
/// [MemberFailure].
class AsyncBlock<T> extends StatelessWidget {
  /// Renders [value].
  const AsyncBlock({
    required this.value,
    required this.builder,
    this.empty,
    super.key,
  });

  /// What to render.
  final AsyncValue<T> value;

  /// How to render it once it is there.
  final Widget Function(T value) builder;

  /// What to say when the data is there and there is none of it.
  final String? empty;

  @override
  Widget build(BuildContext context) => switch (value) {
    AsyncData(:final value) => builder(value),
    AsyncError(:final error) => _Trouble(error: error),
    _ => const _Waiting(),
  };
}

class _Waiting extends StatelessWidget {
  const _Waiting();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: ZarSpace.xxl),
    child: Center(
      child: Text(
        'One moment',
        style: ZarType.body.copyWith(color: ZarColors.inkFaint),
      ),
    ),
  );
}

class _Trouble extends StatelessWidget {
  const _Trouble({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    // A refusal and a fault get different words. The refusal's sentence is
    // the server's, because a client that composed its own would eventually
    // explain a refusal it did not understand.
    final failure = switch (error) {
      final MemberFailure refusal => refusal,
      _ => null,
    };
    return EkipaCard(
      tone: EkipaCardTone.quiet,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            failure == null ? 'That did not load' : 'No',
            style: ZarType.bodyStrong.copyWith(
              color: failure == null ? ZarColors.amber : ZarColors.rose,
            ),
          ),
          const SizedBox(height: ZarSpace.xs),
          Text(
            failure?.message ??
                'The app could not reach the server. Nothing you did caused '
                    'this, and nothing was lost.',
            style: ZarType.body.copyWith(color: ZarColors.inkMuted),
          ),
        ],
      ),
    );
  }
}
