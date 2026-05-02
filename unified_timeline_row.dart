// Unified timeline row with swipe (no packages)
// Delete: swipe right -> left
// Future: left -> right for complete

import 'package:flutter/material.dart';

class UnifiedTimelineRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isDone;
  final VoidCallback onDelete;
  final VoidCallback onToggle;

  const UnifiedTimelineRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.isDone,
    required this.onDelete,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Dismissible(
      key: ValueKey(title),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
          width: 40,
          height: 40,
          decoration: const BoxDecoration(
            color: Colors.red,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.delete, color: Colors.white),
        ),
      ),
      onDismissed: (_) => onDelete(),
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: onToggle,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isDone
                              ? colorScheme.primary
                              : colorScheme.outline,
                        ),
                        color: isDone
                            ? colorScheme.primary
                            : Colors.transparent,
                      ),
                      child: isDone
                          ? Icon(Icons.check,
                              size: 14, color: colorScheme.onPrimary)
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            decoration:
                                isDone ? TextDecoration.lineThrough : null,
                          ),
                        ),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
        ],
      ),
    );
  }
}
