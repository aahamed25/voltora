import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../models/cart_item_key.dart';
import '../services/api_client.dart';
import '../state/app_state.dart';

class CheckoutAddressPage extends StatefulWidget {
  final Map<CartItemKey, int> items;
  final double total;

  const CheckoutAddressPage({
    super.key,
    required this.items,
    required this.total,
  });

  @override
  State<CheckoutAddressPage> createState() => _CheckoutAddressPageState();
}

class _CheckoutAddressPageState extends State<CheckoutAddressPage> {
  final _formKey = GlobalKey<FormState>();
  final _nom = TextEditingController();
  final _prenom = TextEditingController();
  final _address = TextEditingController();
  final _postalCode = TextEditingController();
  final _city = TextEditingController();

  @override
  void dispose() {
    _nom.dispose();
    _prenom.dispose();
    _address.dispose();
    _postalCode.dispose();
    _city.dispose();
    super.dispose();
  }

  void _continue() {
    if (!_formKey.currentState!.validate()) return;
    final shippingAddress = {
      'nom': _nom.text.trim(),
      'prenom': _prenom.text.trim(),
      'address': _address.text.trim(),
      'postal_code': _postalCode.text.trim(),
      'city': _city.text.trim(),
    };
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CheckoutPaymentPage(
          items: widget.items,
          total: widget.total,
          shippingAddress: shippingAddress,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Adresse de livraison')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const _CheckoutStepHeader(
                step: 1,
                title: 'Où livrer votre commande ?',
              ),
              const SizedBox(height: 8),
              Text(
                'Total de la commande : ${euro(widget.total)}',
                style: const TextStyle(
                  color: kViolet,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              _checkoutField(_prenom, 'Prénom'),
              _checkoutField(_nom, 'Nom'),
              _checkoutField(
                _address,
                'Adresse',
                hint: 'Numéro et nom de rue',
                textCapitalization: TextCapitalization.words,
              ),
              _checkoutField(
                _postalCode,
                'Code postal',
                keyboardType: TextInputType.number,
              ),
              _checkoutField(
                _city,
                'Ville',
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _continue,
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Continuer vers le paiement'),
                style: FilledButton.styleFrom(
                  backgroundColor: kViolet,
                  minimumSize: const Size.fromHeight(52),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class CheckoutPaymentPage extends StatefulWidget {
  final Map<CartItemKey, int> items;
  final double total;
  final Map<String, String> shippingAddress;

  const CheckoutPaymentPage({
    super.key,
    required this.items,
    required this.total,
    required this.shippingAddress,
  });

  @override
  State<CheckoutPaymentPage> createState() => _CheckoutPaymentPageState();
}

class _CheckoutPaymentPageState extends State<CheckoutPaymentPage> {
  final _formKey = GlobalKey<FormState>();
  final _cardholder = TextEditingController();
  final _cardNumber = TextEditingController();
  final _expiry = TextEditingController();
  final _securityCode = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _cardholder.dispose();
    _cardNumber.dispose();
    _expiry.dispose();
    _securityCode.dispose();
    super.dispose();
  }

  String? _validateCardNumber(String? value) {
    final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.length < 12 || digits.length > 19) {
      return 'Numéro de carte de démonstration invalide.';
    }
    return null;
  }

  String? _validateExpiry(String? value) {
    final match = RegExp(r'^(\d{2})/(\d{2})$').firstMatch(value?.trim() ?? '');
    if (match == null) return 'Format attendu : MM/AA.';
    final month = int.parse(match[1]!);
    if (month < 1 || month > 12) return 'Mois invalide.';
    return null;
  }

  String? _validateSecurityCode(String? value) {
    if (!RegExp(r'^\d{3,4}$').hasMatch(value?.trim() ?? '')) {
      return 'Saisis 3 ou 4 chiffres.';
    }
    return null;
  }

  Future<void> _pay() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      final order = await appState.placeOrder(
        widget.items,
        shippingAddress: widget.shippingAddress,
      );
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
      appState.setTab(2);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Paiement simulé confirmé — commande ${order.number}.'),
        ),
      );
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Paiement par carte')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const _CheckoutStepHeader(
                step: 2,
                title: 'Confirmer votre commande',
              ),
              const SizedBox(height: 16),
              Card(
                color: const Color(0xFFFFF4CC),
                child: const Padding(
                  padding: EdgeInsets.all(14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, color: Color(0xFF8A5A00)),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Paiement de démonstration uniquement : aucun débit '
                          'ne sera effectué. N’utilise pas une vraie carte. '
                          'Les données saisies ne sont ni envoyées ni enregistrées.',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Montant à confirmer : ${euro(widget.total)}',
                style: const TextStyle(
                  color: kViolet,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              _checkoutField(
                _cardholder,
                'Nom sur la carte de démonstration',
                textCapitalization: TextCapitalization.characters,
              ),
              _checkoutField(
                _cardNumber,
                'Numéro de carte fictive',
                hint: '4242 4242 4242 4242',
                keyboardType: TextInputType.number,
                validator: _validateCardNumber,
              ),
              Row(
                children: [
                  Expanded(
                    child: _checkoutField(
                      _expiry,
                      'Expiration',
                      hint: 'MM/AA',
                      keyboardType: TextInputType.datetime,
                      validator: _validateExpiry,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _checkoutField(
                      _securityCode,
                      'Cryptogramme fictif',
                      hint: '123',
                      keyboardType: TextInputType.number,
                      validator: _validateSecurityCode,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Livraison : ${widget.shippingAddress['prenom']} '
                '${widget.shippingAddress['nom']}, '
                '${widget.shippingAddress['address']}, '
                '${widget.shippingAddress['postal_code']} '
                '${widget.shippingAddress['city']}',
                style: const TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _submitting ? null : _pay,
                icon: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.lock_outline),
                label: Text(
                  _submitting
                      ? 'Confirmation…'
                      : 'Confirmer le paiement simulé',
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: kViolet,
                  minimumSize: const Size.fromHeight(52),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _CheckoutStepHeader extends StatelessWidget {
  final int step;
  final String title;

  const _CheckoutStepHeader({required this.step, required this.title});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      CircleAvatar(
        backgroundColor: kViolet,
        foregroundColor: Colors.white,
        child: Text('$step'),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Text(
          title,
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
      ),
    ],
  );
}

Widget _checkoutField(
  TextEditingController controller,
  String label, {
  String? hint,
  TextInputType? keyboardType,
  TextCapitalization textCapitalization = TextCapitalization.none,
  String? Function(String?)? validator,
}) => Padding(
  padding: const EdgeInsets.only(bottom: 14),
  child: TextFormField(
    controller: controller,
    keyboardType: keyboardType,
    textCapitalization: textCapitalization,
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      border: const OutlineInputBorder(),
    ),
    validator: validator ?? (value) => _checkoutRequired(value),
  ),
);

String? _checkoutRequired(String? value) =>
    value == null || value.trim().isEmpty ? 'Ce champ est requis.' : null;
