USE voltora;

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