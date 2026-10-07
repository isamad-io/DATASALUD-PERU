USE DataSalud_DB;
GO

-- 1. Dimensión Tiempo
IF OBJECT_ID('Dim_Tiempo', 'U') IS NOT NULL DROP TABLE Dim_Tiempo;
CREATE TABLE Dim_Tiempo (
    TiempoKey INT IDENTITY(1,1) PRIMARY KEY,
    Ano INT NOT NULL,
    Semana INT NOT NULL,
    Trimestre INT NOT NULL
);
GO

-- 2. Dimensión Ubicación
IF OBJECT_ID('Dim_Ubicacion', 'U') IS NOT NULL DROP TABLE Dim_Ubicacion;
CREATE TABLE Dim_Ubicacion (
    UbicacionKey INT IDENTITY(1,1) PRIMARY KEY,
    Ubigeo VARCHAR(10) NOT NULL,
    Departamento VARCHAR(100) NOT NULL,
    Provincia VARCHAR(100) NOT NULL,
    Distrito VARCHAR(100) NOT NULL,
    Localidad VARCHAR(150) NOT NULL
);
GO

-- 3. Dimensión Enfermedad
IF OBJECT_ID('Dim_Enfermedad', 'U') IS NOT NULL DROP TABLE Dim_Enfermedad;
CREATE TABLE Dim_Enfermedad (
    EnfermedadKey INT IDENTITY(1,1) PRIMARY KEY,
    Enfermedad VARCHAR(100) NOT NULL,
    Diagnostico VARCHAR(100) NOT NULL
);
GO

-- 4. Dimensión Establecimiento (Catálogo Maestro RENAES)
-- Se configuran longitudes amplias (VARCHAR 500/300) para prevenir errores de truncamiento de texto
IF OBJECT_ID('Dim_Establecimiento', 'U') IS NOT NULL DROP TABLE Dim_Establecimiento;
CREATE TABLE Dim_Establecimiento (
    EstablecimientoKey INT IDENTITY(1,1) PRIMARY KEY,
    CodigoUnico VARCHAR(20) NOT NULL,
    NombreEstablecimiento VARCHAR(500) NOT NULL,
    Clasificacion VARCHAR(500),
    TipoEstablecimiento VARCHAR(500),
    Institucion VARCHAR(100),
    Ubigeo VARCHAR(10),
    Departamento VARCHAR(100),
    Provincia VARCHAR(100),
    Distrito VARCHAR(100),
    DISA VARCHAR(100),
    Red VARCHAR(300),
    Microrred VARCHAR(300),
    Categoria VARCHAR(20),
    Estado VARCHAR(50)
);
GO

-- Registro neutro por defecto (EstablecimientoKey = 0) para eventos epidemiológicos sin IPRESS vinculada
SET IDENTITY_INSERT Dim_Establecimiento ON;
INSERT INTO Dim_Establecimiento (
    EstablecimientoKey, CodigoUnico, NombreEstablecimiento, Clasificacion, 
    TipoEstablecimiento, Institucion, Ubigeo, Departamento, Provincia, Distrito, 
    DISA, Red, Microrred, Categoria, Estado
) VALUES (
    0, '00000', 'NO ESPECIFICADO / DOMICILIARIO', 'NO APLICA', 
    'SIN INTERNAMIENTO', 'MINSA', '000000', 'DESCONOCIDO', 'DESCONOCIDO', 'DESCONOCIDO',
    'DESCONOCIDO', 'DESCONOCIDO', 'DESCONOCIDO', 'S/C', 'ACTIVO'
);
SET IDENTITY_INSERT Dim_Establecimiento OFF;
GO

-- 5. Tabla de Hechos: Vigilancia Zoonosis
IF OBJECT_ID('Fact_VigilanciaZoonosis', 'U') IS NOT NULL DROP TABLE Fact_VigilanciaZoonosis;
CREATE TABLE Fact_VigilanciaZoonosis (
    FactKey BIGINT IDENTITY(1,1) PRIMARY KEY,
    TiempoKey INT NOT NULL FOREIGN KEY REFERENCES Dim_Tiempo(TiempoKey),
    UbicacionKey INT NOT NULL FOREIGN KEY REFERENCES Dim_Ubicacion(UbicacionKey),
    EnfermedadKey INT NOT NULL FOREIGN KEY REFERENCES Dim_Enfermedad(EnfermedadKey),
    EstablecimientoKey INT NOT NULL DEFAULT 0 FOREIGN KEY REFERENCES Dim_Establecimiento(EstablecimientoKey),
    Edad INT,
    TipoEdad VARCHAR(20),
    Sexo VARCHAR(20),
    CantidadCasos INT DEFAULT 1,
    FechaCarga DATETIME DEFAULT GETDATE()
);
GO