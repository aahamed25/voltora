class CartItemKey {
  final int productId;
  final String? color;

  const CartItemKey(this.productId, {this.color});

  @override
  bool operator ==(Object other) =>
      other is CartItemKey &&
      other.productId == productId &&
      other.color == color;

  @override
  int get hashCode => Object.hash(productId, color);
}
