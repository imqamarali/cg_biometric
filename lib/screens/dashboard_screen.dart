import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/server_connection_provider.dart';
import '../providers/session_provider.dart';
import '../services/reader_service.dart';
import 'package:flutter/services.dart';
import '../theme/ace_theme.dart';
import '../widgets/app_navbar.dart';
import '../widgets/custom_dialog.dart';
import 'biometric_registration.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    context.read<ServerConnectionProvider>().start();
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          AppNavbar(),
          Expanded(child: DashboardContent()),
        ],
      ),
    );
  }
}

class DashboardContent extends StatefulWidget {
  const DashboardContent({super.key});

  @override
  State<DashboardContent> createState() => _DashboardContentState();
}

class _DashboardContentState extends State<DashboardContent> {
  late Future<Map<String, dynamic>?> _loginInfo;
  Timer? _clock;
  DateTime _now = DateTime.now();
  ReaderStatus? _reader;
  Timer? _readerTimer;

  @override
  void initState() {
    super.initState();
    _loginInfo = context.read<SessionProvider>().getLastLogin();
    _checkReader();
    _readerTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _checkReader(),
    );
    _clock = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    _readerTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkReader() async {
    final status = await ReaderService.check();
    if (mounted) setState(() => _reader = status);
  }

  Future<void> _showDiagnostics() async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    final report = await ReaderService.diagnose();
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    await CustomDialog.show(
      context: context,
      title: 'Reader diagnostics',
      icon: Icons.medical_information_outlined,
      width: 760,
      height: 560,
      content: SingleChildScrollView(
        child: SelectableText(
          report,
          style: const TextStyle(fontFamily: 'Consolas', fontSize: 12.5),
        ),
      ),
      actions: [
        CustomDialogAction(
          label: 'Copy',
          dismissOnPressed: false,
          onPressed: () => Clipboard.setData(ClipboardData(text: report)),
        ),
        const CustomDialogAction(label: 'Close', isPrimary: true),
      ],
    );
  }

  void _open(String title, Widget content) {
    final size = MediaQuery.of(context).size;
    CustomDialog.show(
      context: context,
      title: title,
      height: size.height * 0.9,
      width: size.width * 0.9,
      content: content,
      barrierDismissible: false,
      showCloseButton: true,
    );
  }

  String get _greeting {
    final h = _now.hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String get _dateLabel {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final h = _now.hour % 12 == 0 ? 12 : _now.hour % 12;
    final m = _now.minute.toString().padLeft(2, '0');
    final ap = _now.hour < 12 ? 'AM' : 'PM';
    return '${days[_now.weekday - 1]}, ${_now.day} ${months[_now.month - 1]} '
        '${_now.year}  •  $h:$m $ap';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _loginInfo,
      builder: (context, snap) {
        final info = snap.data;
        return LayoutBuilder(
          builder: (context, c) {
            final wide = c.maxWidth >= 950;
            final pad = c.maxWidth < 700 ? 12.0 : 20.0;
            final minH = wide ? 400.0 : 860.0;
            final avail = c.maxHeight - 38 - pad * 2; // minus breadcrumb bar
            final h = avail < minH ? minH : avail;
            return Column(
              children: [
                _breadcrumb(info),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(pad),
                    child: SizedBox(
                      height: h,
                      child: Column(
                        children: [
                          _statRow(c.maxWidth),
                          const SizedBox(height: 14),
                          Expanded(
                            child: wide
                                ? Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Expanded(
                                        flex: 3,
                                        child: _leftColumn(true),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        flex: 2,
                                        child: _projectCard(info),
                                      ),
                                    ],
                                  )
                                : Column(
                                    children: [
                                      Expanded(
                                        flex: 3,
                                        child: _leftColumn(false),
                                      ),
                                      const SizedBox(height: 14),
                                      Expanded(
                                        flex: 2,
                                        child: _projectCard(info),
                                      ),
                                    ],
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ---------------- BREADCRUMB ----------------
  Widget _breadcrumb(Map<String, dynamic>? info) {
    final project = info?['project_name']?.toString();
    final rawName = (info?['name'] ?? info?['full_name'] ?? info?['username'])
        ?.toString();
    final name = (rawName == null || rawName.isEmpty)
        ? null
        : rawName.split('@').first;
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        color: Ace.breadcrumbBg,
        border: Border(bottom: BorderSide(color: Ace.borderLight)),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Row(
            children: [
              const Icon(Icons.home, size: 18, color: Ace.link),
              const SizedBox(width: 6),
              const Text(
                'Home',
                style: TextStyle(color: Ace.link, fontSize: 13),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.chevron_right, size: 16, color: Ace.muted),
              ),
              const Text('Dashboard', style: TextStyle(fontSize: 13)),
              const Spacer(),
              if (project != null)
                Text(
                  project,
                  style: const TextStyle(color: Ace.muted, fontSize: 12.5),
                ),
            ],
          ),
          Text(
            '${name == null ? _greeting : '$_greeting, $name'}   •   $_dateLabel',
            style: const TextStyle(fontSize: 13, color: Ace.text),
          ),
        ],
      ),
    );
  }

  Widget _leftColumn(bool wide) {
    return Column(
      children: [
        Expanded(child: _actions()),
        const SizedBox(height: 14),
        _guideStrip(wide),
      ],
    );
  }

  // ---------------- STATUS INFOBOXES ----------------
  Widget _statRow(double width) {
    return Consumer<ServerConnectionProvider>(
      builder: (context, server, _) {
        final last = server.lastCheckTime;
        String two(int n) => n.toString().padLeft(2, '0');
        final lastLabel = last == null
            ? 'Checking...'
            : 'Checked ${two(last.hour)}:${two(last.minute)}:${two(last.second)}';
        final tiles = <Widget>[
          _InfoBox(
            icon: server.isConnected
                ? Icons.cloud_done_outlined
                : Icons.cloud_off_outlined,
            color: server.isConnected ? Ace.successDark : Ace.danger,
            label: 'Server',
            value: last == null
                ? 'Checking'
                : (server.isConnected ? 'Connected' : 'Unreachable'),
            hint: lastLabel,
            onTap: server.manualCheck,
          ),
          _InfoBox(
            icon: Icons.sensors,
            color: _reader == null
                ? Ace.grey
                : (_reader!.isReady ? Ace.info : Ace.danger),
            label: 'Fingerprint scanner',
            value: _reader?.title ?? 'Checking...',
            hint: _reader?.hint ?? '',
            onTap: _checkReader,
            trailing: IconButton(
              tooltip: 'Reader diagnostics',
              icon: const Icon(
                Icons.medical_information_outlined,
                color: Colors.white,
              ),
              onPressed: _showDiagnostics,
            ),
          ),
          const _InfoBox(
            icon: Icons.verified_user_outlined,
            color: Ace.purple,
            label: 'Session',
            value: 'Signed in',
            hint: 'Token active',
          ),
          _InfoBox(
            icon: Icons.computer,
            color: const Color(0xFF555555),
            label: 'Workstation',
            value: Platform.localHostname,
            hint: Platform.operatingSystem,
          ),
        ];
        final cols = width >= 950 ? 4 : 2;
        final rows = <Widget>[];
        for (var i = 0; i < tiles.length; i += cols) {
          if (i > 0) rows.add(const SizedBox(height: 10));
          rows.add(
            Row(
              children: [
                for (var j = i; j < i + cols; j++) ...[
                  if (j > i) const SizedBox(width: 10),
                  Expanded(child: tiles[j]),
                ],
              ],
            ),
          );
        }
        return Column(children: rows);
      },
    );
  }

  // ---------------- ACTIONS ----------------
  Widget _actions() {
    Widget tile(
      IconData icon,
      Color color,
      String title,
      String description,
      String operation,
    ) {
      return _ActionTile(
        icon: icon,
        color: color,
        title: title,
        description: description,
        onTap: () =>
            _open(title, BiometricRegistrationScreen(operation: operation)),
      );
    }

    return AceWidgetBox(
      title: 'Quick Actions',
      icon: Icons.bolt,
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: tile(
              Icons.fingerprint,
              Ace.successDark,
              'Member Registration',
              'Scan once and save the fingerprint against the CNIC.',
              'registration',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: tile(
              Icons.folder_open,
              Ace.primary,
              'Allotment Verification',
              'Scan a finger and match it with the saved fingerprint for a file.',
              'allotment',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: tile(
              Icons.swap_horiz,
              Ace.purple,
              'Transfer Verification',
              'Scan a finger and match it with the saved fingerprint for a transfer.',
              'transfer',
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- PROJECT ----------------
  Widget _projectCard(Map<String, dynamic>? info) {
    final logo = info?['project_logo'] as String?;
    String v(String k) {
      final s = info?[k]?.toString().trim();
      return (s == null || s.isEmpty) ? '-' : s;
    }

    return AceWidgetBox(
      title: 'Project Overview',
      icon: Icons.business_outlined,
      padding: const EdgeInsets.all(14),
      child: info == null
          ? const Text(
              'No project information available.',
              style: TextStyle(color: Ace.muted),
            )
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (logo != null && logo.isNotEmpty)
                        Container(
                          width: 46,
                          height: 46,
                          margin: const EdgeInsets.only(right: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Ace.borderLight),
                            image: DecorationImage(
                              image: NetworkImage(logo),
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      Expanded(
                        child: Text(
                          v('project_name'),
                          style: const TextStyle(
                            fontSize: 17,
                            color: Color(0xFF2679B5),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Divider(height: 1),
                  const SizedBox(height: 4),
                  _InfoRow(Icons.email_outlined, 'Email', v('project_email')),
                  _InfoRow(
                    Icons.phone_outlined,
                    'Contact',
                    v('project_contact'),
                  ),
                  _InfoRow(
                    Icons.location_on_outlined,
                    'Address',
                    v('project_address'),
                  ),
                ],
              ),
            ),
    );
  }

  // ---------------- GUIDE ----------------
  Widget _guideStrip(bool wide) {
    const steps = [
      ('Register once', 'Scan and save by CNIC'),
      ('Verify by CNIC', 'File or transfer + CNIC'),
      ('Scan to verify', 'Matched with saved print'),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Ace.border),
      ),
      child: Row(
        children: [
          if (wide)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Text(
                'How it works',
                style: TextStyle(fontSize: 14, color: Ace.widgetTitle),
              ),
            ),
          for (var i = 0; i < steps.length; i++)
            Expanded(
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: Ace.info,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${i + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          steps[i].$1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12.5,
                          ),
                        ),
                        Text(
                          steps[i].$2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Ace.muted,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ======================= REUSABLE PIECES =======================

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 7),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Ace.borderLight)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: Ace.info),
          const SizedBox(width: 10),
          SizedBox(
            width: 64,
            child: Text(
              label,
              style: const TextStyle(color: Ace.muted, fontSize: 13),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

/// Ace "infobox": solid colour block with a white icon and text.
class _InfoBox extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final String hint;
  final VoidCallback? onTap;
  final Widget? trailing;
  const _InfoBox({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.hint,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 66,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Icon(icon, color: Colors.white, size: 34),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      value,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.95),
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      hint,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
        ),
      ),
    );
  }
}

/// Large Ace "btn-app" style action.
class _ActionTile extends StatefulWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String description;
  final VoidCallback onTap;
  const _ActionTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
    required this.onTap,
  });

  @override
  State<_ActionTile> createState() => _ActionTileState();
}

class _ActionTileState extends State<_ActionTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _hover ? widget.color : Colors.white,
            border: Border.all(color: widget.color),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                widget.icon,
                size: 44,
                color: _hover ? Colors.white : widget.color,
              ),
              const SizedBox(height: 10),
              Text(
                widget.title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: _hover ? Colors.white : widget.color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.description,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.3,
                  color: _hover
                      ? Colors.white.withValues(alpha: 0.95)
                      : Ace.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
