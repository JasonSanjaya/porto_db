import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';

import '../../database/local_database.dart';

class DatabaseDetailScreen extends StatefulWidget {
  final String databaseId;
  const DatabaseDetailScreen({super.key, required this.databaseId});

  @override
  State<DatabaseDetailScreen> createState() => _DatabaseDetailScreenState();
}

class _DatabaseDetailScreenState extends State<DatabaseDetailScreen> {
  String databaseName = '';

  List<Map<String, dynamic>> allTables = [];
  List<Map<String, dynamic>> tables = [];

  bool isLoading = true;
  bool isSearching = false;
  bool isImporting = false;

  final TextEditingController searchController = TextEditingController();

  int get dbId => int.parse(widget.databaseId);

  @override
  void initState() {
    super.initState();
    _loadDatabaseName();
    _loadTables();
  }

  // ================= LOAD DATABASE NAME =================
  Future<void> _loadDatabaseName() async {
    final db = await LocalDatabase.instance.getDatabaseById(dbId);
    if (!mounted) return;
    if (db != null) {
      setState(() => databaseName = db['name']);
    }
  }

  // ================= LOAD TABLES =================
  Future<void> _loadTables() async {
    final data = await LocalDatabase.instance.getTables(dbId);
    if (!mounted) return;
    setState(() {
      allTables = data;
      tables = data;
      isLoading = false;
    });
  }

  // ================= SEARCH =================
  void _filterTables(String query) {
    final q = query.toLowerCase();
    setState(() {
      tables = allTables
          .where((t) => t['name'].toString().toLowerCase().contains(q))
          .toList();
    });
  }

  // ================= IMPORT CSV (FIXED) =================
  Future<void> _importCsv() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    if (result == null) return;

    setState(() => isImporting = true);

    final file = File(result.files.single.path!);
    final tableName = result.files.single.name.replaceAll('.csv', '');

    final tableId = await LocalDatabase.instance.insertTable(
      databaseId: dbId,
      name: tableName,
    );

    final stream = file
        .openRead()
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    final converter = CsvToListConverter(
      fieldDelimiter: ',',
      textDelimiter: '"',
      shouldParseNumbers: false,
    );

    bool headerInserted = false;
    final columnIds = <int>[];

    int rowCount = 0;

    await for (final line in stream) {
      if (line.trim().isEmpty) continue;

      final rows = converter.convert(line);
      if (rows.isEmpty) continue;

      final data = rows.first;

      // HEADER
      if (!headerInserted) {
        for (final col in data) {
          final id = await LocalDatabase.instance.insertColumn(
            tableId: tableId,
            name: col.toString().trim(),
          );
          columnIds.add(id);
        }
        headerInserted = true;
        continue;
      }

      // DATA
      final rowId = await LocalDatabase.instance.insertRow(tableId);

      for (int i = 0; i < columnIds.length; i++) {
        final value = i < data.length ? data[i].toString() : '';
        await LocalDatabase.instance.setCellValue(
          rowId: rowId,
          columnId: columnIds[i],
          value: value,
        );
      }

      rowCount++;
      if (rowCount % 500 == 0) {
        await Future.delayed(Duration.zero);
      }
    }

    // 🔥 PENTING: REFRESH DULU BARU MATIKAN LOADING
    await _loadTables();

    if (!mounted) return;
    setState(() {
      isImporting = false;
      isSearching = false;
      searchController.clear();
    });
  }

  // ================= ADD TABLE =================
  Future<void> _showAddTableDialog() async {
    final controller = TextEditingController();

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Table name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Enter table name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('BATAL'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.trim().isEmpty) return;
              await LocalDatabase.instance.insertTable(
                databaseId: dbId,
                name: controller.text.trim(),
              );
              Navigator.pop(context);
              await _loadTables();
            },
            child: const Text('OKE'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteTable(int tableId, String tableName) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Hapus Table'),
        content: Text(
          'Yakin ingin menghapus table "$tableName"?\n\nData akan hilang permanen.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (result == true) {
      await LocalDatabase.instance.deleteTable(tableId);
      await _loadTables(); // refresh list setelah hapus
    }
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0E5A6F),
        title: isSearching
            ? TextField(
                controller: searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search table...',
                  border: InputBorder.none,
                ),
                onChanged: _filterTables,
              )
            : Text(databaseName),
        actions: [
          IconButton(
            icon: Icon(isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                if (isSearching) {
                  searchController.clear();
                  tables = allTables;
                }
                isSearching = !isSearching;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddTableDialog,
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'import_csv') _importCsv();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'import_csv',
                child: Text('Import table (CSV)'),
              ),
            ],
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                ListView.separated(
                  itemCount: tables.length,
                  separatorBuilder: (_, __) =>
                      const Divider(color: Colors.white24),
                  itemBuilder: (context, index) {
                    final table = tables[index];
                    return ListTile(
                      leading: const Icon(Icons.table_chart),
                      title: Text(table['name']),
                      onTap: () {
                        context.push('/table/${table['id']}');
                      },
                      onLongPress: () {
                        _confirmDeleteTable(table['id'], table['name']);
                      },
                    );
                  },
                ),
                if (isImporting)
                  Container(
                    color: Colors.black54,
                    child: const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text(
                            'Importing CSV...',
                            style: TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
