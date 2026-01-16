import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import '../../database/local_database.dart';
import 'package:go_router/go_router.dart';

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
  int currentPage =
      0; // 3baris ke bawah ini untuk pagination bukan scrool infinite
  int totalPage = 0;
  static const int pageSize = 100;

  final TextEditingController searchController = TextEditingController();

  List<Map<String, dynamic>> columns = [];
  late TableGridSource dataSource;
  Map<String, double> columnWidths = {};

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

  Future<void> _loadPage(int page) async {
    setState(() => loading = true);

    final raw = await LocalDatabase.instance.getPageData(
      widget.tableId,
      pageSize,
      page * pageSize,
    );

    dataSource.replaceWithRaw(raw);

    _calculateColumnWidths(dataSource.rows);

    setState(() {
      currentPage = page;
      loading = false;
    });
  }

  void _calculateColumnWidths(List<DataGridRow> rows) {
    final Map<String, double> widths = {};

    for (final col in columns) {
      final name = col['name'];
      double maxWidth = 80; // minimum width

      // ukur header
      final headerPainter = TextPainter(
        text: TextSpan(
          text: name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      maxWidth = headerPainter.width + 32;

      // ukur isi (ambil max dari baris yang tampil)
      for (final row in rows) {
        final cell = row.getCells().firstWhere((c) => c.columnName == name);
        final text = cell.value.toString();

        final painter = TextPainter(
          text: TextSpan(text: text, style: const TextStyle(fontSize: 14)),
          textDirection: TextDirection.ltr,
          maxLines: 1,
        )..layout();

        maxWidth = painter.width + 32 > maxWidth
            ? painter.width + 32
            : maxWidth;
      }

      // batasi supaya tidak terlalu lebar
      // widths[name] = maxWidth.clamp(80, 300);

      if (name.toUpperCase() == 'UPDATE') {
        widths[name] = maxWidth.clamp(80, 100); //ubah lebar kolom UPDATE
      } else {
        widths[name] = maxWidth.clamp(20, 300);
      }
    }

    setState(() {
      columnWidths = widths;
    });
  }

  // ================= INIT =================
  Future<void> _init() async {
    final table = await LocalDatabase.instance.getTableById(widget.tableId);
    tableName = table?['name'] ?? '';

    columns = await LocalDatabase.instance.getColumns(widget.tableId);

    totalRows = await LocalDatabase.instance.getRowCount(widget.tableId);
    shownRows = totalRows;

    totalPage = (totalRows / pageSize)
        .ceil(); //in ipagination bukan scrool infinite

    dataSource = TableGridSource(tableId: widget.tableId, columns: columns);

    // await dataSource.loadInitial(); uncoment kalau mau infinite scroll
    await _loadPage(0); //ini untuk pagination bukan scrool infinite

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
          // Tombol scan QR
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: () async {
              final result = await context.push('/scanner');
              if (result != null && result is String) {
                searchController.text = result;
                await _search(result);
              }
            },
          ),

          // Tombol search teks (yang lama)
          IconButton(
            icon: Icon(isSearching ? Icons.close : Icons.search),
            onPressed: () async {
              if (isSearching) {
                searchController.clear();
                isSearching = false;
                shownRows = totalRows;
                await _loadPage(0);
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
              headerRowHeight: 32,
              columnWidthMode:
                  ColumnWidthMode.fitByColumnName, //ubah lebar di dalam kotak
              rowHeight: 40, //tinggi per kotak di dalam tabel
              // loadMoreViewBuilder: (context, loadMoreRows) {
              //   return FutureBuilder(
              //     future: loadMoreRows(),
              //     builder: (context, snapshot) {
              //       return const SizedBox(
              //         height: 56,
              //         child: Center(child: CircularProgressIndicator()),
              //       );
              //     },
              //   );
              // }, //uncomment ini jika ingin menampilkan loading di bawah saat load more
              columns: columns.map((c) {
                final name = c['name'];
                return GridColumn(
                  columnName: name,
                  width: columnWidths[name] ?? 120, //auto width
                  label: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 2,
                      horizontal: 6,
                    ),
                    child: Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
      // ================= PAGINATION BAR =================
      bottomNavigationBar: isSearching
          ? null
          : Container(
              padding: const EdgeInsets.symmetric(vertical: 0),
              color: const Color(0xFF0E5A6F),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // ⏮️ ke halaman pertama
                  IconButton(
                    icon: const Icon(Icons.first_page, color: Colors.white),
                    onPressed: currentPage > 0 ? () => _loadPage(0) : null,
                  ),

                  // ◀️ halaman sebelumnya
                  IconButton(
                    icon: const Icon(Icons.chevron_left, color: Colors.white),
                    onPressed: currentPage > 0
                        ? () => _loadPage(currentPage - 1)
                        : null,
                  ),

                  // indikator halaman
                  Text(
                    '${currentPage + 1} / $totalPage',
                    style: const TextStyle(color: Colors.white),
                  ),

                  // ▶️ halaman berikutnya
                  IconButton(
                    icon: const Icon(Icons.chevron_right, color: Colors.white),
                    onPressed: currentPage < totalPage - 1
                        ? () => _loadPage(currentPage + 1)
                        : null,
                  ),

                  // ⏭️ ke halaman terakhir
                  IconButton(
                    icon: const Icon(Icons.last_page, color: Colors.white),
                    onPressed: currentPage < totalPage - 1
                        ? () => _loadPage(totalPage - 1)
                        : null,
                  ),
                ],
              ),
            ),
    );
  }
}

// ================= DATA SOURCE =================
class TableGridSource extends DataGridSource {
  final int tableId;
  final List<Map<String, dynamic>> columns;

  static const int pageSize = 100; // Jumlah baris per halaman
  int pageIndex = 0;
  // bool hasMore = true; ini diuncomment jika ingin load more otomatis saat scroll

  final List<DataGridRow> _rows = [];

  TableGridSource({required this.tableId, required this.columns});

  @override
  List<DataGridRow> get rows => _rows;

  // Load awal (dipanggil dari init)
  Future<void> loadInitial() async {
    _rows.clear();
    pageIndex = 0;
    // hasMore = true;
    notifyListeners();
    await _loadNext();
  }

  // Dipanggil otomatis oleh SfDataGrid (VIRTUAL SCROLL)
  // @override
  // Future<void> handleLoadMoreRows() async {
  //   if (!hasMore) return;
  //   await _loadNext();
  // } ini diuncomment jika ingin load more otomatis saat scroll

  Future<void> _loadNext() async {
    final raw = await LocalDatabase.instance.getPageData(
      tableId,
      pageSize,
      pageIndex * pageSize, // OFFSET BERDASARKAN ROW
    );

    if (raw.isEmpty) {
      // hasMore = false;
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
    // hasMore = false;
    notifyListeners();
  }

  /// 🔁 Ganti data langsung dengan DataGridRow
  void replaceWithRows(List<DataGridRow> rows) {
    _rows
      ..clear()
      ..addAll(rows);
    // hasMore = false;
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
        final column = cell.columnName.toUpperCase();
        String value = cell.value.toString();

        // ===== FORMAT DATE UNTUK KOLOM UPDATE =====
        if (column == 'UPDATE' && value.contains('-')) {
          try {
            final date = DateTime.parse(value);
            const months = [
              'JAN',
              'FEB',
              'MAR',
              'APR',
              'MAY',
              'JUN',
              'JUL',
              'AUG',
              'SEP',
              'OCT',
              'NOV',
              'DEC',
            ];
            value =
                '${date.day.toString().padLeft(2, '0')} '
                '${months[date.month - 1]} '
                '${date.year}';
          } catch (_) {
            // kalau gagal parse, biarkan value asli
          }
        }

        // ================= FORMAT HET (1.000.000) =================
        if (column == 'HET') {
          final num? number = num.tryParse(
            value.replaceAll(',', '').replaceAll('.', ''),
          );
          if (number != null) {
            value = _formatRupiah(number.toInt());
          }
        }

        // ===== ALIGNMENT =====
        final isRightAlign = column == 'HET';

        //biar supersede tidak turun baris
        final isSupersede = column == 'SUPERSEDE';

        return Padding(
          padding: const EdgeInsets.all(8),
          child: isSupersede
              ? SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Text(value, style: const TextStyle(fontSize: 14)),
                )
              : Container(
                  alignment: isRightAlign
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Text(
                    value,
                    maxLines: 3,
                    softWrap: true,
                    overflow: TextOverflow.fade,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),

          // : Align(
          //     alignment:
          //         isRightAlign ? Alignment.centerRight : Alignment.centerLeft,
          //     child: Text(
          //       value,
          //       maxLines: 3,
          //       softWrap: true,
          //       overflow: TextOverflow.fade,
          //       style: const TextStyle(fontSize: 14),
          //     ),
          //   ),
          // : Text(
          //     value,
          //     textAlign: isRightAlign ? TextAlign.right : TextAlign.left,
          //     maxLines: 3,
          //     softWrap: true,
          //     overflow: TextOverflow.fade,
          //     style: const TextStyle(fontSize: 14),
          //   ), //ubah ukuran tabel
        );
      }).toList(),
    );
  }
}

String _formatRupiah(int value) {
  final s = value.toString();
  final buffer = StringBuffer();

  for (int i = 0; i < s.length; i++) {
    buffer.write(s[s.length - 1 - i]);
    if ((i + 1) % 3 == 0 && i + 1 != s.length) {
      buffer.write('.');
    }
  }

  return buffer.toString().split('').reversed.join();
}
