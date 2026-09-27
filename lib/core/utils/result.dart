import '../errors/failures.dart';

/// A type-safe monadic container representing either a successful outcome [Success]
/// with value [T], or an error outcome [Error] with a domain [Failure].
sealed class Result<T> {
  const Result();

  /// Creates a successful result holding [data].
  const factory Result.success(T data) = Success<T>;

  /// Creates a failed result holding [failure].
  const factory Result.failure(Failure failure) = Error<T>;

  /// Alias for [Result.failure].
  const factory Result.error(Failure failure) = Error<T>;

  /// Returns true if this is a [Success].
  bool get isSuccess => this is Success<T>;

  /// Returns true if this is an [Error].
  bool get isFailure => this is Error<T>;

  /// Returns data if success, or null if failure.
  T? get dataOrNull => switch (this) {
    Success(data: final d) => d,
    Error() => null,
  };

  /// Alias for [dataOrNull].
  T? get valueOrNull => dataOrNull;

  /// Returns failure if error, or null if success.
  Failure? get failureOrNull => switch (this) {
    Success() => null,
    Error(failure: final f) => f,
  };

  /// Alias for [failureOrNull].
  Failure? get errorOrNull => failureOrNull;

  /// Pattern-matches over the result, returning [onSuccess] or [onFailure].
  R fold<R>({
    required R Function(Failure failure) onFailure,
    required R Function(T data) onSuccess,
  }) {
    return switch (this) {
      Success(data: final d) => onSuccess(d),
      Error(failure: final f) => onFailure(f),
    };
  }

  /// Transforms the underlying data if [Success], preserving [Error].
  Result<R> map<R>(R Function(T data) transform) {
    return switch (this) {
      Success(data: final d) => Result.success(transform(d)),
      Error(failure: final f) => Result.failure(f),
    };
  }
}

/// Represents a successful computation.
final class Success<T> extends Result<T> {
  const Success(this.data);

  final T data;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Success<T> && other.data == data);

  @override
  int get hashCode => data.hashCode;

  @override
  String toString() => 'Result.success($data)';
}

/// Represents a failed computation holding a [Failure].
final class Error<T> extends Result<T> {
  const Error(this.failure);

  final Failure failure;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Error<T> && other.failure == failure);

  @override
  int get hashCode => failure.hashCode;

  @override
  String toString() => 'Result.failure($failure)';
}
