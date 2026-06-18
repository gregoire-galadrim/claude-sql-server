CREATE TABLE users (
  id          INT           NOT NULL IDENTITY(1, 1) PRIMARY KEY,
  email       NVARCHAR(255) NOT NULL UNIQUE,
  username    NVARCHAR(100) NOT NULL UNIQUE,
  full_name   NVARCHAR(255) NOT NULL,
  role        NVARCHAR(20)  NOT NULL CONSTRAINT ck_users_role CHECK (role IN ('customer', 'seller', 'admin')),
  created_at  DATETIME2     NOT NULL CONSTRAINT df_users_created_at DEFAULT SYSDATETIME(),
  updated_at  DATETIME2     NOT NULL CONSTRAINT df_users_updated_at DEFAULT SYSDATETIME()
);
GO

-- Équivalent de "ON UPDATE CURRENT_TIMESTAMP" (MySQL) : SQL Server ne propose pas
-- cette clause, on reproduit le comportement via un trigger AFTER UPDATE.
CREATE TRIGGER trg_users_updated_at ON users AFTER UPDATE AS
BEGIN
  SET NOCOUNT ON;
  UPDATE u SET updated_at = SYSDATETIME()
  FROM users u INNER JOIN inserted i ON u.id = i.id;
END;
GO
