import 'package:equatable/equatable.dart';

/// Represents a reusable metadata tag for labeling documents.
class TagEntity extends Equatable {
  const TagEntity({
    required this.id,
    required this.name,
    this.colorValue,
    required this.createdAt,
    this.documentCount = 0,
  });

  final String id;
  final String name;
  final int? colorValue;
  final DateTime createdAt;
  final int documentCount;

  TagEntity copyWith({
    String? id,
    String? name,
    int? colorValue,
    DateTime? createdAt,
    int? documentCount,
  }) {
    return TagEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      colorValue: colorValue ?? this.colorValue,
      createdAt: createdAt ?? this.createdAt,
      documentCount: documentCount ?? this.documentCount,
    );
  }

  @override
  List<Object?> get props => [id, name, colorValue, createdAt, documentCount];
}

