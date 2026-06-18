CREATE TABLE addresses (
  id           INT           NOT NULL IDENTITY(1, 1) PRIMARY KEY,
  user_id      INT           NOT NULL,
  street       NVARCHAR(255) NOT NULL,
  city         NVARCHAR(100) NOT NULL,
  postal_code  NVARCHAR(20)  NOT NULL,
  country      NVARCHAR(100) NOT NULL CONSTRAINT df_addresses_country DEFAULT N'France',
  is_default   BIT           NOT NULL CONSTRAINT df_addresses_is_default DEFAULT 0,
  created_at   DATETIME2     NOT NULL CONSTRAINT df_addresses_created_at DEFAULT SYSDATETIME(),
  CONSTRAINT fk_addresses_user FOREIGN KEY (user_id) REFERENCES users (id)
);
GO
