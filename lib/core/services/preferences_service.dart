import 'package:sqflite/sqflite.dart';
import '../database/app_database.dart';

/// Service for storing and retrieving lightweight local user preferences in SQLite.
abstract class PreferencesService {
  Future<String?> getString(String key);
  Future<void> setString(String key, String value);
  Future<String> getViewMode();
  Future<void> setViewMode(String mode);
  Future<String> getSortOption();
  Future<void> setSortOption(String option);
}

class PreferencesServiceImpl implements PreferencesService {
  const PreferencesServiceImpl(this._appDatabase);

  final AppDatabase _appDatabase;

  static const String keyViewMode = 'view_mode';
  static const String keySortOption = 'sort_option';

  @override
  Future<String?> getString(String key) async {
    try {
      final db = await _appDatabase.database;
      final results = await db.query(
        'app_preferences',
        where: 'key = ?',
        whereArgs: [key],
        limit: 1,
      );
      if (results.isEmpty) return null;
      return results.first['value'] as String?;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> setString(String key, String value) async {
    try {
      final db = await _appDatabase.database;
      await db.insert(
        'app_preferences',
        {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (_) {}
  }

  @override
  Future<String> getViewMode() async {
    final val = await getString(keyViewMode);
    return val ?? 'list';
  }

  @override
  Future<void> setViewMode(String mode) async {
    await setString(keyViewMode, mode);
  }

  @override
  Future<String> getSortOption() async {
    final val = await getString(keySortOption);
    return val ?? 'newest';
  }

  @override
  Future<void> setSortOption(String option) async {
    await setString(keySortOption, option);
  }
}

