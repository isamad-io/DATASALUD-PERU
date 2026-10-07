-- 1. Inserción VÁLIDA (Para generar el Log de "Operación ejecutada exitosamente")
EXEC sp_IngestarLoteZoonosis 
    @departamento='La Libertad', @provincia='Trujillo', @distrito='Trujillo', 
    @localidad='Centro', @enfermedad='Leptospirosis', 
    @ano=2024, @semana=12, @diagnostic='Confirmado', -- Año 2024 (Correcto)
    @diresa='Diresa La Libertad', @ubigeo='130101', 
    @localcod='001', @edad=28, @tipo_edad='A', @sexo='M';

-- 2. Inserción INVÁLIDA (Para generar el "ERROR_INGESTA" con el año 2035)
-- Esto activará el Trigger trg_ValidaIntegridadZoonosis y hará el ROLLBACK
EXEC sp_IngestarLoteZoonosis 
    @departamento='La Libertad', @provincia='Trujillo', @distrito='Trujillo', 
    @localidad='Centro', @enfermedad='Leptospirosis', 
    @ano=2035, @semana=12, @diagnostic='Confirmado', 
    @diresa='Diresa La Libertad', @ubigeo='130101', 
    @localcod='001', @edad=28, @tipo_edad='A', @sexo='M';

-- 3. Comprobación de la tabla.
SELECT * FROM AuditoriaLog;
