import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class LocalDatabase {
  LocalDatabase._internal();
  static final LocalDatabase instance = LocalDatabase._internal();

  static Database? _database;

  // =========================
  // DATABASE INSTANCE
  // =========================
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  // =========================
  // INIT DATABASE
  // =========================
  Future<Database> _initDatabase() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = join(dir.path, 'porto_db_v5.sqlite');

    final db = await openDatabase(path, version: 1, onCreate: _onCreate);

    // LIKE konsisten
    await db.execute('PRAGMA case_sensitive_like = OFF');
    await db.execute('PRAGMA foreign_keys = ON');

    return db;
  }

  // =====================================================
  // ===================== META ==========================
  // =====================================================

  /// 🔢 Hitung total row (jumlah baris data)
  Future<int> getRowCount(int tableId) async {
    final db = await database;
    final res = await db.rawQuery(
      'SELECT COUNT(*) FROM rows WHERE table_id = ?',
      [tableId],
    );
    return Sqflite.firstIntValue(res) ?? 0;
  }

  // =====================================================
  // ===================== SCHEMA ========================
  // =====================================================

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE databases (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE tables (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        database_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        FOREIGN KEY (database_id) REFERENCES databases(id)
          ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE columns (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        table_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        FOREIGN KEY (table_id) REFERENCES tables(id)
          ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE rows (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        table_id INTEGER NOT NULL,
        FOREIGN KEY (table_id) REFERENCES tables(id)
          ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE cells (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        row_id INTEGER NOT NULL,
        column_id INTEGER NOT NULL,
        value TEXT,
        FOREIGN KEY (row_id) REFERENCES rows(id)
          ON DELETE CASCADE,
        FOREIGN KEY (column_id) REFERENCES columns(id)
          ON DELETE CASCADE
      )
    ''');

    // ================= INDEX (WAJIB UNTUK PERFORMA)
    await db.execute('CREATE INDEX idx_rows_table ON rows(table_id)');
    await db.execute('CREATE INDEX idx_cells_row ON cells(row_id)');
    await db.execute('CREATE INDEX idx_cells_column ON cells(column_id)');
    await db.execute('CREATE INDEX idx_cells_value ON cells(value)');
  }

  Future<void> deleteTable(int tableId) async {
    final db = await database;

    // hapus isi cell
    await db.delete(
      'cells',
      where: 'row_id IN (SELECT id FROM rows WHERE table_id = ?)',
      whereArgs: [tableId],
    );

    // hapus rows
    await db.delete('rows', where: 'table_id = ?', whereArgs: [tableId]);

    // hapus columns
    await db.delete('columns', where: 'table_id = ?', whereArgs: [tableId]);

    // hapus table
    await db.delete('tables', where: 'id = ?', whereArgs: [tableId]);
  }

  // =====================================================
  // ===================== PAGINATION ====================
  // =====================================================

  /// 🔥 Pagination berbasis ROW (BUKAN cell)
  /// Digunakan oleh virtual scroll
  Future<List<Map<String, dynamic>>> getPageData(
    int tableId,
    int limit,
    int offset,
  ) async {
    final db = await database;

    return db.rawQuery(
      '''
      SELECT r.id AS row_id,
             c.column_id,
             c.value
      FROM rows r
      JOIN cells c ON c.row_id = r.id
      WHERE r.table_id = ?
        AND r.id IN (
          SELECT id
          FROM rows
          WHERE table_id = ?
          ORDER BY id
          LIMIT ? OFFSET ?
        )
      ORDER BY r.id
      ''',
      [tableId, tableId, limit, offset],
    );
  }

  /// 🔍 Ambil data berdasarkan row_id list (untuk search)
  Future<List<Map<String, dynamic>>> getRowsByIds(
    int tableId,
    List<int> rowIds,
  ) async {
    if (rowIds.isEmpty) return [];

    final db = await database;
    final placeholders = List.filled(rowIds.length, '?').join(',');

    return db.rawQuery(
      '''
      SELECT r.id AS row_id,
             c.column_id,
             c.value
      FROM rows r
      JOIN cells c ON c.row_id = r.id
      WHERE r.table_id = ?
        AND r.id IN ($placeholders)
      ORDER BY r.id
      ''',
      [tableId, ...rowIds],
    );
  }

  // =====================================================
  // ======================= SEARCH ======================
  // =====================================================

  /// 🔎 Search GLOBAL & PRESISI
  /// "35" → hanya yang mengandung "35"
  Future<List<Map<String, dynamic>>> searchRows(
    int tableId,
    String query,
  ) async {
    final db = await database;

    return db.rawQuery(
      '''
      SELECT DISTINCT r.id
      FROM rows r
      JOIN cells c ON c.row_id = r.id
      WHERE r.table_id = ?
        AND c.value LIKE ?
      ORDER BY r.id
      ''',
      [tableId, '%${query.trim()}%'],
    );
  }

  // =====================================================
  // ======================= CRUD ========================
  // =====================================================

  Future<Map<String, dynamic>?> getDatabaseById(int id) async {
    final db = await database;
    final res = await db.query('databases', where: 'id = ?', whereArgs: [id]);
    return res.isEmpty ? null : res.first;
  }

  Future<List<Map<String, dynamic>>> getDatabases() async {
    final db = await database;
    return db.query('databases', orderBy: 'created_at DESC');
  }

  Future<int> insertDatabase(String name) async {
    final db = await database;
    return db.insert('databases', {
      'name': name,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<Map<String, dynamic>?> getTableById(int id) async {
    final db = await database;
    final res = await db.query('tables', where: 'id = ?', whereArgs: [id]);
    return res.isEmpty ? null : res.first;
  }

  Future<List<Map<String, dynamic>>> getTables(int databaseId) async {
    final db = await database;
    return db.query(
      'tables',
      where: 'database_id = ?',
      whereArgs: [databaseId],
    );
  }

  Future<int> insertTable({
    required int databaseId,
    required String name,
  }) async {
    final db = await database;
    return db.insert('tables', {'database_id': databaseId, 'name': name});
  }

  Future<List<Map<String, dynamic>>> getColumns(int tableId) async {
    final db = await database;
    return db.query('columns', where: 'table_id = ?', whereArgs: [tableId]);
  }

  Future<int> insertColumn({required int tableId, required String name}) async {
    final db = await database;
    return db.insert('columns', {'table_id': tableId, 'name': name});
  }

  /// 🔥 1 insertRow = 1 baris Excel
  Future<int> insertRow(int tableId) async {
    final db = await database;
    return db.insert('rows', {'table_id': tableId});
  }

  /// 🔥 Isi cell per kolom
  Future<void> setCellValue({
    required int rowId,
    required int columnId,
    required String value,
  }) async {
    final db = await database;
    await db.insert('cells', {
      'row_id': rowId,
      'column_id': columnId,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> insertRowsBatch({
  required int tableId,
  required List<int> columnIds,
  required List<List<String>> rows,
}) async {
  final db = await database;

  await db.transaction((txn) async {
    final batch = txn.batch();

    for (final row in rows) {
      final rowId = await txn.insert('rows', {
        'table_id': tableId,
      });

      for (int i = 0; i < columnIds.length; i++) {
        batch.insert('cells', {
          'row_id': rowId,
          'column_id': columnIds[i],
          'value': row[i],
        });
      }
    }

    await batch.commit(noResult: true);
  });
}


  // =========================
  // CLOSE
  // =========================
  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}
