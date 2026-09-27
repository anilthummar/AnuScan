import '../../domain/entities/tag_entity.dart';

class TagDto {
  const TagDto({
    required this.id,
    required this.name,
    this.colorValue,
    required this.createdAt,
    this.documentCount = 0,
  });

  final String id;
  final String name;
  final int? colorValue;
  final int createdAt; // epoch ms
  final int documentCount;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'color_value': colorValue,
      'created_at': createdAt,
    };
  }

  factory TagDto.fromMap(Map<String, dynamic> map, {int documentCount = 0}) {
    return TagDto(
      id: map['id'] as String,
      name: map['name'] as String,
      colorValue: (map['color_value'] as num?)?.toInt(),
      createdAt: (map['created_at'] as num).toInt(),
      documentCount: documentCount,
    );
  }

  factory TagDto.fromEntity(TagEntity entity) {
    return TagDto(
      id: entity.id,
      name: entity.name,
      colorValue: entity.colorValue,
      createdAt: entity.createdAt.millisecondsSinceEpoch,
      documentCount: entity.documentCount,
    );
  }

  TagEntity toEntity() {
    return TagEntity(
      id: id,
      name: name,
      colorValue: colorValue,
      createdAt: DateTime.fromMillisecondsSinceEpoch(createdAt),
      documentCount: documentCount,
    );
  }
}

