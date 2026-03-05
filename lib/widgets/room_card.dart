import 'package:flutter/material.dart';
import '../models/room_status.dart';
import '../models/room_db.dart';

class RoomCard extends StatefulWidget {
  const RoomCard({
    super.key,
    required this.roomNumber,
    required this.status,
    this.guestName,
    this.guestId,
    this.guestContact,
    this.checkInTime,
    this.checkOutTime,
    this.price,
    this.priceHourly,
    this.deposit,
    this.capacity,
    this.occupancyCount=0,
    this.amenities,
    this.onCheckIn,
    this.onDetails,
    this.onStatusChanged,
  });

  final String roomNumber;
  final String status;
  final String? guestName;
  final String? guestId;
  final String? guestContact;
  final String? checkInTime;
  final String? checkOutTime;
  final double? price;
  final double? priceHourly;
  final int? deposit;
  final int? capacity;
  final int? occupancyCount;
  final List<String>? amenities;
  final VoidCallback? onCheckIn;
  final VoidCallback? onDetails;
  final ValueChanged<String>? onStatusChanged;

  @override
  State<RoomCard> createState() => _RoomCardState();
}

class _RoomCardState extends State<RoomCard> {
  late String _status;
  String? _guestName;

  @override
  void initState() {
    super.initState();
    _status = widget.status;
    _guestName = widget.guestName;
  }

  void _toggleStatus() {
    final store = RoomStatus.of(context);
    if (store != null) {
      store.toggleStatus(widget.roomNumber);
      widget.onStatusChanged?.call(store.getStatus(widget.roomNumber));
      return;
    }
    if (_status == '入住') return;
    setState(() {
      _status = _status == '空闲' ? '停住' : '空闲';
    });
    widget.onStatusChanged?.call(_status);
  }

