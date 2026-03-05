import 'package:flutter/material.dart';
import 'widgets/room_card.dart';
import 'models/room_status.dart';
import 'models/room_db.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = await RoomStatusStore.load();
  runApp(RoomStatus(notifier: store, child: const MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hotel Manager',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Hotel Manager Home Page'),
    );
  }
}

class MyHomePage extends StatelessWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: const Center(
        child: HomeInfo(),
      ),
    );
  }
}

class HomeInfo extends StatelessWidget {
  const HomeInfo({super.key});

  @override
  Widget build(BuildContext context) {
    return const _RoomsList();
  }
}

class _RoomsList extends StatefulWidget {
  const _RoomsList();

  @override
  State<_RoomsList> createState() => _RoomsListState();
}

class _RoomsListState extends State<_RoomsList> {
  List<Map<String, dynamic>> _rooms = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadRooms();
  }

  Future<void> _loadRooms() async {
    final rows = await RoomDb.getAllRooms();
    setState(() {
      _rooms = rows;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final maxWidth = screenWidth * 0.95;
    if (_loading) return const Center(child: CircularProgressIndicator());
    const cardWidth = 400;
    int crossAxisCount = (maxWidth / cardWidth).floor();
    crossAxisCount = crossAxisCount > 0 ? crossAxisCount : 1;
    return Center(
      child: ConstrainedBox(
        // Allow wider layout so cards can take two-column layout on large screens
        constraints:
            BoxConstraints(maxWidth: maxWidth > 1200 ? 1200 : maxWidth),
        child: MasonryGridView.count(
          padding: const EdgeInsets.all(12),
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          itemCount: _rooms.length,
          itemBuilder: (ctx, idx) {
            final r = _rooms[idx];
            final rn = r['room_number']?.toString() ?? '';
            final price = (r['price_per_night'] is num)
                ? (r['price_per_night'] as num).toDouble()
                : null;
            final priceHourly = (r['price_hourly'] is num)
                ? (r['price_hourly'] as num).toDouble()
                : null;
            final amenities = (r['amenities'] as String?)
                ?.split(',')
                .map((s) => s.trim())
                .where((s) => s.isNotEmpty)
                .toList();
            final guestName = r['guest_name'] as String?;
            final guestId = r['id_card'] as String?;
            final guestContact = r['contact'] as String?;
            final checkIn = r['check_in_time']?.toString();
            final checkOut = r['check_out_time']?.toString();
            final deposit =
                (r['deposit'] is num) ? (r['deposit'] as num).toInt() : null;
            final capacity =
                (r['capacity'] is num) ? (r['capacity'] as num).toInt() : null;
            final occupancyCount = (r['occupancy_count'] is num)
                ? (r['occupancy_count'] as num).toInt()
                : 0;

            return RoomCard(
              roomNumber: rn,
              status: '空闲',
              guestName: guestName,
              guestId: guestId,
              guestContact: guestContact,
              checkInTime: checkIn,
              checkOutTime: checkOut,
              price: price,
              priceHourly: priceHourly,
              deposit: deposit,
              capacity: capacity,
              occupancyCount: occupancyCount,
              amenities: amenities,
              onCheckIn: () {},
              onDetails: () {},
              onStatusChanged: (s) {},
            );
          },
        ),
      ),
    );
  }
}
