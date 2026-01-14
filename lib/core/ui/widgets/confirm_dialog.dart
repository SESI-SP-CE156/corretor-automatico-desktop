// lib/core/ui/widgets/confirm_dialog.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ConfirmDialog {
  static Future<bool> show({
    required BuildContext context,
    required String title,
    required String content,
    String confirmText = 'CONFIRMAR',
    String cancelText = 'CANCELAR',
    bool isDanger = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(onPressed: () => ctx.pop(false), child: Text(cancelText)),
          ElevatedButton(
            style: isDanger
                ? ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  )
                : null,
            onPressed: () => ctx.pop(true),
            child: Text(confirmText),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}
