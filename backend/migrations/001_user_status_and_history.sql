USE voltora;

ALTER TABLE users
  ADD COLUMN is_active TINYINT(1) NOT NULL DEFAULT 1 AFTER role,
  ADD COLUMN last_login_at DATETIME NULL AFTER is_active;

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
