import 'package:flutter/material.dart';
import '../../services/admin_api_service.dart';

class RegisterOfficerDialog {
  static void show(BuildContext context, {VoidCallback? onOfficerCreated}) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final usernameController = TextEditingController();
    final passwordController = TextEditingController();
    String selectedRole = 'OFFICER';
    bool isSubmitting = false;
    String? dialogError;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.person_add_rounded, color: Color(0xFF0F172A)),
              SizedBox(width: 10),
              Text('Register Municipal Officer', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Create an administrative account for municipal staff or inspectors.',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 16),
                  if (dialogError != null) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFCA5A5)),
                      ),
                      child: Text(
                        dialogError!,
                        style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 12),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Officer Full Name',
                      hintText: 'e.g. Zone 1 Officer Senthil',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter officer name' : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: usernameController,
                    decoration: const InputDecoration(
                      labelText: 'Username',
                      hintText: 'e.g. senthil_zone1',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Enter username';
                      if (v.trim().length < 3) return 'At least 3 characters';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      hintText: 'Enter password (min 6 characters)',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Enter password';
                      if (v.trim().length < 6) return 'At least 6 characters';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: selectedRole,
                    decoration: const InputDecoration(
                      labelText: 'Administrative Role',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'OFFICER',
                        child: Text('Municipal Officer (Complaints & Stores)'),
                      ),
                      DropdownMenuItem(
                        value: 'SUPER_ADMIN',
                        child: Text('Super Admin (Full Officer & Staff Control)'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => selectedRole = val);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white,
              ),
              onPressed: isSubmitting
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() {
                        isSubmitting = true;
                        dialogError = null;
                      });

                      final res = await AdminApiService.createAdmin(
                        username: usernameController.text,
                        password: passwordController.text,
                        name: nameController.text,
                        role: selectedRole,
                      );

                      if (res['success'] == true) {
                        if (!ctx.mounted) return;
                        Navigator.of(ctx).pop();
                        final newAdmin = res['admin'] as Map<String, dynamic>?;
                        onOfficerCreated?.call();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              '✅ Created Officer: ${newAdmin?['name']} (${newAdmin?['adminId']}) [${newAdmin?['role'] ?? selectedRole}]',
                            ),
                            backgroundColor: const Color(0xFF16A34A),
                          ),
                        );
                      } else {
                        setDialogState(() {
                          isSubmitting = false;
                          dialogError = res['error'] ?? 'Failed to create officer';
                        });
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Create Officer'),
            ),
          ],
        ),
      ),
    );
  }
}

