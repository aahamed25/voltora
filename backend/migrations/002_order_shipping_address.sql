USE voltora;

ALTER TABLE orders
  ADD COLUMN shipping_nom VARCHAR(120) NOT NULL DEFAULT '' AFTER item_count,
  ADD COLUMN shipping_prenom VARCHAR(120) NOT NULL DEFAULT '' AFTER shipping_nom,
  ADD COLUMN shipping_address VARCHAR(240) NOT NULL DEFAULT '' AFTER shipping_prenom,
  ADD COLUMN shipping_postal_code VARCHAR(12) NOT NULL DEFAULT '' AFTER shipping_address,
  ADD COLUMN shipping_city VARCHAR(100) NOT NULL DEFAULT '' AFTER shipping_postal_code;
