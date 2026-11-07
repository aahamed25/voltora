USE voltora;

ALTER TABLE products
  ADD COLUMN color_stock JSON NULL AFTER stock;

ALTER TABLE cart_items
  DROP PRIMARY KEY,
  ADD COLUMN color VARCHAR(80) NOT NULL DEFAULT '' AFTER product_id,
  ADD PRIMARY KEY (user_id, product_id, color);

ALTER TABLE order_items
  ADD COLUMN color VARCHAR(80) NOT NULL DEFAULT '' AFTER product_name;
