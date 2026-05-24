import 'package:flutter/material.dart';

Widget buildSectionContainer({
  required BuildContext context,
  required Widget child,
}) {
  final colorScheme = Theme.of(context).colorScheme;

  return Container(
    padding: const EdgeInsets.all(16),
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    decoration: BoxDecoration(
      color: colorScheme.surface,
      borderRadius: BorderRadius.circular(18),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.06),
          blurRadius: 14,
          offset: const Offset(0, 6),
        ),
      ],
    ),
    child: child,
  );
}

InputDecoration buildPillDecoration({
  required BuildContext context,
  required String hint,
  required IconData icon,
}) {
  final colorScheme = Theme.of(context).colorScheme;

  return InputDecoration(
    hintText: hint,
    prefixIcon: Icon(icon),
    filled: true,
    fillColor: colorScheme.surfaceVariant.withOpacity(0.4),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(30),
      borderSide: BorderSide.none,
    ),
  );
}

Widget buildEmptyState({
  required BuildContext context,
  required IconData icon,
  required String title,
  required String subtitle,
}) {
  final colorScheme = Theme.of(context).colorScheme;

  return buildSectionContainer(
    context: context,
    child: Column(
      children: [
        Container(
          height: 70,
          width: 70,
          decoration: BoxDecoration(
            color: colorScheme.primary.withOpacity(0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(icon, color: colorScheme.primary, size: 38),
        ),

        const SizedBox(height: 12),

        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),

        const SizedBox(height: 6),

        Text(
          subtitle,
          style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
}

Widget buildDateHeader({required String title}) {
  return Padding(
    padding: const EdgeInsets.fromLTRB(18, 14, 18, 4),
    child: Text(
      title,
      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
    ),
  );
}
