import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import '../../database/local_database.dart';

class TableDetailScreen extends StatefulWidget {
  final int tableId;
  const TableDetailScreen({super.key, required this.tableId});

  @override
  State<TableDetailScreen> createState() => _TableDetailScreenState();
}

class _TableDetailScreenState extends State<TableDetailScreen> {
  String tableName = '';
  bool loading = true;
  bool isSearching = false;

  final TextEditingController searchController = TextEditingController();

  List<Map<String, dynamic>> columns = [];
  late TableGridSource dataSource;

  int totalRows = 0;
  int shownRows = 0;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  // ================= INIT =================
  Future<void> _init() async {
    final table = await LocalDatabase.instance.getTableById(widget.tableId);
    tableName = table?['name'] ?? '';

    columns = await LocalDatabase.instance.getColumns(widget.tableId);

    totalRows = await LocalDatabase.instance.getRowCount(widget.tableId);
    shownRows = totalRows;

    dataSource = TableGridSource(tableId: widget.tableId, columns: columns);

    await dataSource.loadInitial();

    setState(() => loading = false);
  }

  // ================= SEARCH =================
  Future<void> _search(String query) async {
    if (query.isEmpty) {
      isSearching = false;
      shownRows = totalRows;
      await dataSource.loadInitial();
      setState(() {});
      return;
    }

    setState(() {
      loading = true;
      isSearching = true;
    });

    final ids = await LocalDatabase.instance.searchRows(widget.tableId, query);

    shownRows = ids.length;

    if (ids.isEmpty) {
      dataSource.replaceWithRows([]);
    } else {
      final raw = await LocalDatabase.instance.getRowsByIds(
        widget.tableId,
        ids.map((e) => e['id'] as int).toList(),
      );
      dataSource.replaceWithRaw(raw);
    }

    setState(() => loading = false);
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
                  hintText: 'Search...',
                  border: InputBorder.none,
                ),
                onChanged: _search,
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tableName, style: const TextStyle(fontSize: 16)),
                  Text(
                    isSearching ? '$shownRows results' : '$totalRows rows',
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ],
              ),
        actions: [
          IconButton(
            icon: Icon(isSearching ? Icons.close : Icons.search),
            onPressed: () async {
              if (isSearching) {
                searchController.clear();
                isSearching = false;
                shownRows = totalRows;
                await dataSource.loadInitial();
                setState(() {});
              } else {
                setState(() => isSearching = true);
              }
            },
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : SfDataGrid(
              source: dataSource,
              columnWidthMode: ColumnWidthMode.fill,
              loadMoreViewBuilder: (context, loadMoreRows) {
                return FutureBuilder(
                  future: loadMoreRows(),
                  builder: (context, snapshot) {
                    return const SizedBox(
                      height: 56,
                      child: Center(child: CircularProgressIndicator()),
                    );
                  },
                );
              },
              columns: columns.map((c) {
                return GridColumn(
                  columnName: c['name'],
                  label: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      c['name'],
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                );
              }).toList(),
            ),
    );
  }
}

// ================= DATA SOURCE =================
class TableGridSource extends DataGridSource {
  final int tableId;
  final List<Map<String, dynamic>> columns;

  static const int pageSize = 50;
  int pageIndex = 0;
  bool hasMore = true;

  final List<DataGridRow> _rows = [];

  TableGridSource({required this.tableId, required this.columns});

  @override
  List<DataGridRow> get rows => _rows;

  // Load awal (dipanggil dari init)
  Future<void> loadInitial() async {
    _rows.clear();
    pageIndex = 0;
    hasMore = true;
    notifyListeners();
    await _loadNext();
  }

  // Dipanggil otomatis oleh SfDataGrid (VIRTUAL SCROLL)
  @override
  Future<void> handleLoadMoreRows() async {
    if (!hasMore) return;
    await _loadNext();
  }

  Future<void> _loadNext() async {
    final raw = await LocalDatabase.instance.getPageData(
      tableId,
      pageSize,
      pageIndex * pageSize, // OFFSET BERDASARKAN ROW
    );

    if (raw.isEmpty) {
      hasMore = false;
      return;
    }

    _rows.addAll(_buildRows(raw));
    pageIndex++;
    notifyListeners();
  }

  // Dipakai saat SEARCH
  void replaceWithRaw(List<Map<String, dynamic>> raw) {
    _rows
      ..clear()
      ..addAll(_buildRows(raw));
    hasMore = false;
    notifyListeners();
  }

    /// 🔁 Ganti data langsung dengan DataGridRow
  void replaceWithRows(List<DataGridRow> rows) {
    _rows
      ..clear()
      ..addAll(rows);
    hasMore = false;
    notifyListeners();
  }

  List<DataGridRow> _buildRows(List<Map<String, dynamic>> raw) {
    final Map<int, Map<int, String>> grouped = {};

    for (final r in raw) {
      grouped.putIfAbsent(r['row_id'], () => {});
      grouped[r['row_id']]![r['column_id']] = r['value']?.toString() ?? '';
    }

    return grouped.entries.map((entry) {
      return DataGridRow(
        cells: columns.map((c) {
          return DataGridCell(
            columnName: c['name'],
            value: entry.value[c['id']] ?? '',
          );
        }).toList(),
      );
    }).toList();
  }

  @override
  DataGridRowAdapter buildRow(DataGridRow row) {
    return DataGridRowAdapter(
      cells: row.getCells().map((cell) {
        return Padding(
          padding: const EdgeInsets.all(8),
          child: Text(cell.value.toString(), overflow: TextOverflow.ellipsis),
        );
      }).toList(),
    );
  }
}


