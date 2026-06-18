-- Création de la base applicative. À exécuter en premier, sur la base `master`.
-- (Les migrations 001+ supposent que la base `test` existe et qu'on y est connecté.)
IF DB_ID('test') IS NULL
  CREATE DATABASE test;
GO
