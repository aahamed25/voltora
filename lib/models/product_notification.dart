class ProductNotification {
  final int productId;
  final String productName;
  final DateTime createdAt;
  final bool isRead;

  const ProductNotification({
    required this.productId,
    required this.productName,
    required this.createdAt,
    this.isRead = false,
  });

  ProductNotification copyWith({bool? isRead}) => ProductNotification(
    productId: productId,
    productName: productName,
    createdAt: createdAt,
    isRead: isRead ?? this.isRead,
  );

  Map<String, dynamic> toJson() => {
    'product_id': productId,
    'product_name': productName,
    'created_at': createdAt.toIso8601String(),
    'is_read': isRead,
  };

  factory ProductNotification.fromJson(Map<String, dynamic> json) =>
      ProductNotification(
        productId: (json['product_id'] as num).toInt(),
        productName: json['product_name'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
        isRead: json['is_read'] as bool? ?? false,
      );
}
