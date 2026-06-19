CREATE TABLE addresses (
  id           SERIAL       NOT NULL PRIMARY KEY,
  user_id      INT          NOT NULL REFERENCES users (id),
  street       VARCHAR(255) NOT NULL,
  city         VARCHAR(100) NOT NULL,
  postal_code  VARCHAR(20)  NOT NULL,
  country      VARCHAR(100) NOT NULL DEFAULT 'France',
  is_default   BOOLEAN      NOT NULL DEFAULT FALSE,
  created_at   TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);
