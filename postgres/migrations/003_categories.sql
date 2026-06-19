CREATE TABLE categories (
  id          SERIAL       NOT NULL PRIMARY KEY,
  name        VARCHAR(100) NOT NULL,
  slug        VARCHAR(100) NOT NULL UNIQUE,
  parent_id   INT          NULL REFERENCES categories (id),
  created_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);
