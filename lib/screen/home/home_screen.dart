import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../database/local_database.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, dynamic>> allDatabases = [];
  List<Map<String, dynamic>> databases = [];

  bool isLoading = true;
  bool isSearching = false;

  final TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadDatabases();
  }

  Future<void> _loadDatabases() async {
    final data = await LocalDatabase.instance.getDatabases();
    setState(() {
      allDatabases = data;
      databases = data;
      isLoading = false;
    });
  }

  // ================= SEARCH =================
  void _filterDatabases(String query) {
    final q = query.toLowerCase();
    setState(() {
      databases = allDatabases
          .where((db) => db['name'].toString().toLowerCase().contains(q))
          .toList();
    });
  }

  // ================= ADD DATABASE =================
  Future<void> _showAddDatabaseDialog() async {
    final controller = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Database'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Database name'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = controller.text.trim();
                if (name.isEmpty) return;

                await LocalDatabase.instance.insertDatabase(name);
                Navigator.pop(context);
                _loadDatabases();
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
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
                  hintText: 'Search database...',
                  border: InputBorder.none,
                ),
                onChanged: _filterDatabases,
              )
            : const Text('Databases'),
        actions: [
          IconButton(
            icon: Icon(isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                if (isSearching) {
                  searchController.clear();
                  databases = allDatabases;
                }
                isSearching = !isSearching;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddDatabaseDialog,
          ),
          IconButton(icon: const Icon(Icons.more_vert), onPressed: () {}),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : databases.isEmpty
          ? const Center(
              child: Text(
                'No databases',
                style: TextStyle(fontSize: 18, color: Colors.white70),
              ),
            )
          : ListView.separated(
              itemCount: databases.length,
              separatorBuilder: (_, __) => const Divider(color: Colors.white24),
              itemBuilder: (context, index) {
                final db = databases[index];
                return ListTile(
                  leading: const Icon(Icons.storage),
                  title: Text(db['name']),
                  // Tap biasa → masuk database
                  onTap: () {
                    context.push('/database/${db['id']}');
                  },

                  // LONG PRESS → konfirmasi hapus database
                  onLongPress: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Hapus Database'),
                        content: Text(
                          'Yakin ingin menghapus database "${db['name']}"?\n\nSemua tabel dan data akan ikut terhapus.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Batal'),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                            ),
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Hapus'),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      await LocalDatabase.instance.deleteDatabase(db['id']);
                      await _loadDatabases(); // refresh list
                    }
                  },
                );
              },
            ),
    );
  }
}
