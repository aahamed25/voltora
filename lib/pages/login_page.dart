import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../services/auth_service.dart';
import 'register_page.dart';

const _authBlue = Color.fromARGB(255, 102, 45, 140);

class LoginPage extends StatefulWidget {
  final String? prompt;
  final Future<void> Function()? onAuthenticated;

  const LoginPage({
    super.key,
    this.prompt,
    this.onAuthenticated,
  });

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSubmitting = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    try {
      final result = await authService.login(
        _identifierController.text,
        _passwordController.text,
      );
      if (!mounted) return;
      if (!result.ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.error ?? 'Connexion impossible')),
        );
        return;
      }
      await authService.refreshAdminSetupStatus();
      await appState.loadUserData();
      final onAuthenticated = widget.onAuthenticated;
      Navigator.of(context).pop();
      if (onAuthenticated != null) await onAuthenticated();
      appState.setTab(0);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: _authBlue,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Card(
                  color: Colors.white,
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Form(
                    key: _formKey,
                    child: ListView(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(28),
                      children: [
                        const Text(
                          'Voltora',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _authBlue,
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Connecte-toi à ton espace',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.black54),
                        ),
                        if (widget.prompt != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            widget.prompt!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.black54),
                          ),
                        ],
                        const SizedBox(height: 28),
                        TextFormField(
                          controller: _identifierController,
                          keyboardType: TextInputType.emailAddress,
                          autocorrect: false,
                          decoration: InputDecoration(
                            labelText: 'E-mail ou identifiant',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                                  ? 'Saisis ton e-mail ou ton identifiant'
                                  : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            labelText: 'Mot de passe',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            suffixIcon: IconButton(
                              onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                              ),
                            ),
                          ),
                          validator: (value) =>
                              value == null || value.isEmpty
                                  ? 'Saisis ton mot de passe'
                                  : null,
                        ),
                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed: _isSubmitting ? null : _submit,
                          style: FilledButton.styleFrom(
                            backgroundColor: _authBlue,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: _isSubmitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Se connecter'),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: _isSubmitting
                              ? null
                              : () => Navigator.of(context).pushReplacement(
                                  MaterialPageRoute<void>(
                                    builder: (_) => RegisterPage(
                                      onAuthenticated:
                                          widget.onAuthenticated,
                                    ),
                                  ),
                                ),
                          child: const Text('Pas encore de compte ? Inscris-toi'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}