  Future<void> _showRegisterDialog() async {
    final store = RoomStatus.of(context);
    // 默认单位为“晚”，默认数量为 1（切换到“时”时使用房间配置或 4）
    String unit = '晚';
    final String initialCount =
        unit == '时' ? '4' : '1';
    final TextEditingController controller =
        TextEditingController(text: initialCount);
    final TextEditingController nameController =
        TextEditingController(text: _guestName ?? '');
    final TextEditingController idController = TextEditingController();
    final TextEditingController contactController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setStateDialog) {
          double parsed = double.tryParse(controller.text) ?? 0.0;
          final int estimate = RoomStatusStore.computeEstimatedFee(
            parsed,
            unit == '晚' ? true : false,
            widget.price ?? 0,
            widget.priceHourly ?? 0,
          );

          return AlertDialog(
            title: const Text('登记入住'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  Row(children: [
                    const Text('入住时间:'),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 100,
                      child: TextField(
                        controller: controller,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        onChanged: (_) => setStateDialog(() {}),
                      ),
                    ),
                    const SizedBox(width: 8),
                    DropdownButton<String>(
                      value: unit,
                      items: const [
                        DropdownMenuItem(value: '晚', child: Text('晚')),
                        DropdownMenuItem(value: '时', child: Text('时')),
                      ],
                      onChanged: (v) => setStateDialog(() {
                        final prev = unit;
                        unit = v ?? '晚';
                        final prevDefault = prev == '时'? '4': '1';
                        final newDefault = unit == '时'? '4': '1';
                        if (controller.text.isEmpty ||
                            controller.text == prevDefault) {
                          controller.text = newDefault;
                        }
                      }),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  // 客人信息输入
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: '客人姓名'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: idController,
                    decoration: const InputDecoration(labelText: '身份证号'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: contactController,
                    decoration: const InputDecoration(labelText: '联系方式'),
                  ),
                  const SizedBox(height: 12),
                  Text('估算费用: ¥$estimate',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('取消')),
              ElevatedButton(
                onPressed: () {
                  if (store != null) {
                    store.setStatus(widget.roomNumber, '入住');
                    store.setOccupancyCount(widget.roomNumber, 1);
                  } else {
                    setState(() => _status = '入住');
                  }
                  // 保存并展示客人姓名
                  // 持久化客人信息到 SQLite
                  RoomDb.setGuestInfo(widget.roomNumber,
                      guestName: nameController.text.isNotEmpty
                          ? nameController.text
                          : null,
                      idCard: idController.text.isNotEmpty
                          ? idController.text
                          : null,
                      contact: contactController.text.isNotEmpty
                          ? contactController.text
                          : null);
                  setState(() {
                    _guestName = nameController.text.isNotEmpty
                        ? nameController.text
                        : _guestName;
                  });
                  widget.onCheckIn?.call();
                  Navigator.of(ctx).pop();
                },
                child: const Text('确认'),
              ),
            ],
          );
        });
      },
    );
  }

  Color _statusColor(ThemeData theme, String status) {
    switch (status) {
      case '入住':
        return theme.colorScheme.errorContainer;
      case '停住':
        return theme.colorScheme.tertiaryContainer;
      case '空闲':
      default:
        return theme.colorScheme.primaryContainer;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case '入住':
        return Icons.event_busy;
      case '停住':
        return Icons.pause_circle;
      case '空闲':
      default:
        return Icons.check_circle_outline;
    }
  }

  void _showDetailsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('房间 ${widget.roomNumber} 详情'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _InfoRow(
                  icon: Icons.person,
                  label: '客人',
                  value: widget.guestName ?? '—'),
              const SizedBox(height: 8),
              _InfoRow(
                  icon: Icons.credit_card,
                  label: '身份证',
                  value: widget.guestId ?? '—'),
              const SizedBox(height: 8),
              _InfoRow(
                  icon: Icons.contact_phone,
                  label: '联系电话',
                  value: widget.guestContact ?? '—'),
              const SizedBox(height: 8),
              _InfoRow(
                  icon: Icons.calendar_today,
                  label: '入住时间',
                  value: widget.checkInTime ?? '—'),
              const SizedBox(height: 8),
              _InfoRow(
                  icon: Icons.calendar_month,
                  label: '退房时间',
                  value: widget.checkOutTime ?? '—'),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                    child: _InfoRow(
                        icon: Icons.attach_money,
                        label: '价格',
                        value:
                            widget.price != null ? '¥${widget.price}/晚' : '—')),
                const SizedBox(width: 8),
                Expanded(
                    child: _InfoRow(
                        icon: Icons.access_time,
                        label: '钟点',
                        value: widget.priceHourly != null
                            ? '¥${widget.priceHourly! * 4}/4时'
                            : '—')),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                    child: _InfoRow(
                        icon: Icons.account_balance_wallet,
                        label: '押金',
                        value: widget.deposit != null
                            ? '¥${widget.deposit}'
                            : '—')),
                const SizedBox(width: 8),
                Expanded(
                    child: _InfoRow(
                        icon: Icons.group,
                        label: '可住',
                        value: widget.capacity?.toString() ?? '—')),
              ]),
              if (widget.amenities != null && widget.amenities!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text('房间设施', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: widget.amenities!
                      .map((a) => Chip(
                          label: Text(a), visualDensity: VisualDensity.compact))
                      .toList(),
                )
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final guest = widget.guestName ?? '—';
    final guestContact = widget.guestContact ?? '—';
    final checkIn = widget.checkInTime ?? '—';
    final checkOut = widget.checkOutTime ?? '—';

    final store = RoomStatus.of(context);
    final currentStatus = store?.getStatus(widget.roomNumber) ?? _status;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: LayoutBuilder(builder: (context, constraints) {
          final isWide = constraints.maxWidth > 520;
          const avatar = CircleAvatar(
            radius: 24,
            child: Icon(Icons.hotel, size: 24),
          );

          Widget header = Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              avatar,
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('房间 ${widget.roomNumber}',
                        style: theme.textTheme.titleLarge),
                    const SizedBox(height: 6),
                    Row(children: [
                      ActionChip(
                        avatar: Icon(_statusIcon(currentStatus), size: 16),
                        label: Text(currentStatus),
                        onPressed:
                            (currentStatus == '入住') ? null : _toggleStatus,
                        backgroundColor: _statusColor(theme, currentStatus),
                      ),
                      const SizedBox(width: 8),
                      Text(widget.guestName ?? '—',
                          style: theme.textTheme.bodySmall),
                    ])
                  ],
                ),
              ),
              IconButton(
                onPressed: widget.onDetails,
                tooltip: '更多',
                icon: const Icon(Icons.more_vert),
              )
            ],
          );

          Widget detailsColumn = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _InfoRow(icon: Icons.person, label: '客人', value: guest),
              const SizedBox(height: 4),
              _InfoRow(icon: Icons.contact_phone, label: '联系电话', value: guestContact),
              const SizedBox(height: 4),
              _InfoRow(icon: Icons.calendar_today, label: '入住时间', value: checkIn),
              const SizedBox(height: 4),
              _InfoRow(icon: Icons.calendar_month, label: '退房时间', value: checkOut),
              const SizedBox(height: 4),
              const SizedBox(height: 4),
              Row(children: [
                Expanded(
                    child: _InfoRow(
                        icon: Icons.account_balance_wallet,
                        label: '押金',
                        value: widget.deposit != null ? '¥${widget.deposit}' : '—')),
                const SizedBox(width: 6),
                Expanded(
                    child: _InfoRow(
                        icon: Icons.group,
                        label: '可住',
                        value: widget.capacity?.toString() ?? '—')),
              ]),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _showRegisterDialog,
                      icon: const Icon(Icons.login),
                      label: const Text('登记入住'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: _showDetailsDialog,
                    icon: const Icon(Icons.info_outline),
                    label: const Text('详情'),
                  ),
                ],
              )
            ],
          );

          if (isWide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                    flex: 3,
                    child: Column(children: [
                      header,
                      const SizedBox(height: 6),
                      Divider(color: theme.colorScheme.outline)
                    ])),
                const SizedBox(width: 8),
                Expanded(flex: 5, child: detailsColumn),
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              header,
              const SizedBox(height: 6),
              Divider(color: theme.colorScheme.outline),
              const SizedBox(height: 6),
              detailsColumn
            ],
          );
        }),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(
      {required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Text('$label：', style: theme.textTheme.bodyMedium),
        const SizedBox(width: 6),
        Expanded(
            child: Text(value,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600))),
      ],
    );
  }
}
