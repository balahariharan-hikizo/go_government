import 'package:flutter/material.dart';

Widget buildKpiCard({
  required String title,
  required String count,
  required String subtitle,
  required IconData icon,
  required Color color,
  required Color bgColor,
  bool isAlert = false,
}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: isAlert ? color : const Color(0xFFE2E8F0), width: isAlert ? 1.5 : 1),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.02),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                count,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                subtitle,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget buildFilterTab({
  required String label,
  required String tabKey,
  required int badgeCount,
  required Color activeColor,
  required String currentSelected,
  required VoidCallback onTap,
}) {
  final isSelected = currentSelected == tabKey;

  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isSelected ? activeColor.withValues(alpha: 0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isSelected ? activeColor : Colors.transparent),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? activeColor : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: isSelected ? activeColor : const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$badgeCount',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : const Color(0xFF64748B),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

Widget tableHeader(String title) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    child: Text(
      title,
      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 0.5),
    ),
  );
}

Widget buildResponsiveKpiGrid(List<Widget> cards) {
  return LayoutBuilder(
    builder: (ctx, constraints) {
      final maxW = constraints.maxWidth;
      if (maxW <= 0) return const SizedBox.shrink();

      int cols;
      if (maxW >= 1200) {
        cols = 4;
      } else if (maxW >= 650) {
        cols = 2;
      } else {
        cols = 1;
      }

      const double gap = 16.0;
      final double cardW = cols == 1 ? maxW : ((maxW - ((cols - 1) * gap)) / cols).clamp(100.0, maxW);

      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: cards.map((c) => SizedBox(width: cardW, child: c)).toList(),
      );
    },
  );
}

Widget buildEmptyState(String type, String selectedTab) {
  String title = 'No records found in "$selectedTab" category';
  if (type == 'complaints') {
    title = 'No grievances found in "$selectedTab" category';
  } else if (type == 'stores') {
    title = 'No stores found in "$selectedTab" queue';
  } else if (type == 'feedback') {
    title = 'No citizen feedback found in "$selectedTab" filter';
  }

  return Padding(
    padding: const EdgeInsets.all(60),
    child: Center(
      child: Column(
        children: [
          Icon(Icons.check_circle_outline_rounded, size: 56, color: Colors.grey.shade400),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
          ),
          const SizedBox(height: 6),
          Text(
            'All citizen records in this category have been processed.',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
          ),
        ],
      ),
    ),
  );
}

