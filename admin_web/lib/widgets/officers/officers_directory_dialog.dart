import 'package:flutter/material.dart';
import '../../services/admin_api_service.dart';
import 'register_officer_dialog.dart';
import 'reset_officer_password_dialog.dart';

class OfficersDirectoryDialog {
  static void show(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.people_alt_rounded, color: Color(0xFF38BDF8), size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Municipal Officers Directory', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                    Text('Authorized personnel & administrative credentials', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
              ),
              if (AdminApiService.isSuperAdmin)
                IconButton(
                  icon: const Icon(Icons.person_add_rounded, color: Color(0xFF0F172A)),
                  tooltip: 'Register New Officer',
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    RegisterOfficerDialog.show(context, onOfficerCreated: () {
                      OfficersDirectoryDialog.show(context);
                    });
                  },
                ),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 580, maxHeight: 480),
            child: FutureBuilder<Map<String, dynamic>>(
              future: AdminApiService.listAdmins(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                final data = snapshot.data;
                if (data == null || data['success'] != true) {
                  return Center(
                    child: Text(
                      'Failed to load officers: ${data?['error'] ?? 'Unknown error'}',
                      style: const TextStyle(color: Colors.red),
                    ),
                  );
                }

                final List<Map<String, dynamic>> admins = List<Map<String, dynamic>>.from(data['admins'] ?? []);
                if (admins.isEmpty) {
                  return const Center(child: Text('No officers found'));
                }

                final isCurrentSuperAdmin = AdminApiService.isSuperAdmin;
                final isChiefMaster = AdminApiService.currentAdmin?['adminId'] == 'ADM_00001';

                return ListView.separated(
                  shrinkWrap: true,
                  itemCount: admins.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final adm = admins[i];
                    final adminId = (adm['adminId'] ?? 'ADM_00000').toString();
                    final name = (adm['name'] ?? 'Officer').toString();
                    final username = (adm['username'] ?? '').toString();
                    final createdBy = (adm['createdBy'] ?? 'SYSTEM').toString();
                    final role = (adm['role'] ?? (adminId == 'ADM_00001' ? 'SUPER_ADMIN' : 'OFFICER')).toString();
                    final isActive = adm['isActive'] != false;
                    final initial = name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'A';
                    final canResetThisRow = isCurrentSuperAdmin && adminId != 'ADM_00001' && (role != 'SUPER_ADMIN' || isChiefMaster);

                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // 1. Officer Initial Avatar
                          CircleAvatar(
                            radius: 19,
                            backgroundColor: const Color(0xFF0F172A),
                            child: Text(
                              initial,
                              style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                          const SizedBox(width: 12),

                          // 2. Middle Name & Meta
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: Color(0xFF0F172A),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: role == 'SUPER_ADMIN' ? const Color(0xFFFEF3C7) : const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                          color: role == 'SUPER_ADMIN' ? const Color(0xFFF59E0B) : const Color(0xFFCBD5E1),
                                        ),
                                      ),
                                      child: Text(
                                        role == 'SUPER_ADMIN' ? 'SUPER ADMIN' : 'OFFICER',
                                        style: TextStyle(
                                          color: role == 'SUPER_ADMIN' ? const Color(0xFFB45309) : const Color(0xFF475569),
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '@$username • Created by $createdBy',
                                  style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(width: 12),

                          // 3. Right: Prominently Aligned Admin ID & Status
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0F172A),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.3)),
                                ),
                                child: Text(
                                  adminId,
                                  style: const TextStyle(
                                    color: Color(0xFF38BDF8),
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 5),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.circle,
                                    size: 6,
                                    color: isActive ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    isActive ? 'Active' : 'Disabled',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: isActive ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          if (canResetThisRow) ...[
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.key_rounded, size: 18, color: Color(0xFF0284C7)),
                              tooltip: 'Reset Password ($adminId)',
                              onPressed: () => ResetOfficerPasswordDialog.show(context, adm),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }
}

