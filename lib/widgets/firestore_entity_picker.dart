import 'package:flutter/material.dart';

/// Picks from Firestore-backed options (reliable on web vs nested [DropdownButton]).
class FirestoreEntityPicker extends StatelessWidget {
  const FirestoreEntityPicker({
    super.key,
    required this.label,
    required this.options,
    required this.selectedId,
    required this.onSelected,
    this.hint = 'בחר…',
    this.emptyMessage = 'אין פריטים — צור מסמכים ב-Firestore',
  });

  final String label;
  final List<({String id, String label})> options;
  final String? selectedId;
  final ValueChanged<String> onSelected;
  final String hint;
  final String emptyMessage;

  String? get _resolvedLabel {
    if (selectedId == null) {
      return null;
    }
    for (final o in options) {
      if (o.id == selectedId) {
        return o.label;
      }
    }
    return selectedId;
  }

  Future<void> _openSheet(BuildContext context) async {
    if (options.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(emptyMessage)),
      );
      return;
    }
    final theme = Theme.of(context);
    final maxH = MediaQuery.sizeOf(context).height * 0.55;
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Text(label, style: theme.textTheme.titleMedium),
              ),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxH),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final o in options)
                      ListTile(
                        title: Text(o.label),
                        subtitle: Text(o.id, style: theme.textTheme.bodySmall),
                        selected: selectedId == o.id,
                        onTap: () => Navigator.pop(ctx, o.id),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
    if (picked != null && context.mounted) {
      onSelected(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = _resolvedLabel ?? hint;
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => _openSheet(context),
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: label,
              border: const OutlineInputBorder(),
              suffixIcon: const Icon(Icons.arrow_drop_down),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                text,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: selectedId == null
                      ? theme.colorScheme.onSurfaceVariant
                      : theme.colorScheme.onSurface,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
