import 'package:flutter/material.dart';
import '../services/admin_api_service.dart';

class StoreDetailDialog extends StatefulWidget {
  final Map<String, dynamic> store;
  final VoidCallback onActionCompleted;

  const StoreDetailDialog({
    super.key,
    required this.store,
    required this.onActionCompleted,
  });

  @override
  State<StoreDetailDialog> createState() => _StoreDetailDialogState();
}

class _StoreDetailDialogState extends State<StoreDetailDialog> {
  bool _isLoading = false;

  Future<void> _approveStore() async {
    final storeId = widget.store['storeId'];
    setState(() => _isLoading = true);

    final res = await AdminApiService.updateStoreStatus(
      storeId: storeId,
      status: 'approved',
      verifiedBy: 'Municipal Commercial Officer (Admin Portal)',
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (res['success'] == true) {
      Navigator.of(context).pop();
      widget.onActionCompleted();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Store "${widget.store['name']}" approved successfully!'),
          backgroundColor: const Color(0xFF16A34A),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['error'] ?? 'Approval failed'), backgroundColor: Colors.red),
      );
    }
  }

  void _showRejectPrompt() {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Store Application', style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Please provide clear feedback for the merchant on why this application is being rejected so they can fix and re-submit:',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'e.g., Trade license document is expired. Please re-upload updated 2026 renewal copy.',
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white),
            onPressed: () async {
              final reason = reasonController.text.trim();
              if (reason.isEmpty) return;

              Navigator.of(ctx).pop(); // Close reason dialog
              setState(() => _isLoading = true);

              final res = await AdminApiService.updateStoreStatus(
                storeId: widget.store['storeId'],
                status: 'rejected',
                rejectionReason: reason,
              );

              if (!mounted) return;
              setState(() => _isLoading = false);

              if (res['success'] == true) {
                Navigator.of(context).pop(); // Close detail dialog
                widget.onActionCompleted();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Store application marked as rejected'), backgroundColor: Color(0xFFDC2626)),
                );
              }
            },
            child: const Text('Confirm Rejection'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.store;
    final name = s['name'] ?? 'Store';
    final storeId = s['storeId'] ?? '';
    final category = (s['category'] ?? 'General').toString().toUpperCase();
    final status = s['status'] ?? 'pending';
    final storeImage = s['storeImage']?.toString() ?? '';

    final screenW = MediaQuery.of(context).size.width;
    final screenH = MediaQuery.of(context).size.height;
    final isMobile = screenW < 700;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: isMobile ? screenW * 0.95 : 780,
        constraints: BoxConstraints(
          maxHeight: screenH * 0.9,
          maxWidth: 780,
        ),
        padding: EdgeInsets.all(isMobile ? 16 : 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: TextStyle(
                                fontSize: isMobile ? 18 : 22,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF0F172A),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 10),
                          _buildStatusBadge(status),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Registration ID: $storeId • Category: $category',
                        style: TextStyle(fontSize: isMobile ? 11.5 : 13, color: Colors.grey.shade600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(height: 28),

            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isMobile) ...[
                      // Mobile: Stack Store Details and Photo vertically
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionTitle('Store & Merchant Information'),
                          const SizedBox(height: 10),
                          _detailRow('Owner Name', s['ownerName'] ?? 'N/A'),
                          _detailRow('Mobile Phone', s['phone'] ?? 'N/A'),
                          _detailRow('Email', s['email'] != null && s['email'].toString().isNotEmpty ? s['email'] : 'Not provided'),
                          _detailRow('Address', s['address'] ?? 'N/A'),
                          _detailRow('Pincode', s['pincode'] ?? 'N/A'),
                          _detailRow('Working Hours', '${s['timings']?['open'] ?? '08:00 AM'} - ${s['timings']?['close'] ?? '08:30 PM'}'),
                          if (s['location'] != null)
                            _detailRow('GPS Pin', '${s['location']['lat']}, ${s['location']['lng']}'),
                          const SizedBox(height: 12),
                          _sectionTitle('Settlement Bank Details'),
                          const SizedBox(height: 8),
                          _detailRow('Bank Name', s['bankDetails']?['bankName'] ?? 'Not specified'),
                          _detailRow('Account No', s['bankDetails']?['accountNumber'] ?? 'Not specified'),
                          _detailRow('IFSC Code', s['bankDetails']?['ifscCode'] ?? 'Not specified'),
                          _detailRow('Holder Name', s['bankDetails']?['accountHolderName'] ?? s['ownerName'] ?? 'N/A'),
                          if (s['rejectionReason'] != null && s['rejectionReason'].toString().isNotEmpty)
                            _detailRow('Rejection Note', s['rejectionReason'], isAlert: true),
                          const SizedBox(height: 16),
                          _sectionTitle('Storefront Verification'),
                          const SizedBox(height: 10),
                          _buildDocCard('Storefront Photo', storeImage, Icons.storefront),
                        ],
                      ),
                    ] else ...[
                      // Desktop / Tablet: 2-Column Row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _sectionTitle('Store & Merchant Information'),
                                const SizedBox(height: 10),
                                _detailRow('Owner Name', s['ownerName'] ?? 'N/A'),
                                _detailRow('Mobile Phone', s['phone'] ?? 'N/A'),
                                _detailRow('Email', s['email'] != null && s['email'].toString().isNotEmpty ? s['email'] : 'Not provided'),
                                _detailRow('Address', s['address'] ?? 'N/A'),
                                _detailRow('Pincode', s['pincode'] ?? 'N/A'),
                                _detailRow('Working Hours', '${s['timings']?['open'] ?? '08:00 AM'} - ${s['timings']?['close'] ?? '08:30 PM'}'),
                                if (s['location'] != null)
                                  _detailRow('GPS Pin', '${s['location']['lat']}, ${s['location']['lng']}'),
                                const SizedBox(height: 12),
                                _sectionTitle('Settlement Bank Details'),
                                const SizedBox(height: 8),
                                _detailRow('Bank Name', s['bankDetails']?['bankName'] ?? 'Not specified'),
                                _detailRow('Account No', s['bankDetails']?['accountNumber'] ?? 'Not specified'),
                                _detailRow('IFSC Code', s['bankDetails']?['ifscCode'] ?? 'Not specified'),
                                _detailRow('Holder Name', s['bankDetails']?['accountHolderName'] ?? s['ownerName'] ?? 'N/A'),
                                if (s['rejectionReason'] != null && s['rejectionReason'].toString().isNotEmpty)
                                  _detailRow('Rejection Note', s['rejectionReason'], isAlert: true),
                              ],
                            ),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _sectionTitle('Storefront Verification'),
                                const SizedBox(height: 10),
                                _buildDocCard('Storefront Photo', storeImage, Icons.storefront),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const Divider(height: 28),

            // Action Buttons
            Wrap(
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 10,
              runSpacing: 8,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
                if (status == 'pending' || status == 'rejected') ...[
                  OutlinedButton.icon(
                    icon: const Icon(Icons.cancel_outlined, color: Color(0xFFDC2626), size: 18),
                    label: const Text('Reject Application', style: TextStyle(color: Color(0xFFDC2626))),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFDC2626)),
                      padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 18, vertical: isMobile ? 10 : 14),
                    ),
                    onPressed: _isLoading ? null : _showRejectPrompt,
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.check_circle_outline, size: 18),
                    label: const Text('Approve Store Outlet', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: isMobile ? 14 : 22, vertical: isMobile ? 10 : 14),
                    ),
                    onPressed: _isLoading ? null : _approveStore,
                  ),
                ] else ...[
                  ElevatedButton.icon(
                    icon: const Icon(Icons.block_rounded, size: 18),
                    label: const Text('Revoke / Reject Store'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 18, vertical: isMobile ? 10 : 14),
                    ),
                    onPressed: _isLoading ? null : _showRejectPrompt,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E293B)),
    );
  }

  Widget _detailRow(String label, String value, {bool isAlert = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isAlert ? const Color(0xFFDC2626) : const Color(0xFF1E293B),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocCard(String title, String url, IconData icon) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: const Color(0xFF0D47A1)),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: url.startsWith('http')
                ? Image.network(
                    url,
                    height: 110,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => _placeholder(title),
                  )
                : _placeholder(title),
          ),
        ],
      ),
    );
  }

  Widget _placeholder(String title) {
    return Container(
      height: 100,
      width: double.infinity,
      color: Colors.grey.shade200,
      child: Center(
        child: Text('Document on file ($title)', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color fg;
    String label;

    if (status == 'approved') {
      bg = const Color(0xFFDCFCE7);
      fg = const Color(0xFF15803D);
      label = 'APPROVED';
    } else if (status == 'rejected') {
      bg = const Color(0xFFFEE2E2);
      fg = const Color(0xFFB91C1C);
      label = 'REJECTED';
    } else {
      bg = const Color(0xFFFEF3C7);
      fg = const Color(0xFFB45309);
      label = 'PENDING APPROVAL';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(label, style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
}
