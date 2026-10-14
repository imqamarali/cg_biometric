import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/server_connection_provider.dart';
import '../providers/session_provider.dart';
import '../widgets/custom_dialog.dart';
import 'dashboard_screen.dart';
import '../services/api_service.dart';

class LoginScreen extends StatefulWidget {
  /// Shown above the form, e.g. when the session ended.
  final String? notice;

  const LoginScreen({super.key, this.notice});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;
  int _failedAttempts = 0;

  // Hidden endpoint editor: double-click the page, then type the phrase.
  static const _secretPhrase = 'allowtoupdateendpoint';
  final FocusNode _secretFocus = FocusNode(debugLabel: 'endpoint-secret');
  String _typed = '';
  bool _armed = false;
  Timer? _armTimer;

  @override
  void initState() {
    super.initState();
    _errorMessage = widget.notice;
  }

  void _arm() {
    FocusManager.instance.primaryFocus?.unfocus();
    _secretFocus.requestFocus();
    _armTimer?.cancel();
    _armTimer = Timer(const Duration(seconds: 15), _disarm);
    _typed = '';
    _armed = true;
  }

  void _disarm() {
    _armed = false;
    _typed = '';
  }

  KeyEventResult _onSecretKey(FocusNode node, KeyEvent event) {
    if (!_armed || event is! KeyDownEvent) return KeyEventResult.ignored;
    final ch = event.character;
    if (ch == null || ch.isEmpty) return KeyEventResult.ignored;
    _typed += ch.toLowerCase();
    if (_typed.length > _secretPhrase.length) {
      _typed = _typed.substring(_typed.length - _secretPhrase.length);
    }
    if (_typed == _secretPhrase) {
      _armTimer?.cancel();
      _disarm();
      _showEndpointDialog();
    }
    return KeyEventResult.handled;
  }

  Future<void> _showEndpointDialog() async {
    final controller = TextEditingController(
      text: await ApiService.getBaseUrl(),
    );
    if (!mounted) return;
    String? error;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('API endpoint'),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Base URL of the server, e.g. https://erp.example.com/admin/web. '
                  'The app calls <base URL>/biometric_gateway/index.php. '
                  'Leave empty to use the built-in default.',
                  style: TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: controller,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: 'Base URL',
                    prefixIcon: const Icon(Icons.link),
                    errorText: error,
                    border: const OutlineInputBorder(),
                  ),
                  onSubmitted: (_) async {
                    if (await ApiService.setBaseUrl(controller.text)) {
                      if (ctx.mounted) Navigator.of(ctx).pop();
                    } else {
                      setLocal(() => error = 'Enter a valid http(s) URL');
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (await ApiService.setBaseUrl(controller.text)) {
                  if (ctx.mounted) Navigator.of(ctx).pop();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('API endpoint saved')),
                    );
                  }
                } else {
                  setLocal(() => error = 'Enter a valid http(s) URL');
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
  }

  @override
  void dispose() {
    _armTimer?.cancel();
    _secretFocus.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      final username = _usernameController.text.trim();
      final password = _passwordController.text;

      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final success = await ApiService.login(
        username: username,
        password: password,
      );

      setState(() {
        _isLoading = false;
      });

      if (success['success'] == true) {
        setState(() {
          _failedAttempts = 0;
        });

        if (mounted) {
          context.read<SessionProvider>().loadSession();
          var connectionProvider = context.read<ServerConnectionProvider>();
          connectionProvider.start();
          Future.delayed(const Duration(seconds: 1), () {
            connectionProvider.manualCheck();
          });
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const DashboardScreen()),
          );
        }
      } else {
        setState(() {
          _failedAttempts++;
          _errorMessage = success['message']?.toString() ?? 'Login failed';

          if (_failedAttempts >= 5) {
            SuccessDialog.show(
              context: context,
              title: 'Too Many Failed Attempts',
              message: 'Please try again later.',
            );
            return;
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFE4E6E9),
      body: Focus(
        focusNode: _secretFocus,
        onKeyEvent: _onSecretKey,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onDoubleTap: _arm,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(bottom: 18),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.fingerprint,
                            size: 38,
                            color: Color(0xFF438EB9),
                          ),
                          SizedBox(width: 8),
                          Text(
                            'CG Biometric',
                            style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w300,
                              color: Color(0xFF438EB9),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Login Form
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: const Color(0xFFD5D5D5)),
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Error Message
                            if (_errorMessage != null) ...[
                              Container(
                                padding: const EdgeInsets.all(12),
                                margin: const EdgeInsets.only(bottom: 16),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.errorContainer,
                                  borderRadius: BorderRadius.zero,
                                  border: Border.all(
                                    color: theme.colorScheme.error,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.error_outline,
                                      color: theme.colorScheme.onErrorContainer,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _errorMessage!,
                                        style: TextStyle(
                                          color: theme
                                              .colorScheme
                                              .onErrorContainer,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            // Username Field
                            TextFormField(
                              controller: _usernameController,
                              decoration: InputDecoration(
                                labelText: 'Username',
                                hintText: 'Enter your username',
                                prefixIcon: const Icon(Icons.person_outline),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.zero,
                                ),
                                filled: true,
                                fillColor:
                                    theme.inputDecorationTheme.fillColor ??
                                    theme.colorScheme.surface,
                              ),
                              style: TextStyle(
                                color: theme.textTheme.bodyLarge?.color,
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your username';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // Password Field
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              decoration: InputDecoration(
                                labelText: 'Password',
                                hintText: 'Enter your password',
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.zero,
                                ),
                                filled: true,
                                fillColor:
                                    theme.inputDecorationTheme.fillColor ??
                                    theme.colorScheme.surface,
                              ),
                              style: TextStyle(
                                color: theme.textTheme.bodyLarge?.color,
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your password';
                                }
                                return null;
                              },
                              onFieldSubmitted: (_) => _handleLogin(),
                            ),
                            const SizedBox(height: 24),

                            // Login Button
                            ElevatedButton(
                              onPressed: _isLoading ? null : _handleLogin,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: theme.primaryColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.zero,
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                      ),
                                    )
                                  : const Text(
                                      'Sign In',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
