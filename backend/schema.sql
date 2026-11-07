CREATE DATABASE IF NOT EXISTS voltora
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE voltora;

CREATE TABLE IF NOT EXISTS users (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  nom VARCHAR(120) NOT NULL,
  prenom VARCHAR(120) NOT NULL,
  birth_date DATE NOT NULL,
  phone VARCHAR(40) NOT NULL,
  email VARCHAR(254) NOT NULL UNIQUE,
  username VARCHAR(80) NOT NULL UNIQUE,
  password_hash VARCHAR(255) NOT NULL,
  role ENUM('user', 'admin') NOT NULL DEFAULT 'user',
  is_active TINYINT(1) NOT NULL DEFAULT 1,
  last_login_at DATETIME NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS login_history (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  user_id BIGINT UNSIGNED NULL,
  email VARCHAR(254) NOT NULL,
  succeeded TINYINT(1) NOT NULL,
  occurred_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_login_history_user_date (user_id, occurred_at),
  CONSTRAINT fk_login_history_user
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS admin_user_actions (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  target_user_id BIGINT UNSIGNED NULL,
  target_email VARCHAR(254) NOT NULL,
  admin_user_id BIGINT UNSIGNED NULL,
  action VARCHAR(40) NOT NULL,
  details JSON NULL,
  occurred_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_admin_user_actions_target_date (target_user_id, occurred_at),
  CONSTRAINT fk_admin_user_actions_admin
    FOREIGN KEY (admin_user_id) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS api_tokens (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  user_id BIGINT UNSIGNED NOT NULL,
  token_hash CHAR(64) NOT NULL UNIQUE,
  expires_at DATETIME NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_api_tokens_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS products (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(180) NOT NULL,
  brand VARCHAR(120) NOT NULL,
  category VARCHAR(100) NOT NULL,
  description TEXT NOT NULL,
  price DECIMAL(10,2) NOT NULL,
  promo_price DECIMAL(10,2) NULL,
  stock INT UNSIGNED NOT NULL DEFAULT 0,
  color_stock JSON NULL,
  rating DECIMAL(3,2) NOT NULL DEFAULT 0,
  reviews INT UNSIGNED NOT NULL DEFAULT 0,
  icon VARCHAR(60) NOT NULL DEFAULT 'devices',
  image_url TEXT NULL,
  image_urls JSON NULL,
  specs JSON NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_products_category (category)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS product_categories (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(100) NOT NULL UNIQUE,
  is_published TINYINT(1) NOT NULL DEFAULT 0,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

INSERT IGNORE INTO product_categories (name, is_published) VALUES
  ('Smartphones', 1),
  ('Ordinateurs', 1),
  ('Tablettes', 1),
  ('Casques', 1),
  ('Enceintes', 1),
  ('Montres', 1);

CREATE TABLE IF NOT EXISTS favorites (
  user_id BIGINT UNSIGNED NOT NULL,
  product_id BIGINT UNSIGNED NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (user_id, product_id),
  CONSTRAINT fk_favorites_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  CONSTRAINT fk_favorites_product FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS cart_items (
  user_id BIGINT UNSIGNED NOT NULL,
  product_id BIGINT UNSIGNED NOT NULL,
  color VARCHAR(80) NOT NULL DEFAULT '',
  quantity INT UNSIGNED NOT NULL,
  PRIMARY KEY (user_id, product_id, color),
  CONSTRAINT fk_cart_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  CONSTRAINT fk_cart_product FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS orders (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  number VARCHAR(40) NOT NULL UNIQUE,
  user_id BIGINT UNSIGNED NOT NULL,
  total DECIMAL(10,2) NOT NULL,
  item_count INT UNSIGNED NOT NULL,
  shipping_nom VARCHAR(120) NOT NULL,
  shipping_prenom VARCHAR(120) NOT NULL,
  shipping_address VARCHAR(240) NOT NULL,
  shipping_postal_code VARCHAR(12) NOT NULL,
  shipping_city VARCHAR(100) NOT NULL,
  status VARCHAR(40) NOT NULL DEFAULT 'En préparation',
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_orders_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE RESTRICT,
  INDEX idx_orders_created (created_at)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS order_items (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  order_id BIGINT UNSIGNED NOT NULL,
  product_id BIGINT UNSIGNED NOT NULL,
  product_name VARCHAR(180) NOT NULL,
  color VARCHAR(80) NOT NULL DEFAULT '',
  quantity INT UNSIGNED NOT NULL,
  unit_price DECIMAL(10,2) NOT NULL,
  CONSTRAINT fk_order_items_order FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE,
  CONSTRAINT fk_order_items_product FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE RESTRICT
) ENGINE=InnoDB;

INSERT IGNORE INTO products
  (id, name, brand, category, description, price, promo_price, stock, rating, reviews, icon, image_url, specs)
VALUES
  (1, 'Nova X Pro 256 Go, 5G', 'Nova', 'Smartphones',
   'Écran AMOLED 6,7 pouces, triple capteur photo et charge rapide.',
   899, 749, 12, 4.6, 128, 'smartphone',
   'https://images.unsplash.com/photo-1512499617640-c74ae3a79d37?auto=format&fit=max&w=1200&q=90',
   JSON_OBJECT('Écran', '6,7 pouces AMOLED', 'Stockage', '256 Go', 'Batterie', '5000 mAh')),
  (2, 'Pulse Mini 128 Go', 'Pulse', 'Smartphones',
   'Smartphone compact avec écran OLED lumineux.',
   499, NULL, 5, 4.2, 64, 'phone_android',
   'https://images.unsplash.com/photo-1598327105666-5b89351aff97?auto=format&fit=max&w=1200&q=90',
   JSON_OBJECT('Écran', '6,1 pouces OLED', 'Stockage', '128 Go', 'Batterie', '4200 mAh')),
  (3, 'AirBeat Studio - Blanc', 'Beatz', 'Casques',
   'Casque sans fil avec réduction de bruit et 40 heures d’autonomie.',
   249, 189, 20, 4.8, 310, 'headphones',
   'https://images.unsplash.com/photo-1505740420928-5e560c06d30e?auto=format&fit=max&w=1200&q=90',
   JSON_OBJECT('Autonomie', '40 h', 'Bluetooth', '5.3', 'Poids', '250 g')),
  (4, 'Buds Lite', 'Beatz', 'Casques',
   'Écouteurs intra-auriculaires avec boîtier de charge compact.',
   79, NULL, 0, 4.0, 87, 'earbuds',
   'https://images.unsplash.com/photo-1606220945770-b5b6c2c55bf1?auto=format&fit=max&w=1200&q=90',
   JSON_OBJECT('Autonomie', '8 h', 'Bluetooth', '5.2', 'Étanchéité', 'IPX4')),
  (5, 'Boom Speaker 360', 'Boom', 'Enceintes',
   'Enceinte portable étanche avec son à 360 degrés.',
   129, 99, 9, 4.5, 142, 'speaker',
   'https://images.unsplash.com/photo-1608043152269-423dbba4e7e1?auto=format&fit=max&w=1200&q=90',
   JSON_OBJECT('Autonomie', '20 h', 'Puissance', '30 W', 'Étanchéité', 'IP67')),
  (6, 'Chrono Ultra 47 mm, LTE', 'Chrono', 'Montres',
   'Montre connectée avec GPS et suivi sportif.',
   600, 580, 15, 4.9, 1800, 'watch',
   'https://images.unsplash.com/photo-1523275335684-37898b6baf30?auto=format&fit=max&w=1200&q=90',
   JSON_OBJECT('Boîtier', '47 mm titane', 'GPS', 'Double fréquence', 'Autonomie', '3 jours')),
  (7, 'Tab Air 11 - Gris sidéral', 'Nova', 'Tablettes',
   'Tablette 11 pouces pour le travail et le divertissement.',
   780, 750, 7, 4.4, 120, 'tablet_mac',
   'https://images.unsplash.com/photo-1544244015-0df4b3ffc6b0?auto=format&fit=max&w=1200&q=90',
   JSON_OBJECT('Écran', '11 pouces LCD', 'Stockage', '128 Go', 'RAM', '8 Go')),
  (8, 'Book Pro 14 - M3', 'Nova', 'Ordinateurs',
   'Ordinateur portable fin avec écran 14 pouces.',
   1499, 1399, 4, 4.7, 201, 'laptop_mac',
   'https://images.unsplash.com/photo-1517336714731-489689fd1ca8?auto=format&fit=max&w=1200&q=90',
   JSON_OBJECT('Écran', '14 pouces Retina', 'RAM', '16 Go', 'SSD', '512 Go'));
