-- BLOQUE 2: SEGURIDAD, ROLES, ÍNDICES Y BACKUPS (LEY 29733)
-- 1. Crear el índice no clúster
CREATE NONCLUSTERED INDEX IX_Staging_Zoonosis 
ON Staging_Zoonosis (departamento, fecha_ingreso);
GO

-- 1.2. Ejecutar una búsqueda analítica para probar el índice
SELECT departamento, fecha_ingreso, enfermedad 
FROM Staging_Zoonosis 
WHERE departamento = 'La Libertad' AND fecha_ingreso >= '2024-01-01';
GO

-- 2. CREACIÓN DE ROLES DE SEGURIDAD
CREATE ROLE Rol_Administrador;
CREATE ROLE Rol_AnalistaDatos;
CREATE ROLE Rol_AuditorSeguridad;
GO

-- 3. ASIGNACIÓN DE PRIVILEGIOS (Segregación de funciones)
GRANT SELECT, INSERT ON Staging_Zoonosis TO Rol_AnalistaDatos;
DENY SELECT, INSERT, UPDATE, DELETE ON AuditoriaLog TO Rol_AnalistaDatos;

GRANT SELECT ON AuditoriaLog TO Rol_AuditorSeguridad;
DENY SELECT ON Staging_Zoonosis TO Rol_AuditorSeguridad;

GRANT CONTROL ON DATABASE::DataSalud_DB TO Rol_Administrador;
GO

-- 4. POLÍTICA DE RESPALDO Y RESTAURACIÓN
-- Script para generar un Respaldo Completo (Full Backup)
BACKUP DATABASE DataSalud_DB 
TO DISK = 'C:\Backups\DataSalud_DB_Full.bak' 
WITH FORMAT, INIT, NAME = 'Respaldo DataSalud';
GO

-- 2. Ejecutar Restauración (Restore)
USE master;
GO
ALTER DATABASE DataSalud_DB SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
GO
RESTORE DATABASE DataSalud_DB 
FROM DISK = 'C:\Backups\DataSalud_DB_Full.bak' 
WITH REPLACE;
GO
ALTER DATABASE DataSalud_DB SET MULTI_USER;
GO