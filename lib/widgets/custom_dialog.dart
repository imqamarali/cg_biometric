import 'package:flutter/material.dart';

class CustomDialog extends StatelessWidget {
  final String title;
  final Widget content;
  final List<CustomDialogAction>? actions;
  final bool showCloseButton;
  final double? width;
  final double? height; // Added height
  final IconData? icon;

  const CustomDialog({
    super.key,
    required this.title,
    required this.content,
    this.actions,
    this.showCloseButton = true,
    this.width,
    this.height, // Added
    this.icon,
  });

  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    required Widget content,
    List<CustomDialogAction>? actions,
    bool showCloseButton = true,
    double? width,
    double? height, // Added
    IconData? icon,
    bool barrierDismissible = true,
    bool useRootNavigator = false,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      useRootNavigator: useRootNavigator,
      builder: (context) => CustomDialog(
        title: title,
        content: content,
        actions: actions,
        showCloseButton: showCloseButton,
        width: width,
        height: height, // Pass height
        icon: icon,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: width ?? 800,
          maxHeight: height ?? 600,
          minWidth: 300,
          minHeight: 200,
        ),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.zero,
          border: Border.all(color: const Color(0xFFD5D5D5)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header
            if (title.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 15,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F7F7),
                  border: Border(
                    bottom: BorderSide(color: theme.dividerColor, width: 1),
                  ),
                ),
                child: Row(
                  children: [
                    if (icon != null) ...[
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: theme.primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.zero,
                        ),
                        child: Icon(icon, color: theme.primaryColor, size: 24),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w400,
                          color: const Color(0xFF669FC7),
                        ),
                      ),
                    ),
                    if (showCloseButton)
                      IconButton(
                        icon: Icon(
                          Icons.close,
                          color: theme.textTheme.bodyMedium?.color,
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                  ],
                ),
              ),

            // Content (no scrolling)
            Expanded(
              child: Padding(padding: const EdgeInsets.all(15), child: content),
            ),

            // Actions
            if (actions != null && actions!.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  border: Border(
                    top: BorderSide(color: theme.dividerColor, width: 1),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: actions!.map((action) {
                    return Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: _CustomDialogButton(
                        action: action,
                        onPressed: () {
                          if (action.onPressed != null) {
                            action.onPressed!();
                          }
                          if (action.dismissOnPressed) {
                            Navigator.of(context).pop(action.returnValue);
                          }
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class CustomDialogAction {
  final String label;
  final VoidCallback? onPressed;
  final bool isPrimary;
  final bool isDanger;
  final bool dismissOnPressed;
  final dynamic returnValue;

  const CustomDialogAction({
    required this.label,
    this.onPressed,
    this.isPrimary = false,
    this.isDanger = false,
    this.dismissOnPressed = true,
    this.returnValue,
  });
}

class _CustomDialogButton extends StatelessWidget {
  final CustomDialogAction action;
  final VoidCallback onPressed;

  const _CustomDialogButton({required this.action, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (action.isDanger) {
      return OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.red,
          side: const BorderSide(color: Colors.red),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        ),
        child: Text(
          action.label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      );
    } else if (action.isPrimary) {
      return ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          elevation: 0,
        ),
        child: Text(
          action.label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      );
    } else {
      return OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: theme.textTheme.bodyLarge?.color,
          side: BorderSide(color: theme.dividerColor),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        ),
        child: Text(
          action.label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      );
    }
  }
}

// Helper method for confirmation dialogs
class ConfirmationDialog {
  static Future<bool?> show({
    required BuildContext context,
    required String title,
    required String message,
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
    bool isDanger = false,
    IconData? icon,
    double? width,
    double? height,
    bool barrierDismissible = true,
    bool useRootNavigator = false,
  }) {
    return CustomDialog.show<bool>(
      context: context,
      title: title,
      icon: icon ?? Icons.warning_outlined,
      width: width,
      height: height,
      barrierDismissible: barrierDismissible,
      useRootNavigator: useRootNavigator,
      content: Builder(
        builder: (context) => Text(
          message,
          style: TextStyle(
            fontSize: 14,
            color: Theme.of(context).textTheme.bodyMedium?.color,
            height: 1.5,
          ),
        ),
      ),
      actions: [
        CustomDialogAction(
          label: cancelText,
          isPrimary: false,
          dismissOnPressed: true,
          returnValue: false,
        ),
        CustomDialogAction(
          label: confirmText,
          isPrimary: !isDanger,
          isDanger: isDanger,
          dismissOnPressed: true,
          returnValue: true,
        ),
      ],
    );
  }
}

// Helper method for info dialogs
class InfoDialog {
  static Future<void> show({
    required BuildContext context,
    required String title,
    required String message,
    String buttonText = 'OK',
    IconData? icon,
    double? width,
    double? height,
  }) {
    return CustomDialog.show(
      context: context,
      title: title,
      icon: icon ?? Icons.info_outline,
      width: width,
      height: height,
      content: Builder(
        builder: (context) => Text(
          message,
          style: TextStyle(
            fontSize: 14,
            color: Theme.of(context).textTheme.bodyMedium?.color,
            height: 1.5,
          ),
        ),
      ),
      actions: [
        CustomDialogAction(
          label: buttonText,
          isPrimary: true,
          dismissOnPressed: true,
        ),
      ],
    );
  }
}

// Helper method for success dialogs
class SuccessDialog {
  static Future<void> show({
    required BuildContext context,
    required String title,
    required String message,
    String buttonText = 'OK',
    double? width,
    double? height,
    bool barrierDismissible = false,
  }) {
    return CustomDialog.show(
      context: context,
      title: title,
      icon: Icons.check_circle_outline,
      width: width,
      height: height,
      barrierDismissible: barrierDismissible,
      content: Builder(
        builder: (context) => Text(
          message,
          style: TextStyle(
            fontSize: 14,
            color: Theme.of(context).textTheme.bodyMedium?.color,
            height: 1.5,
          ),
        ),
      ),
      actions: [
        CustomDialogAction(
          label: buttonText,
          isPrimary: true,
          dismissOnPressed: true,
        ),
      ],
    );
  }
}

class ErrorDialog {
  static Future<void> show({
    required BuildContext context,
    required String title,
    required String message,
    String buttonText = 'OK',
    double? width,
    double? height,
  }) {
    return CustomDialog.show(
      context: context,
      title: title,
      icon: Icons.error_outline,
      width: width,
      height: height,
      content: Builder(
        builder: (context) => Text(
          message,
          style: TextStyle(
            fontSize: 14,
            color: Theme.of(context).textTheme.bodyMedium?.color,
            height: 1.5,
          ),
        ),
      ),
      actions: [
        CustomDialogAction(
          label: buttonText,
          isPrimary: true,
          dismissOnPressed: true,
        ),
      ],
    );
  }

  // Create error callback for API service
  static void Function(String, String) createCallback(BuildContext context) {
    return (String title, String message) {
      show(context: context, title: title, message: message);
    };
  }
}
