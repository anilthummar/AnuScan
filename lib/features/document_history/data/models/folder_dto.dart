import '../../domain/entities/folder_entity.dart';

class FolderDto {
  const FolderDto({
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
  final int createdAt; // epoch ms
  final int updatedAt; // epoch ms
  final int documentCount;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'color_value': colorValue,
      'icon_name': iconName,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  factory FolderDto.fromMap(Map<String, dynamic> map, {int documentCount = 0}) {
    return FolderDto(
      id: map['id'] as String,
      name: map['name'] as String,
      colorValue: (map['color_value'] as num?)?.toInt(),
      iconName: map['icon_name'] as String?,
      createdAt: (map['created_at'] as num).toInt(),
      updatedAt: (map['updated_at'] as num).toInt(),
      documentCount: documentCount,
    );
  }

  factory FolderDto.fromEntity(FolderEntity entity) {
    return FolderDto(
      id: entity.id,
      name: entity.name,
      colorValue: entity.colorValue,
      iconName: entity.iconName,
      createdAt: entity.createdAt.millisecondsSinceEpoch,
      updatedAt: entity.updatedAt.millisecondsSinceEpoch,
      documentCount: entity.documentCount,
    );
  }

  FolderEntity toEntity() {
    return FolderEntity(
      id: id,
      name: name,
      colorValue: colorValue,
      iconName: iconName,
      createdAt: DateTime.fromMillisecondsSinceEpoch(createdAt),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(updatedAt),
      documentCount: documentCount,
    );
  }
}

