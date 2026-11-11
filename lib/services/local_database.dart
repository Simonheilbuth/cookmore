import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;

/// Opens and owns the local SQLite database.
///
/// SQLite is the "source of truth" on the device: everything the user
/// creates is written here first, so the app works fully offline.
/// Android and iOS use the native sqflite plugin; Windows and Linux use the
/// FFI implementation with a bundled SQLite library.
class LocalDatabase {
  static const String _fileName = 'cookmore.db';
  static const int _version = 1;

  Database? _db;

  Database get db {
    final database = _db;
    if (database == null) {
      throw StateError('LocalDatabase.open() must be called before use.');
    }
    return database;
  }

  static bool get _usesFfi => Platform.isWindows || Platform.isLinux;

  Future<void> open() async {
    if (_db != null) return;

    final DatabaseFactory factory;
    if (_usesFfi) {
      ffi.sqfliteFfiInit();
      factory = ffi.databaseFactoryFfi;
    } else {
      factory = databaseFactory;
    }

    final path = await _databasePath(factory);
    _db = await factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: _version,
        // Needed for ON DELETE CASCADE between profiles and their data.
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: _createSchema,
      ),
    );
  }

  Future<String> _databasePath(DatabaseFactory factory) async {
    if (_usesFfi) {
      // Store the file in the user's app data folder on desktop.
      final dir = await getApplicationSupportDirectory();
      await dir.create(recursive: true);
      return p.join(dir.path, _fileName);
    }
    return p.join(await factory.getDatabasesPath(), _fileName);
  }

  Future<void> _createSchema(Database db, int version) async {
    final batch = db.batch();

    batch.execute('''
      CREATE TABLE profiles (
        id TEXT PRIMARY KEY,
        nickname TEXT NOT NULL,
        avatar TEXT NOT NULL,
        diet TEXT NOT NULL,
        theme_mode TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )''');

    // A favourite keeps a full copy of the recipe so it can be read offline.
    batch.execute('''
      CREATE TABLE favourites (
        profile_id TEXT NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
        recipe_id TEXT NOT NULL,
        name TEXT NOT NULL,
        recipe_json TEXT NOT NULL,
        saved_at INTEGER NOT NULL,
        PRIMARY KEY (profile_id, recipe_id)
      )''');

    batch.execute('''
      CREATE TABLE pantry_items (
        profile_id TEXT NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
        name TEXT NOT NULL,
        PRIMARY KEY (profile_id, name)
      )''');

    batch.execute('''
      CREATE TABLE shopping_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        profile_id TEXT NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
        name TEXT NOT NULL,
        measure TEXT NOT NULL DEFAULT '',
        recipe_name TEXT,
        checked INTEGER NOT NULL DEFAULT 0
      )''');

    // Recently viewed recipes, shared by all profiles (not personal data).
    batch.execute('''
      CREATE TABLE recipe_cache (
        recipe_id TEXT PRIMARY KEY,
        recipe_json TEXT NOT NULL,
        cached_at INTEGER NOT NULL
      )''');

    // Profiles with local changes that have not reached the cloud yet.
    batch.execute('''
      CREATE TABLE pending_sync (
        profile_id TEXT PRIMARY KEY,
        operation TEXT NOT NULL,
        queued_at INTEGER NOT NULL
      )''');

    // Small key/value settings, e.g. the last selected profile.
    batch.execute('''
      CREATE TABLE app_settings (
        key TEXT PRIMARY KEY,
        value TEXT
      )''');

    await batch.commit(noResult: true);
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
