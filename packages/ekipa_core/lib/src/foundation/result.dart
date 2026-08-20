import 'package:meta/meta.dart';

/// The outcome of an operation that is expected to be able to fail.
///
/// **Intention.** Exceptions thrown across an async UI boundary produce the
/// failure mode recorded as S7 in `docs/v3/LEGACY_AUDIT.md`: a network error
/// rendered as an empty state, because `snapshot.data ?? const []` cannot tell
/// "no rows" from "the call blew up". A sealed result makes the error case
/// unmissable — the analyzer refuses an inexhaustive `switch`.
///
/// **Rejected — exceptions everywhere.** Cheaper to write, and the compiler
/// never tells you a caller forgot to handle a failure. Reserved here for
/// genuine programmer error (a broken invariant), never for expected outcomes.
///
/// **Rejected — nullable returns.** `null` collapses every distinct failure
/// into one, so the UI can say "something went wrong" and nothing more precise,
/// ever.
@immutable
sealed class Result<T, E> {
  const Result();

  /// A successful outcome carrying [value].
  const factory Result.ok(T value) = Ok<T, E>;

  /// A failed outcome carrying [error].
  const factory Result.err(E error) = Err<T, E>;

  /// Whether this is an [Ok].
  bool get isOk => this is Ok<T, E>;

  /// Whether this is an [Err].
  bool get isErr => this is Err<T, E>;

  /// The value if this is an [Ok], otherwise `null`.
  ///
  /// Prefer [fold] — this exists for interop at boundaries where a nullable is
  /// genuinely the right shape, not as a shortcut around handling the error.
  T? get valueOrNull => switch (this) {
    Ok<T, E>(:final value) => value,
    Err<T, E>() => null,
  };

  /// The error if this is an [Err], otherwise `null`.
  E? get errorOrNull => switch (this) {
    Ok<T, E>() => null,
    Err<T, E>(:final error) => error,
  };

  /// Collapses both branches into a single value. The only total accessor.
  R fold<R>({
    required R Function(T value) onOk,
    required R Function(E error) onErr,
  }) => switch (this) {
    Ok<T, E>(:final value) => onOk(value),
    Err<T, E>(:final error) => onErr(error),
  };

  /// Transforms the success value, leaving an error untouched.
  Result<R, E> map<R>(R Function(T value) transform) => switch (this) {
    Ok<T, E>(:final value) => Ok<R, E>(transform(value)),
    Err<T, E>(:final error) => Err<R, E>(error),
  };

  /// Chains an operation that may itself fail.
  Result<R, E> flatMap<R>(Result<R, E> Function(T value) transform) =>
      switch (this) {
        Ok<T, E>(:final value) => transform(value),
        Err<T, E>(:final error) => Err<R, E>(error),
      };

  /// Transforms the error, leaving a success untouched.
  Result<T, F> mapErr<F>(F Function(E error) transform) => switch (this) {
    Ok<T, E>(:final value) => Ok<T, F>(value),
    Err<T, E>(:final error) => Err<T, F>(transform(error)),
  };

  /// The success value, or [fallback] if this is an [Err].
  T unwrapOr(T fallback) => switch (this) {
    Ok<T, E>(:final value) => value,
    Err<T, E>() => fallback,
  };
}

/// A successful [Result].
final class Ok<T, E> extends Result<T, E> {
  /// Wraps [value] as a success.
  const Ok(this.value);

  /// The value produced.
  final T value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Ok<T, E> && other.value == value);

  @override
  int get hashCode => Object.hash(Ok, value);

  @override
  String toString() => 'Ok($value)';
}

/// A failed [Result].
final class Err<T, E> extends Result<T, E> {
  /// Wraps [error] as a failure.
  const Err(this.error);

  /// The error produced.
  final E error;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Err<T, E> && other.error == error);

  @override
  int get hashCode => Object.hash(Err, error);

  @override
  String toString() => 'Err($error)';
}
