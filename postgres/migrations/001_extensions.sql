-- Active pgcrypto pour gen_random_uuid() et md5() côté seed.
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Fonction partagée pour mettre à jour la colonne updated_at avant chaque UPDATE.
-- Équivalent des triggers AFTER UPDATE de SQL Server (qui utilisent la pseudo-table
-- `inserted`). En PostgreSQL, un trigger BEFORE UPDATE modifie NEW avant l'écriture.
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;
