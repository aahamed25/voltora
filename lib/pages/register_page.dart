import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../state/app_state.dart';

const _authBlue = Color.fromARGB(255, 96, 45, 140);

class RegisterPage extends StatefulWidget {
  final Future<void> Function()? onAuthenticated;
  final bool isAdminCreation;

  const RegisterPage({
    super.key,
    this.onAuthenticated,
    this.isAdminCreation = false,
  });

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _nomController = TextEditingController();
  final _prenomController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _adminSetupKeyController = TextEditingController();

  DateTime? _birthDate;
  bool _isSubmitting = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _nomController.dispose();
    _prenomController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _adminSetupKeyController.dispose();
    super.dispose();
  }

  Future<void> _selectBirthDate() async {
    final today = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: DateTime(today.year - 18, today.month, today.day),
      firstDate: DateTime(1900),
      lastDate: today,
      helpText: 'Sélectionne ta date de naissance',
    );
    if (selected != null && mounted) {
      setState(() => _birthDate = selected);
    }
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    final birthDate = _birthDate;
    if (birthDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sélectionne ta date de naissance')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final result = widget.isAdminCreation
          ? await authService.registerAdmin(
              nom: _nomController.text,
              prenom: _prenomController.text,
              birthDate: birthDate,
              phone: _phoneController.text,
              email: _emailController.text,
              username: _usernameController.text,
              password: _passwordController.text,
              setupKey: _adminSetupKeyController.text.trim(),
            )
          : await authService.register(
              nom: _nomController.text,
              prenom: _prenomController.text,
              birthDate: birthDate,
              phone: _phoneController.text,
              email: _emailController.text,
              username: _usernameController.text,
              password: _passwordController.text,
            );
      if (!mounted) return;
      if (!result.ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.error ?? 'Inscription impossible')),
        );
        return;
      }
      await authService.refreshAdminSetupStatus();
      await appState.loadUserData();
      final onAuthenticated = widget.onAuthenticated;
      Navigator.of(context).pop();
      if (onAuthenticated != null) await onAuthenticated();
      if (!widget.isAdminCreation) appState.setTab(0);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String? _required(String? value, String label) {
    if (value == null || value.trim().isEmpty) return '$label est requis';
    return null;
  }

  InputDecoration _decoration(String label, {Widget? suffixIcon}) {
    return InputDecoration(
      labelText: label,
      suffixIcon: suffixIcon,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateText = _birthDate == null
        ? 'Date de naissance'
        : '${_birthDate!.day.toString().padLeft(2, '0')}/'
              '${_birthDate!.month.toString().padLeft(2, '0')}/'
              '${_birthDate!.year}';

    return Scaffold(
      backgroundColor: _authBlue,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
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
                      Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          onPressed: () => Navigator.of(context).maybePop(),
                          icon: const Icon(Icons.arrow_back),
                          tooltip: 'Retour',
                        ),
                      ),
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
                      Text(
                        widget.isAdminCreation
                            ? 'Création réservée au premier administrateur'
                            : 'Créer ton espace',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.black54),
                      ),
                      const SizedBox(height: 24),
                      if (widget.isAdminCreation) ...[
                        TextFormField(
                          controller: _adminSetupKeyController,
                          obscureText: true,
                          decoration: _decoration(
                            'Clé de création fournie par le serveur',
                          ),
                          validator: (value) => _required(
                            value,
                            'La clé de création administrateur',
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],
                      Text(
                        widget.isAdminCreation
                            ? 'Créer le compte administrateur'
                            : 'Inscription',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.isAdminCreation
                            ? 'Ce formulaire ne sera plus disponible après la création du compte administrateur.'
                            : 'Renseigne tes informations pour créer ton compte.',
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _prenomController,
                        textCapitalization: TextCapitalization.words,
                        decoration: _decoration('Prénom'),
                        validator: (value) => _required(value, 'Le prénom'),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _nomController,
                        textCapitalization: TextCapitalization.words,
                        decoration: _decoration('Nom'),
                        validator: (value) => _required(value, 'Le nom'),
                      ),
                      const SizedBox(height: 14),
                      OutlinedButton.icon(
                        onPressed: _selectBirthDate,
                        icon: const Icon(Icons.calendar_today),
                        label: Text(dateText),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _birthDate == null ? null : kViolet,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          alignment: Alignment.centerLeft,
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: _decoration('Téléphone'),
                        validator: (value) => _required(value, 'Le téléphone'),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        autocorrect: false,
                        decoration: _decoration('Adresse e-mail'),
                        validator: (value) {
                          final requiredError = _required(value, 'L’e-mail');
                          if (requiredError != null) return requiredError;
                          if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                              .hasMatch(value!.trim())) {
                            return 'Saisis une adresse e-mail valide';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _usernameController,
                        autocorrect: false,
                        decoration: _decoration('Identifiant'),
                        validator: (value) => _required(value, 'L’identifiant'),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: _decoration(
                          'Mot de passe',
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
                        validator: (value) {
                          final requiredError = _required(
                            value,
                            'Le mot de passe',
                          );
                          if (requiredError != null) return requiredError;
                          if (value!.length < 8) {
                            return '8 caractères minimum';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: _obscurePassword,
                        decoration: _decoration('Confirmer le mot de passe'),
                        validator: (value) {
                          if (value != _passwordController.text) {
                            return 'Les mots de passe ne correspondent pas';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: _isSubmitting ? null : _submit,
                        style: FilledButton.styleFrom(
                          backgroundColor: kViolet,
                          padding: const EdgeInsets.symmetric(vertical: 16),
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
                            : Text(
                                widget.isAdminCreation
                                    ? 'Créer le compte administrateur'
                                    : 'Créer mon compte',
                              ),
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
}
