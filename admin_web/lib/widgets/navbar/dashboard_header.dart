import 'package:flutter/material.dart';
import '../../services/admin_api_service.dart';
import '../../utils/responsive.dart';
import '../officers/officers_directory_dialog.dart';
import '../officers/register_officer_dialog.dart';
import 'change_password_dialog.dart';

class DashboardHeader extends StatelessWidget {
  final String activeSection;
  final ValueChanged<String> onSectionChanged;
  final VoidCallback onRefresh;
  final int complaintCount;
  final int storePendingCount;
  final int feedbackCount;
  final VoidCallback onLogout;

  const DashboardHeader({
    super.key,
    required this.activeSection,
    required this.onSectionChanged,
    required this.onRefresh,
    required this.complaintCount,
    required this.storePendingCount,
    required this.feedbackCount,
    required this.onLogout,
  });

  String _getSectionTitle(String key) {
    switch (key) {
      case 'stores':
        return 'Store Approvals';
      case 'feedback':
        return 'Citizen Feedback';
      case 'monitoring':
        return 'Live Dispatch & Logistics';
      case 'city_map':
        return 'Smart City GIS Map';
      case 'complaints':
      default:
        return 'Citizen Grievances';
    }
  }

  Widget _buildSectionButton({
    required String title,
    required IconData icon,
    required String sectionKey,
    required int count,
  }) {
    final isSelected = activeSection == sectionKey;
    return InkWell(
      onTap: () => onSectionChanged(sectionKey),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0284C7) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: isSelected ? Colors.white : const Color(0xFF94A3B8)),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 12,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white.withValues(alpha: 0.25) : const Color(0xFF334155),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProfileMenu(BuildContext context, {bool isCompact = false}) {
    final admin = AdminApiService.currentAdmin;
    final name = admin?['name'] ?? 'Municipal Officer';
    final adminId = admin?['adminId'] ?? 'ADM_00001';
    final username = admin?['username'] ?? 'admin';
    final role = (admin?['role'] ?? (adminId == 'ADM_00001' ? 'SUPER_ADMIN' : 'OFFICER')).toString();
    final initials = (username.isNotEmpty ? username : 'AD').toUpperCase().padRight(2).substring(0, 2);

    return PopupMenuButton<String>(
      tooltip: 'Officer Profile & Actions',
      offset: const Offset(0, 48),
      color: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFF334155)),
      ),
      onSelected: (val) {
        if (val == 'officers') OfficersDirectoryDialog.show(context);
        if (val == 'add') RegisterOfficerDialog.show(context);
        if (val == 'change_password') ChangePasswordDialog.show(context);
        if (val == 'logout') onLogout();
      },
      itemBuilder: (ctx) => [
        PopupMenuItem<String>(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 2),
              Text(
                '$adminId • @$username • ${role == 'SUPER_ADMIN' ? 'Super Admin' : 'Officer'}',
                style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(height: 1),
        const PopupMenuItem<String>(
          value: 'officers',
          child: Row(
            children: [
              Icon(Icons.people_alt_rounded, color: Color(0xFF38BDF8), size: 18),
              SizedBox(width: 10),
              Text('Officers Directory', style: TextStyle(color: Colors.white, fontSize: 13)),
            ],
          ),
        ),
        if (AdminApiService.isSuperAdmin)
          const PopupMenuItem<String>(
            value: 'add',
            child: Row(
              children: [
                Icon(Icons.person_add_rounded, color: Color(0xFF38BDF8), size: 18),
                SizedBox(width: 10),
                Text('Register Officer', style: TextStyle(color: Colors.white, fontSize: 13)),
              ],
            ),
          ),
        const PopupMenuItem<String>(
          value: 'change_password',
          child: Row(
            children: [
              Icon(Icons.lock_reset_rounded, color: Color(0xFF38BDF8), size: 18),
              SizedBox(width: 10),
              Text('Change My Password', style: TextStyle(color: Colors.white, fontSize: 13)),
            ],
          ),
        ),
        const PopupMenuDivider(height: 1),
        PopupMenuItem<String>(
          value: 'logout',
          child: const Row(
            children: [
              Icon(Icons.logout_rounded, color: Color(0xFFF87171), size: 18),
              SizedBox(width: 10),
              Text('Sign Out', style: TextStyle(color: Color(0xFFF87171), fontSize: 13, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ],
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: isCompact ? 8 : 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF334155)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              backgroundColor: const Color(0xFF38BDF8),
              radius: 14,
              child: Text(
                initials,
                style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 10),
              ),
            ),
            if (!isCompact) ...[
              const SizedBox(width: 8),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    adminId,
                    style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 10, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down_rounded, color: Colors.grey, size: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = context.isDesktop;
    final isMobile = context.isMobile;

    if (!isDesktop) {
      return Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: const BoxDecoration(
          color: Color(0xFF0F172A),
          border: Border(bottom: BorderSide(color: Color(0xFF1E293B))),
        ),
        child: Row(
          children: [
            Builder(
              builder: (ctx) => IconButton(
                icon: const Icon(Icons.menu_rounded, color: Colors.white, size: 24),
                onPressed: () => Scaffold.of(ctx).openDrawer(),
                tooltip: 'Navigation Menu',
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.account_balance_rounded, color: Color(0xFF38BDF8), size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isMobile ? 'GoGov Admin' : 'GoGovernment Administration',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    _getSectionTitle(activeSection),
                    style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 11, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
              tooltip: 'Refresh',
              onPressed: onRefresh,
            ),
            const SizedBox(width: 4),
            _buildProfileMenu(context, isCompact: true),
          ],
        ),
      );
    }

    final screenW = context.screenWidth;
    final isCompactDesktop = screenW < 1350;

    return Container(
      height: 72,
      padding: EdgeInsets.symmetric(horizontal: isCompactDesktop ? 18 : 36),
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        border: Border(bottom: BorderSide(color: Color(0xFF1E293B))),
      ),
      child: Row(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(Icons.account_balance_rounded, color: Color(0xFF38BDF8), size: 20),
              ),
              const SizedBox(width: 10),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'GoGovernment',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  Text(
                    'Municipal Admin',
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 10),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(width: 14),

          // Segmented Switcher between Complaints, Stores, Feedback & Monitoring
          Expanded(
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildSectionButton(
                      title: 'Complaints',
                      icon: Icons.campaign_rounded,
                      sectionKey: 'complaints',
                      count: complaintCount,
                    ),
                    const SizedBox(width: 4),
                    _buildSectionButton(
                      title: 'Stores',
                      icon: Icons.storefront_rounded,
                      sectionKey: 'stores',
                      count: storePendingCount,
                    ),
                    const SizedBox(width: 4),
                    _buildSectionButton(
                      title: 'Feedback',
                      icon: Icons.rate_review_rounded,
                      sectionKey: 'feedback',
                      count: feedbackCount,
                    ),
                    const SizedBox(width: 4),
                    _buildSectionButton(
                      title: 'Live Dispatch',
                      icon: Icons.radar_rounded,
                      sectionKey: 'monitoring',
                      count: 0,
                    ),
                    const SizedBox(width: 4),
                    _buildSectionButton(
                      title: 'City Map',
                      icon: Icons.map_rounded,
                      sectionKey: 'city_map',
                      count: 0,
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(width: 10),

          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
            tooltip: 'Refresh Data',
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFF1E293B),
              padding: const EdgeInsets.all(10),
            ),
            onPressed: onRefresh,
          ),
          const SizedBox(width: 10),
          _buildProfileMenu(context, isCompact: isCompactDesktop),
        ],
      ),
    );
  }

  static Widget buildMobileDrawer(
    BuildContext context, {
    required String activeSection,
    required ValueChanged<String> onSectionChanged,
    required int complaintCount,
    required int storePendingCount,
    required int feedbackCount,
    required VoidCallback onLogout,
  }) {
    Widget buildDrawerTile(String title, IconData icon, String sectionKey, int count) {
      final isSelected = activeSection == sectionKey;
      return ListTile(
        leading: Icon(icon, color: isSelected ? const Color(0xFF38BDF8) : Colors.grey.shade400, size: 22),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey.shade300,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 14,
          ),
        ),
        trailing: count > 0
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF38BDF8) : const Color(0xFF334155),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    color: isSelected ? const Color(0xFF0F172A) : Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              )
            : null,
        selected: isSelected,
        onTap: () {
          onSectionChanged(sectionKey);
          Navigator.pop(context);
        },
      );
    }

    return Drawer(
      backgroundColor: const Color(0xFF0F172A),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFF1E293B))),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.account_balance_rounded, color: Color(0xFF38BDF8), size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AdminApiService.currentAdmin?['name'] ?? 'GoGov Admin',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          AdminApiService.currentAdmin?['adminId'] ?? 'ADM_00001',
                          style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            buildDrawerTile('Citizen Complaints', Icons.campaign_rounded, 'complaints', complaintCount),
            buildDrawerTile('Store Approvals', Icons.storefront_rounded, 'stores', storePendingCount),
            buildDrawerTile('Citizen Feedback', Icons.rate_review_rounded, 'feedback', feedbackCount),
            buildDrawerTile('Live Dispatch & Riders', Icons.radar_rounded, 'monitoring', 0),
            buildDrawerTile('Smart City GIS Map', Icons.map_rounded, 'city_map', 0),
            const Divider(color: Color(0xFF1E293B), height: 24),
            ListTile(
              leading: const Icon(Icons.people_alt_rounded, color: Color(0xFF38BDF8), size: 22),
              title: const Text('Officers Directory', style: TextStyle(color: Colors.white, fontSize: 14)),
              onTap: () {
                Navigator.of(context).pop();
                OfficersDirectoryDialog.show(context);
              },
            ),
            if (AdminApiService.isSuperAdmin)
              ListTile(
                leading: const Icon(Icons.person_add_rounded, color: Color(0xFF38BDF8), size: 22),
                title: const Text('Register Officer', style: TextStyle(color: Colors.white, fontSize: 14)),
                onTap: () {
                  Navigator.of(context).pop();
                  RegisterOfficerDialog.show(context);
                },
              ),
            ListTile(
              leading: const Icon(Icons.logout_rounded, color: Color(0xFFF87171), size: 22),
              title: const Text('Sign Out', style: TextStyle(color: Color(0xFFF87171), fontSize: 14, fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.of(context).pop();
                onLogout();
              },
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.verified_user_rounded, color: Color(0xFF16A34A), size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text('Admin Portal Online\nMunicipal Operations Active', style: TextStyle(color: Colors.grey, fontSize: 11)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

