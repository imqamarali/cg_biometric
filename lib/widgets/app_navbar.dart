import 'package:cg_biometric/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/session_provider.dart';
import '../providers/navigation_provider.dart';
import '../providers/server_connection_provider.dart';
import '../screens/login_screen.dart';
import '../theme/ace_theme.dart';
import 'custom_dialog.dart';

class AppNavbar extends StatefulWidget {
  final VoidCallback? onMenuTap;

  const AppNavbar({super.key, this.onMenuTap});

  @override
  State<AppNavbar> createState() => _AppNavbarState();
}

class _AppNavbarState extends State<AppNavbar> {
  Future<void> _handleRefresh(BuildContext context) async {
    final navProvider = Provider.of<NavigationProvider>(context, listen: false);

    if (context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );
    }

    // Simulate refresh delay
    await Future.delayed(const Duration(milliseconds: 500));

    // Reset navigation to dashboard and signal sidebar to clear expanded items
    navProvider.resetToDashboard();

    // Close loading dialog
    if (context.mounted) {
      Navigator.of(context).pop();
    }

    // Show success message
    if (context.mounted) {
      SuccessDialog.show(
        context: context,
        title: 'Refresh Successful',
        message: 'Application has been refreshed and cache cleared.',
        width: 500,
        height: 220,
        barrierDismissible: false,
      );
    }
  }

  Future<void> _handleLogout(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
    // Show confirmation dialog using custom dialog
    final confirm = await ConfirmationDialog.show(
      context: context,
      title: 'Logout',
      message: 'Are you sure you want to logout?',
      confirmText: 'Logout',
      cancelText: 'Cancel',
      icon: Icons.logout,
      width: 500,
      height: 220,
      barrierDismissible: false,
    );
    if (!context.mounted) return;
    Navigator.of(context).pop();

    if (confirm == true && context.mounted) {
      await ApiService.logout();
      if (!context.mounted) return;
      context.read<ServerConnectionProvider>().stop();
      context.read<SessionProvider>().loadSession();
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    Widget navButton({
      required IconData icon,
      required String tooltip,
      required VoidCallback onTap,
    }) {
      return Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onTap,
          child: Container(
            width: 40,
            height: 34,
            margin: const EdgeInsets.only(left: 8),
            color: Ace.navbarDark,
            child: Icon(icon, color: Colors.white, size: 20),
          ),
        ),
      );
    }

    return Container(
      height: 50,
      color: Ace.navbar,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          Image.asset(
            'assets/logo/CG.jpeg',
            height: 30,
            width: 30,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) =>
                const Icon(Icons.fingerprint, color: Colors.white),
          ),
          const SizedBox(width: 10),
          const Text(
            'CG Biometric',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w300,
              color: Colors.white,
            ),
          ),
          if (!isMobile) ...[
            Container(
              width: 1,
              height: 50,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              color: Ace.navbarDark,
            ),
            const Text(
              'Biometric Verification System',
              style: TextStyle(fontSize: 14, color: Colors.white),
            ),
          ],
          const Spacer(),
          Consumer2<SessionProvider, ServerConnectionProvider>(
            builder: (context, session, server, _) {
              if (!session.hasSession) {
                return _statusButton(
                  'Offline Mode',
                  Icons.cloud_off_outlined,
                  Ace.danger,
                  isMobile,
                );
              }
              final connected = server.isConnected;
              final label = connected
                  ? 'Server connected'
                  : (server.errorMessage?.isNotEmpty == true
                        ? 'Server down'
                        : 'Server disconnected');
              return InkWell(
                onTap: server.manualCheck,
                child: _statusButton(
                  label,
                  server.isChecking
                      ? Icons.sync
                      : (connected
                            ? Icons.cloud_done_outlined
                            : Icons.cloud_off_outlined),
                  connected ? const Color(0xFF2E9D4F) : Ace.danger,
                  isMobile,
                ),
              );
            },
          ),
          navButton(
            icon: Icons.refresh,
            tooltip: 'Refresh',
            onTap: () => _handleRefresh(context),
          ),
          if (context.watch<SessionProvider>().hasSession)
            navButton(
              icon: Icons.logout,
              tooltip: 'Logout',
              onTap: () => _handleLogout(context),
            ),
        ],
      ),
    );
  }

  Widget _statusButton(String label, IconData icon, Color color, bool compact) {
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      color: color,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: Colors.white),
          if (!compact) ...[
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12.5,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
