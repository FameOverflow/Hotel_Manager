import 'package:flutter/widgets.dart';
import 'room_db.dart';

/// Room status store backed by SQLite (RoomDb).
class RoomStatusStore extends ValueNotifier<Map<String, String>> {
  RoomStatusStore([Map<String, String>? initial])
      : super(Map.from(initial ?? {}));

  String getStatus(String roomNumber) => value[roomNumber] ?? '空闲';

  /// Set status and persist to SQLite (fire-and-forget).
  void setStatus(String roomNumber, String status) {
    RoomDb.setStatus(roomNumber, status);
    value = {...value, roomNumber: status};
    if (status == '空闲') {
      _occupancyCount[roomNumber] = 0;
    }
  }

  void toggleStatus(String roomNumber) {
    final s = getStatus(roomNumber);
    if (s == '入住') return;
    setStatus(roomNumber, s == '空闲' ? '停住' : '空闲');
  }

  final Map<String, int> _occupancyCount = {};
  int getOccupancyCount(String roomNumber) => _occupancyCount[roomNumber] ?? 0;
  void setOccupancyCount(String roomNumber, int count) {
    _occupancyCount[roomNumber] = count;
    notifyListeners();
  }

  /// Initialize DB and load persisted statuses.
  static Future<RoomStatusStore> load() async {
    await RoomDb.init();
    await RoomDb.initData();
    final map = await RoomDb.getAllStatuses();
    return RoomStatusStore(map);
  }

  /// Compute estimated fee for a given duration in hours.
  static int computeEstimatedFee(
    double duration,
    bool unit, //true为晚，false为时
    double? price,
    double? priceHourly,
    ) {
    if (unit) {
      return (duration * price!).round();
    } else {
      return (duration * priceHourly!).round();
    }
  }
}

/// Inherited widget wrapper to expose the [RoomStatusStore] to the tree.
class RoomStatus extends InheritedNotifier<ValueNotifier<Map<String, String>>> {
  const RoomStatus(
      {super.key, required RoomStatusStore notifier, required super.child})
      : super(notifier: notifier);

  static RoomStatusStore? of(BuildContext context) {
    final widget = context.dependOnInheritedWidgetOfExactType<RoomStatus>();
    return widget?.notifier as RoomStatusStore?;
  }
}
