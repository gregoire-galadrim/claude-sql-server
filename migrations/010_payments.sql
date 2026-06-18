CREATE TABLE payments (
  id               INT            NOT NULL IDENTITY(1, 1) PRIMARY KEY,
  order_id         INT            NOT NULL,
  amount           DECIMAL(10, 2) NOT NULL,
  method           NVARCHAR(30)   NOT NULL CONSTRAINT ck_payments_method CHECK (
                     method IN ('credit_card', 'paypal', 'bank_transfer', 'crypto')
                   ),
  status           NVARCHAR(20)   NOT NULL CONSTRAINT ck_payments_status CHECK (
                     status IN ('pending', 'completed', 'failed', 'refunded')
                   ),
  transaction_ref  NVARCHAR(255)  NULL,
  created_at       DATETIME2      NOT NULL CONSTRAINT df_payments_created_at DEFAULT SYSDATETIME(),
  CONSTRAINT fk_payments_order FOREIGN KEY (order_id) REFERENCES orders (id)
);
GO
