CREATE TABLE users (
  id          SERIAL       NOT NULL PRIMARY KEY,
  email       VARCHAR(255) NOT NULL UNIQUE,
  username    VARCHAR(100) NOT NULL UNIQUE,
  full_name   VARCHAR(255) NOT NULL,
  role        VARCHAR(20)  NOT NULL CHECK (role IN ('customer', 'seller', 'admin')),
  created_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- PostgreSQL : trigger BEFORE UPDATE (et non AFTER) pour pouvoir modifier NEW.
-- La fonction set_updated_at() est définie dans 001_extensions.sql.
CREATE TRIGGER trg_users_updated_at
  BEFORE UPDATE ON users
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
