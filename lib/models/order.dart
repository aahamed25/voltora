class Order {
  final String number;
  final double total;
  final int itemCount;
  final DateTime date;
  final String status;
  final String? shippingAddress;
  Order(this.number, this.total, this.itemCount, this.date,
      {this.status = 'En préparation', this.shippingAddress});

  factory Order.fromJson(Map<String, dynamic> json) => Order(
    json['number'] as String,
    num.parse(json['total'].toString()).toDouble(),
    num.parse(json['item_count'].toString()).toInt(),
    DateTime.parse(
      (json['created_at'] as String).replaceFirst(' ', 'T'),
    ),
    status: json['status'] as String? ?? 'En préparation',
    shippingAddress: _shippingAddress(json),
  );
}

String? _shippingAddress(Map<String, dynamic> json) {
  final address = [
    json['shipping_address'],
    json['shipping_postal_code'],
    json['shipping_city'],
  ].where((part) => part != null && part.toString().isNotEmpty).join(', ');
  final firstName = json['shipping_prenom']?.toString() ?? '';
  final lastName = json['shipping_nom']?.toString() ?? '';
  final name = '$firstName $lastName'.trim();
  final combined = [name, address].where((part) => part.isNotEmpty).join(' · ');
  return combined.isEmpty ? null : combined;
}
