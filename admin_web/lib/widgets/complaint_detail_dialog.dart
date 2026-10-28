import 'package:flutter/material.dart';
import '../services/admin_api_service.dart';

class ComplaintDetailDialog extends StatefulWidget {
  final Map<String, dynamic> complaint;
  final VoidCallback onActionCompleted;

  const ComplaintDetailDialog({
    super.key,
    required this.complaint,
    required this.onActionCompleted,
  });

  @override
  State<ComplaintDetailDialog> createState() => _ComplaintDetailDialogState();
}

class _ComplaintDetailDialogState extends State<ComplaintDetailDialog> {
  late String _currentStatus;
  final TextEditingController _notesController = TextEditingController();
  bool _isLoading = false;

  final List<String> _statusOptions = [
    'Under Review',
    'In Progress',
    'Resolved',
    'Rejected',
  ];

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.complaint['status'] ?? 'Under Review';
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'resolved':
        return const Color(0xFF16A34A);
      case 'in progress':
        return const Color(0xFFD97706);
      case 'rejected':
        return const Color(0xFF64748B);
      case 'under review':
      default:
        return const Color(0xFFDC2626);
    }
  }

  Future<void> _updateStatus(String newStatus) async {
    setState(() => _isLoading = true);

    final complaintId = widget.complaint['complaintId'] ?? widget.complaint['id'];
    final res = await AdminApiService.updateComplaintStatus(
      complaintId: complaintId,
      status: newStatus,
      adminNotes: _notesController.text.trim(),
      updatedBy: 'Chief Municipal Officer',
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (res['success'] == true) {
      setState(() => _currentStatus = newStatus);
      widget.onActionCompleted();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Complaint status successfully updated to "$newStatus"!'),
          backgroundColor: _getStatusColor(newStatus),
        ),
      );
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error: ${res['error']}'),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.complaint;
    final complaintId = c['complaintId'] ?? c['id'] ?? 'N/A';
    final imageUrl = AdminApiService.normalizeImageUrl(c['imagePath']?.toString());
    final date = c['date'] ?? 'Recent';
    final citizen = c['userName'] ?? 'Citizen';
    final userId = c['userId'] ?? 'USER_GUEST';
    final category = c['category'] ?? 'General Civic';
    final address = c['userAddress'] ?? 'Location not specified';
    final description = c['description'] ?? 'No description provided.';
    final comments = List<Map<String, dynamic>>.from(c['comments'] ?? []);

    final screenW = MediaQuery.of(context).size.width;
    final screenH = MediaQuery.of(context).size.height;
    final isMobile = screenW < 700;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      insetPadding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 40, vertical: isMobile ? 16 : 24),
      child: Container(
        width: isMobile ? screenW * 0.95 : 820,
        constraints: BoxConstraints(maxHeight: screenH * 0.9, maxWidth: 820),
        child: Column(
          children: [
            // Modal Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
              decoration: const BoxDecoration(
                color: Color(0xFF0F172A),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF38BDF8).withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      complaintId,
                      style: const TextStyle(
                        color: Color(0xFF38BDF8),
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      category,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _buildStatusBadge(_currentStatus),
                  const SizedBox(width: 12),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Modal Body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left Column: Details & Timeline
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _sectionTitle('Citizen & Grievance Information'),
                              const SizedBox(height: 12),
                              _detailRow('Reported By', citizen),
                              _detailRow('User ID', userId),
                              _detailRow('Date / Time', date),
                              _detailRow('Civic Category', category),
                              _detailRow('Address / Location', address),
                              const SizedBox(height: 16),

                              _sectionTitle('Description'),
                              const SizedBox(height: 8),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Text(
                                  description,
                                  style: const TextStyle(
                                    color: Color(0xFF334155),
                                    fontSize: 13.5,
                                    height: 1.45,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),

                              // Status Selection Section
                              _sectionTitle('Update Complaint Status'),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: const Color(0xFFCBD5E1)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Select New Status for Citizen App:',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: Color(0xFF1E293B),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Wrap(
                                      spacing: 10,
                                      runSpacing: 8,
                                      children: _statusOptions.map((status) {
                                        final isSelected = _currentStatus.toLowerCase() == status.toLowerCase();
                                        final color = _getStatusColor(status);
                                        return InkWell(
                                          onTap: _isLoading ? null : () => _updateStatus(status),
                                          borderRadius: BorderRadius.circular(10),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                            decoration: BoxDecoration(
                                              color: isSelected ? color : Colors.white,
                                              borderRadius: BorderRadius.circular(10),
                                              border: Border.all(
                                                color: isSelected ? color : color.withValues(alpha: 0.5),
                                                width: 1.5,
                                              ),
                                              boxShadow: isSelected
                                                  ? [
                                                      BoxShadow(
                                                        color: color.withValues(alpha: 0.3),
                                                        blurRadius: 8,
                                                        offset: const Offset(0, 2),
                                                      ),
                                                    ]
                                                  : null,
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  isSelected ? Icons.check_circle : Icons.circle_outlined,
                                                  size: 15,
                                                  color: isSelected ? Colors.white : color,
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  status,
                                                  style: TextStyle(
                                                    color: isSelected ? Colors.white : color,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12.5,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                    const SizedBox(height: 14),
                                    TextField(
                                      controller: _notesController,
                                      decoration: InputDecoration(
                                        hintText: 'Optional official note (e.g. Work crew dispatched, repair completed)...',
                                        hintStyle: const TextStyle(fontSize: 12),
                                        filled: true,
                                        fillColor: Colors.white,
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 24),

                        // Right Column: Attached Photo / Evidence
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _sectionTitle('Civic Photo / Evidence'),
                              const SizedBox(height: 10),
                              Container(
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                  color: const Color(0xFFF8FAFC),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: imageUrl.isNotEmpty && imageUrl.startsWith('http')
                                    ? Image.network(
                                        imageUrl,
                                        fit: BoxFit.cover,
                                        height: 240,
                                        width: double.infinity,
                                        loadingBuilder: (context, child, progress) {
                                          if (progress == null) return child;
                                          return const SizedBox(
                                            height: 240,
                                            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                          );
                                        },
                                        errorBuilder: (context, error, stackTrace) {
                                          return _buildNoPhotoPlaceholder();
                                        },
                                      )
                                    : _buildNoPhotoPlaceholder(),
                              ),
                              const SizedBox(height: 20),

                              // Activity Log / Comments Timeline
                              _sectionTitle('Activity & Updates (${comments.length})'),
                              const SizedBox(height: 8),
                              if (comments.isEmpty)
                                const Text(
                                  'No comments or status notes yet.',
                                  style: TextStyle(color: Colors.grey, fontSize: 12),
                                )
                              else
                                ...comments.reversed.take(4).map((c) {
                                  final author = c['userName'] ?? 'Citizen';
                                  final note = c['comment'] ?? '';
                                  final time = c['date'] ?? '';
                                  final isAdmin = c['userId'] == 'ADMIN';

                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: isAdmin ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: isAdmin ? const Color(0xFF86EFAC) : const Color(0xFFE2E8F0),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              author,
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 11.5,
                                                color: isAdmin ? const Color(0xFF166534) : const Color(0xFF1E293B),
                                              ),
                                            ),
                                            const Spacer(),
                                            Text(
                                              time,
                                              style: const TextStyle(fontSize: 10.5, color: Colors.grey),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          note,
                                          style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Modal Footer
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                    ),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoPhotoPlaceholder() {
    return Container(
      height: 240,
      width: double.infinity,
      color: const Color(0xFFF1F5F9),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image_not_supported_outlined, size: 42, color: Color(0xFF94A3B8)),
          SizedBox(height: 8),
          Text(
            'No photo attached',
            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: Color(0xFF0F172A),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B), fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final color = _getStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 11.5,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
