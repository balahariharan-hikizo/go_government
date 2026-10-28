import 'dart:async';
import 'package:flutter/material.dart';
import '../services/admin_api_service.dart';
import '../utils/responsive.dart';

class LiveMonitoringView extends StatefulWidget {
  const LiveMonitoringView({super.key});

  @override
  State<LiveMonitoringView> createState() => _LiveMonitoringViewState();
}

class _LiveMonitoringViewState extends State<LiveMonitoringView> {
  bool _isLoading = true;
  Timer? _refreshTimer;
  List<Map<String, dynamic>> _riders = [];
  List<Map<String, dynamic>> _orders = [];
  int _activeRidersCount = 0;
  int _activeGpsCount = 0;

  // Navigation Sub-tab: 'riders', 'live_orders', 'store_history'
  String _activeTab = 'riders';

  // Filters for Store Order History
  String _selectedStoreId = 'all';
  String _selectedStatus = 'all';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchMonitoringData();
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) => _fetchMonitoringData(showLoader: false));
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchMonitoringData({bool showLoader = true}) async {
    if (showLoader) setState(() => _isLoading = true);

    final riderRes = await AdminApiService.getLiveRiders();
    final orderRes = await AdminApiService.getAllOrders();

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (riderRes['success'] == true) {
      final rawRiders = List<Map<String, dynamic>>.from(
        riderRes['riders'] ?? riderRes['data']?['riders'] ?? [],
      );
      setState(() {
        _riders = rawRiders;
        _activeRidersCount = rawRiders.where((r) => r['isOnline'] == true).length;
        _activeGpsCount = rawRiders.where((r) => r['isActiveGps'] == true).length;
      });
    }

    if (orderRes['success'] == true) {
      final rawOrders = List<Map<String, dynamic>>.from(
        orderRes['orders'] ?? orderRes['data'] ?? [],
      );
      setState(() {
        _orders = rawOrders;
      });
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'placed':
        return Colors.orange;
      case 'preparing':
        return Colors.amber;
      case 'accepted':
        return Colors.blue;
      case 'ready_for_pickup':
        return Colors.purple;
      case 'out_for_delivery':
        return Colors.teal;
      case 'delivered':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  List<String> get _availableStoreNames {
    final names = <String>{'all'};
    for (final o in _orders) {
      final name = o['storeDetails']?['name']?.toString() ?? o['storeId']?.toString();
      if (name != null && name.isNotEmpty) names.add(name);
    }
    return names.toList();
  }

  List<Map<String, dynamic>> get _filteredOrders {
    return _orders.where((o) {
      // Tab filter: live vs history
      if (_activeTab == 'live_orders') {
        if (['delivered', 'cancelled'].contains(o['status']?.toString().toLowerCase())) return false;
      }

      // Store filter
      if (_selectedStoreId != 'all') {
        final storeName = o['storeDetails']?['name']?.toString() ?? o['storeId']?.toString() ?? '';
        if (storeName != _selectedStoreId && o['storeId'] != _selectedStoreId) return false;
      }

      // Status filter
      if (_selectedStatus != 'all') {
        if (o['status']?.toString().toLowerCase() != _selectedStatus.toLowerCase()) return false;
      }

      // Search query
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final id = (o['orderId'] ?? '').toString().toLowerCase();
        final store = (o['storeDetails']?['name'] ?? '').toString().toLowerCase();
        final rider = (o['deliveryAgent']?['name'] ?? '').toString().toLowerCase();
        if (!id.contains(q) && !store.contains(q) && !rider.contains(q)) return false;
      }

      return true;
    }).toList();
  }

  double get _totalFilteredRevenue {
    double total = 0;
    for (final o in _filteredOrders) {
      if (o['status'] == 'delivered') {
        total += (o['grandTotal'] as num?)?.toDouble() ?? 0;
      }
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final liveOrdersCount = _orders.where((o) => ['placed', 'accepted', 'ready_for_pickup', 'out_for_delivery'].contains(o['status'])).length;
    final deliveredCount = _orders.where((o) => o['status'] == 'delivered').length;

    final isMobile = context.isMobile;
    final isDesktop = context.isDesktop;

    final kpiCards = [
      _buildStatCard('Active Online Riders', '$_activeRidersCount', Icons.two_wheeler_rounded, Colors.blue),
      _buildStatCard('Active GPS Signals', '$_activeGpsCount', Icons.location_on_rounded, Colors.green),
      _buildStatCard('In-Flight Live Orders', '$liveOrdersCount', Icons.local_shipping_rounded, Colors.orange),
      _buildStatCard('Completed Deliveries', '$deliveredCount', Icons.check_circle_rounded, Colors.teal),
    ];

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            runSpacing: 12,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '📡 Live Dispatch & Store Order Analytics',
                    style: TextStyle(
                      fontSize: isMobile ? 18 : 22,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Real-time GPS tracking of delivery partners & multi-store order histories',
                    style: TextStyle(fontSize: isMobile ? 11.5 : 13, color: Colors.grey.shade600),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () => _fetchMonitoringData(),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Refresh Live Feed'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: isMobile ? 14 : 18, vertical: isMobile ? 10 : 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Overview KPI Cards
          if (isDesktop)
            Row(
              children: kpiCards.asMap().entries.map((e) {
                final isLast = e.key == kpiCards.length - 1;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: isLast ? 0 : 16),
                    child: e.value,
                  ),
                );
              }).toList(),
            )
          else
            LayoutBuilder(
              builder: (ctx, constraints) {
                final maxW = constraints.maxWidth;
                if (maxW <= 0) return const SizedBox.shrink();
                final cols = maxW >= 1000 ? 4 : (maxW >= 600 ? 2 : 1);
                const gap = 12.0;
                final w = cols == 1
                    ? maxW
                    : ((maxW - ((cols - 1) * gap)) / cols).clamp(100.0, maxW);
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: kpiCards.map((c) => SizedBox(width: w, child: c)).toList(),
                );
              },
            ),
          const SizedBox(height: 28),

          // Sub-navigation Switcher
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildSubTabButton('Live Riders & GPS', 'riders', Icons.gps_fixed_rounded, _riders.length),
                  const SizedBox(width: 6),
                  _buildSubTabButton('In-Flight Live Orders', 'live_orders', Icons.bolt_rounded, liveOrdersCount),
                  const SizedBox(width: 6),
                  _buildSubTabButton('Store Order Histories', 'store_history', Icons.storefront_rounded, _orders.length),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          if (_isLoading)
            const Center(child: Padding(padding: EdgeInsets.all(50), child: CircularProgressIndicator()))
          else if (_activeTab == 'riders')
            _buildRidersTable()
          else
            _buildOrdersSection(),
        ],
      ),
    );
  }

  Widget _buildSubTabButton(String label, String tabKey, IconData icon, int count) {
    final isSelected = _activeTab == tabKey;
    return InkWell(
      onTap: () => setState(() => _activeTab = tabKey),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1E293B) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: isSelected ? Colors.white : Colors.grey.shade700),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : Colors.grey.shade800,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected ? Colors.blue : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : Colors.grey.shade800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRidersTable() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '🚴 Registered Delivery Partners & Live GPS Feed',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            Text(
              'Total Partners: ${_riders.length} · Online: $_activeRidersCount',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _riders.isEmpty
            ? _buildEmptyBox('No riders registered or online.')
            : Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10)],
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 900),
                    child: DataTable(
                      columnSpacing: 24,
                      headingRowColor: WidgetStateProperty.all(Colors.grey.shade50),
                  columns: const [
                    DataColumn(label: Text('Rider ID & Name', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Vehicle & Contact', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Duty Status', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('GPS Signal', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Live Coordinates (Lat, Lng)', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Last Ping', style: TextStyle(fontWeight: FontWeight.bold))),
                  ],
                  rows: _riders.map((r) {
                    final isOnline = r['isOnline'] == true;
                    final isActiveGps = r['isActiveGps'] == true;
                    final lat = (r['latitude'] as num?)?.toDouble() ?? 0.0;
                    final lng = (r['longitude'] as num?)?.toDouble() ?? 0.0;
                    final lastSecs = r['lastSeenSecondsAgo'];
                    final name = r['name'] ?? 'Delivery Partner';
                    final phone = r['phone'] ?? '';
                    final vehicle = '${r['vehicleType'] ?? 'Motorcycle'} · ${r['vehicleNumber'] ?? ''}';

                    return DataRow(cells: [
                      DataCell(
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            Text(r['riderId'] ?? '', style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
                          ],
                        ),
                      ),
                      DataCell(
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(vehicle, style: const TextStyle(fontSize: 12)),
                            Text(phone, style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
                          ],
                        ),
                      ),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isOnline ? Colors.green.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            isOnline ? '🟢 ONLINE' : '🔴 OFFLINE',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isOnline ? Colors.green.shade700 : Colors.grey.shade700,
                            ),
                          ),
                        ),
                      ),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isActiveGps ? Colors.blue.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            isActiveGps ? '📡 Active GPS' : '⚠️ No Signal / Stale',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isActiveGps ? Colors.blue.shade700 : Colors.orange.shade800,
                            ),
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          lat != 0 || lng != 0 ? '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}' : 'Location Pending',
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                        ),
                      ),
                      DataCell(
                        Text(
                          lastSecs != null ? '$lastSecs secs ago' : 'Never',
                          style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                        ),
                      ),
                    ]);
                  }).toList(),
                    ),
                  ),
                ),
              ),
      ],
    );
  }

  Widget _buildOrdersSection() {
    final filtered = _filteredOrders;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Filters Header Bar
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Wrap(
            spacing: 16,
            runSpacing: 12,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Wrap(
                spacing: 20,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  // Store Dropdown Filter
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Store: ', style: TextStyle(fontWeight: FontWeight.bold)),
                      DropdownButton<String>(
                        value: _selectedStoreId,
                        underline: const SizedBox(),
                        items: _availableStoreNames.map((s) {
                          return DropdownMenuItem(
                            value: s,
                            child: Text(s == 'all' ? '🏬 All Stores' : '🏪 $s', style: const TextStyle(fontSize: 13)),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedStoreId = val);
                        },
                      ),
                    ],
                  ),

                  // Status Dropdown Filter
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Status: ', style: TextStyle(fontWeight: FontWeight.bold)),
                      DropdownButton<String>(
                        value: _selectedStatus,
                        underline: const SizedBox(),
                        items: const [
                          DropdownMenuItem(value: 'all', child: Text('All Statuses')),
                          DropdownMenuItem(value: 'placed', child: Text('Placed')),
                          DropdownMenuItem(value: 'preparing', child: Text('Preparing')),
                          DropdownMenuItem(value: 'accepted', child: Text('Accepted')),
                          DropdownMenuItem(value: 'ready_for_pickup', child: Text('Ready for Pickup')),
                          DropdownMenuItem(value: 'out_for_delivery', child: Text('Out for Delivery')),
                          DropdownMenuItem(value: 'delivered', child: Text('Delivered')),
                          DropdownMenuItem(value: 'cancelled', child: Text('Cancelled')),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedStatus = val);
                        },
                      ),
                    ],
                  ),
                ],
              ),

              // Search Bar
              SizedBox(
                width: 260,
                height: 40,
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search order ID, store, rider...',
                    hintStyle: const TextStyle(fontSize: 12),
                    prefixIcon: const Icon(Icons.search, size: 18),
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Summary bar for filtered results
        if (_activeTab == 'store_history')
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'Showing ${filtered.length} orders · Completed Payout Revenue: ₹${_totalFilteredRevenue.toStringAsFixed(0)}',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontSize: 13),
            ),
          ),

        filtered.isEmpty
            ? _buildEmptyBox('No orders match the selected filters.')
            : Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10)],
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 850),
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(Colors.grey.shade50),
                      columnSpacing: 24,
                      columns: const [
                        DataColumn(label: Text('Order ID', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Store Name', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Assigned Rider', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Payment', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Grand Total', style: TextStyle(fontWeight: FontWeight.bold))),
                      ],
                      rows: filtered.map((o) {
                        final status = o['status']?.toString() ?? 'placed';
                        final color = _getStatusColor(status);
                        final agent = o['deliveryAgent'];
                        final riderName = agent != null && agent['name'] != null ? agent['name'].toString() : 'Unassigned';
                        final storeName = o['storeDetails']?['name']?.toString() ?? o['storeId']?.toString() ?? '-';
                        final payMode = o['paymentMethod']?.toString() ?? 'COD';

                        return DataRow(cells: [
                          DataCell(Text('#${o['orderId'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.bold))),
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                status.toUpperCase().replaceAll('_', ' '),
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
                              ),
                            ),
                          ),
                          DataCell(Text(storeName, style: const TextStyle(fontWeight: FontWeight.w500))),
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.two_wheeler_rounded, size: 16, color: agent != null ? Colors.blue : Colors.grey),
                                const SizedBox(width: 6),
                                ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: 140),
                                  child: Text(
                                    riderName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontWeight: agent != null ? FontWeight.bold : FontWeight.normal),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          DataCell(Text(payMode, style: const TextStyle(fontSize: 12))),
                          DataCell(Text('₹${o['grandTotal'] ?? 0}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green))),
                        ]);
                      }).toList(),
                    ),
                  ),
                ),
              ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                Text(title, style: TextStyle(fontSize: 12, color: Colors.grey.shade600), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyBox(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Center(
        child: Text(text, style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
      ),
    );
  }
}
