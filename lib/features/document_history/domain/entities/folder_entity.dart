import 'package:equatable/equatable.dart';

/// Represents a single-level organizational folder for documents.
class FolderEntity extends Equatable {
  const FolderEntity({
    required this.id,
    required this.name,
    this.colorValue,
    this.iconName,
    required this.createdAt,
    required this.updatedAt,
    this.documentCount = 0,
  });

  final String id;
  final String name;
  final int? colorValue;
  final String? iconName;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int documentCount;

  FolderEntity copyWith({
    String? id,
    String? name,
    int? colorValue,
    String? iconName,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? documentCount,
  }) {
    return FolderEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      colorValue: colorValue ?? this.colorValue,
      iconName: iconName ?? this.iconName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      documentCount: documentCount ?? this.documentCount,
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    colorValue,
    iconName,
    createdAt,
    updatedAt,
    documentCount,
  ];
}

