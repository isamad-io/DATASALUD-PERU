-- BLOQUE 1: AUTOMATIZACIÓN Y TRANSACCIONES (DATASALUD PERÚ)
-- 1. CREACIÓN DE LA BASE DE DATOS
CREATE DATABASE DataSalud_DB;
GO
USE DataSalud_DB;
GO

-- 2. CREACIÓN DE TABLAS TRANSACCIONALES
CREATE TABLE Staging_Zoonosis (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    departamento VARCHAR(100),
    provincia VARCHAR(100),
    distrito VARCHAR(100),
    localidad VARCHAR(150),
    enfermedad VARCHAR(100),
    ano INT,
    semana INT,
    diagnostic VARCHAR(100),
    diresa VARCHAR(100),
    ubigeo VARCHAR(10),
    localcod VARCHAR(20),
    edad INT,
    tipo_edad VARCHAR(20),
    sexo VARCHAR(20),
    fecha_ingreso DATETIME DEFAULT GETDATE()
);
GO

CREATE TABLE AuditoriaLog (
    LogID INT IDENTITY(1,1) PRIMARY KEY,
    TablaOrigen VARCHAR(100),
    Operacion VARCHAR(50),
    Usuario VARCHAR(100),
    Timestamp DATETIME DEFAULT GETDATE(),
    MensajeEstado VARCHAR(255)
);
GO

-- 3. FUNCIÓN DE LIMPIEZA
CREATE FUNCTION fn_NormalizarTexto (@Texto VARCHAR(150))
RETURNS VARCHAR(150)
AS
BEGIN
    RETURN UPPER(TRIM(ISNULL(@Texto, 'NO ESPECIFICADO')));
END;
GO

-- 4. PROCEDIMIENTO ALMACENADO (Ingesta con Control de Errores)
ALTER PROCEDURE sp_IngestarLoteZoonosis
    @departamento VARCHAR(100), @provincia VARCHAR(100), @distrito VARCHAR(100),
    @localidad VARCHAR(150), @enfermedad VARCHAR(100), @ano INT,
    @semana INT, @diagnostic VARCHAR(100), @diresa VARCHAR(100),
    @ubigeo VARCHAR(10), @localcod VARCHAR(20), @edad INT,
    @tipo_edad VARCHAR(20), @sexo VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
            INSERT INTO Staging_Zoonosis (
                departamento, provincia, distrito, localidad, enfermedad, 
                ano, semana, diagnostic, diresa, ubigeo, localcod, edad, tipo_edad, sexo
            )
            VALUES (
                dbo.fn_NormalizarTexto(@departamento), dbo.fn_NormalizarTexto(@provincia), 
                dbo.fn_NormalizarTexto(@distrito), dbo.fn_NormalizarTexto(@localidad), 
                dbo.fn_NormalizarTexto(@enfermedad), @ano, @semana, 
                dbo.fn_NormalizarTexto(@diagnostic), dbo.fn_NormalizarTexto(@diresa), 
                @ubigeo, @localcod, @edad, @tipo_edad, UPPER(@sexo)
            );
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        
        -- Guarda el error en la tabla
        INSERT INTO AuditoriaLog (TablaOrigen, Operacion, Usuario, MensajeEstado)
        VALUES ('Staging_Zoonosis', 'ERROR_INGESTA', SUSER_NAME(), ERROR_MESSAGE());
        
        -- ¡Esta línea obliga a SQL Server a mostrar las letras rojas en consola!
        THROW; 
    END CATCH
END;
GO

-- 4.1 PROCEDIMIENTO ALMACENADO (Limpieza Analítica de Duplicados)
CREATE PROCEDURE sp_LimpiarDuplicadosZoonosis
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
            
            -- Usamos CTE (Common Table Expression) y ROW_NUMBER para aislar los duplicados exactos
            WITH CTE_Duplicados AS (
                SELECT 
                    Id,
                    ROW_NUMBER() OVER (
                        PARTITION BY 
                            departamento, provincia, distrito, localidad, enfermedad, 
                            ano, semana, diagnostic, diresa, ubigeo, localcod, edad, tipo_edad, sexo
                        ORDER BY Id
                    ) AS FilaNum
                FROM Staging_Zoonosis
            )
            -- Eliminamos cualquier fila que sea la copia (FilaNum > 1), conservando la original
            DELETE FROM CTE_Duplicados WHERE FilaNum > 1;

        COMMIT TRANSACTION;
        
        -- Auditoría de la limpieza
        INSERT INTO AuditoriaLog (TablaOrigen, Operacion, Usuario, MensajeEstado)
        VALUES ('Staging_Zoonosis', 'DEDUPLICACIÓN', SUSER_NAME(), 'Se eliminaron registros duplicados analíticos con éxito.');

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
            
        INSERT INTO AuditoriaLog (TablaOrigen, Operacion, Usuario, MensajeEstado)
        VALUES ('Staging_Zoonosis', 'ERROR_DEDUPLICACION', SUSER_NAME(), ERROR_MESSAGE());
    END CATCH
END;
GO

-- 5. TRIGGER DE INTEGRIDAD (Bloqueo de Inconsistencias)
CREATE TRIGGER trg_ValidaIntegridadZoonosis
ON Staging_Zoonosis
INSTEAD OF INSERT
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM inserted WHERE ano > YEAR(GETDATE()) OR edad < 0)
    BEGIN
        RAISERROR('Error de Integridad: Se intentó insertar un registro con año futuro o edad negativa.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END
    INSERT INTO Staging_Zoonosis (departamento, provincia, distrito, localidad, enfermedad, ano, semana, diagnostic, diresa, ubigeo, localcod, edad, tipo_edad, sexo, fecha_ingreso)
    SELECT departamento, provincia, distrito, localidad, enfermedad, ano, semana, diagnostic, diresa, ubigeo, localcod, edad, tipo_edad, sexo, ISNULL(fecha_ingreso, GETDATE())
    FROM inserted;
END;
GO

-- 6. TRIGGER DE AUDITORÍA LEGAL
CREATE TRIGGER trg_AuditoriaZoonosis
ON Staging_Zoonosis
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Operacion VARCHAR(50) = 'MODIFICACIÓN NO IDENTIFICADA';
    
    IF EXISTS (SELECT * FROM inserted) AND NOT EXISTS (SELECT * FROM deleted)
        SET @Operacion = 'INSERCIÓN EXITOSA';
    ELSE IF EXISTS (SELECT * FROM inserted) AND EXISTS (SELECT * FROM deleted)
        SET @Operacion = 'ACTUALIZACIÓN';
    ELSE IF NOT EXISTS (SELECT * FROM inserted) AND EXISTS (SELECT * FROM deleted)
        SET @Operacion = 'ELIMINACIÓN';

    INSERT INTO AuditoriaLog (TablaOrigen, Operacion, Usuario, MensajeEstado)
    VALUES ('Staging_Zoonosis', @Operacion, SUSER_NAME(), 'Operación ejecutada con éxito sobre la tabla.');
END;
GO  
