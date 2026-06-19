CREATE TABLE payments (
  id               SERIAL         NOT NULL PRIMARY KEY,
  order_id         INT            NOT NULL REFERENCES orders (id),
  amount           NUMERIC(10, 2) NOT NULL,
  method           VARCHAR(30)    NOT NULL CHECK (
                     method IN ('credit_card', 'paypal', 'bank_transfer', 'crypto')
                   ),
  status           VARCHAR(20)    NOT NULL CHECK (
                     status IN ('pending', 'completed', 'failed', 'refunded')
                   ),
  transaction_ref  VARCHAR(255)   NULL,
  created_at       TIMESTAMPTZ    NOT NULL DEFAULT NOW()
);
