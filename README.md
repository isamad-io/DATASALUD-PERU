# DataSalud Perú — Sistema integrado de base de datos para la gestión del MINSA

Proyecto final del curso **Base de Datos Avanzadas y Big Data (CIIN1021P)** — Grupo 06.

Sistema de vigilancia epidemiológica de **enfermedades zoonóticas** (Leptospirosis, Peste, Rabia, Ántrax, Ofidismo, Loxocelismo, entre otras) para la **DIRESA La Libertad**. Cubre todo el ciclo de datos: ingesta transaccional con validación y auditoría en SQL Server, seguridad conforme a la Ley N.° 29733, exploración NoSQL con MongoDB, Data Warehouse con modelo estrella, ETL en Python, dashboard en Power BI y análisis Big Data con Apache Spark.

## Integrantes

- Anthony Jeremy Marín Anticona
- Juan Diego Geronimo Temoche
- Cesar Manuel Antonio Viteri Vitteri
- Isamad Daniel Guzman Suarez
- Carlos Cristhian Mar Diaz Zamora

## Pregunta de gestión

> ¿Cuál es la carga de morbilidad y la distribución espacio-temporal de las enfermedades zoonóticas en La Libertad, y cómo se relaciona con la capacidad de los establecimientos de salud (IPRESS) para optimizar la asignación de recursos ante brotes?

## Arquitectura general

```
Datos abiertos MINSA + RENAES
        │
        ▼
 [02] SQL Server: staging + SP + triggers ──► AuditoriaLog
        │                 │
        │                 └─ [03] Roles, índices, backups (Ley 29733)
        │
        ├──► [04] MongoDB: historias clínicas (documentos anidados)
        │
        ▼
 [05] ETL (Python/pandas) ──► Modelo estrella (SQL Server / CSV)
        │
        ├──► [06] Power BI: 3 KPIs + drill-down OLAP
        └──► [07] Apache Spark (Colab): agregación masiva y benchmark
```

## Estructura del repositorio

| Carpeta | Contenido |
|---|---|
| `01_datos/RAW` | Datos originales: vigilancia de zoonosis 2000–2024 (CSV) y catálogo de establecimientos RENAES/SUSALUD (XLS). |
| `01_datos/PROCESSED` | Salidas limpias del ETL: `Dim_Tiempo`, `Dim_Ubicacion`, `Dim_Enfermedad`, `Dim_Establecimiento` y `Fact_Vigilancia`. |
| `02_automatizacion` | `script_01_automatizacion.sql` (BD, tablas, función, procedimientos y triggers) y script de prueba técnica. |
| `03_seguridad` | `script_02_seguridad_rendimiento.sql` (índice, roles, privilegios, backup y restore). |
| `04_nosql` | `script_03_mongodb_crud.js` (CRUD) y `atenciones_zoonosis_respaldo.json` (documento de ejemplo). |
| `05_dw_etl` | `07_DDL_DataWarehouse.sql` (DDL del DW) y `ETL/etl_pipeline1.py` con sus datos de entrada. |
| `06_dashboard` | `Power BI Proyecto.zip` con el archivo `.pbix` del dashboard. |
| `07_bigdata` | `NoteBookG6`: notebook de Google Colab con PySpark. |
| `08_documentacion` | Informe final (`Grupo06_CIIN1021P_EF.pdf`) y declaración de uso de IA. |

## Datasets

| Dataset | Fuente | Descarga |
|---|---|---|
| Vigilancia epidemiológica de las zoonosis (2000–2024), 128 084 registros | [Plataforma Nacional de Datos Abiertos del Perú](https://www.datosabiertos.gob.pe/dataset/vigilancia-epidemiol%C3%B3gica-de-las-zoonosis) (CDC-MINSA) | 14/09/2026 |
| Registro Nacional de IPRESS (catálogo de establecimientos, RENAES) | SUSALUD | 14/09/2026 |

## Componentes

### 1. Automatización y transacciones (`02_automatizacion`)

Base de datos `DataSalud_DB` en **SQL Server** con:

- **Tablas:** `Staging_Zoonosis` (ingesta) y `AuditoriaLog` (bitácora).
- **`fn_NormalizarTexto`:** pasa a mayúsculas, recorta espacios y reemplaza nulos por `NO ESPECIFICADO`.
- **`sp_IngestarLoteZoonosis`:** inserta un registro normalizado dentro de una transacción con `TRY/CATCH`; ante un error hace `ROLLBACK`, registra `ERROR_INGESTA` en el log y relanza el error.
- **`sp_LimpiarDuplicadosZoonosis`:** elimina duplicados exactos con CTE + `ROW_NUMBER()`.
- **`trg_ValidaIntegridadZoonosis`** (`INSTEAD OF INSERT`): bloquea registros con año futuro o edad negativa.
- **`trg_AuditoriaZoonosis`:** registra usuario, fecha y tipo de operación (inserción, actualización, eliminación).

**Prueba técnica** (`Script de Prueba Técnica.sql`): una ingesta válida (año 2024) que genera el log de éxito y una inválida (año 2035) que dispara el trigger y el `ROLLBACK`; luego se consulta `AuditoriaLog`.

### 2. Seguridad y rendimiento — Ley N.° 29733 (`03_seguridad`)

- Índice no clúster `IX_Staging_Zoonosis` sobre `(departamento, fecha_ingreso)`.
- Roles con segregación de funciones:

| Rol | Permisos |
|---|---|
| `Rol_Administrador` | `CONTROL` sobre la base de datos |
| `Rol_AnalistaDatos` | `SELECT`/`INSERT` en `Staging_Zoonosis`; acceso denegado a `AuditoriaLog` |
| `Rol_AuditorSeguridad` | `SELECT` en `AuditoriaLog`; acceso denegado a `Staging_Zoonosis` |

- Política de respaldo (full backup) y procedimiento de restauración.

### 3. NoSQL — MongoDB (`04_nosql`)

Base `DataSalud_NoSQL`, colección `atenciones_zoonosis`, con documentos anidados (paciente, detalles clínicos, síntomas, IPRESS notificante). El script ejecuta las operaciones **CREATE, READ y UPDATE** (el informe documenta la comparación SQL vs. NoSQL y la decisión arquitectónica).

### 4. Data Warehouse y ETL (`05_dw_etl`)

**Modelo estrella (metodología Kimball):**

- Tabla de hechos: `Fact_VigilanciaZoonosis`
- Dimensiones: `Dim_Tiempo`, `Dim_Ubicacion`, `Dim_Enfermedad`, `Dim_Establecimiento`
- `Dim_Establecimiento` incluye un registro neutro (`EstablecimientoKey = 0`) para casos sin IPRESS vinculada.

**Pipeline `etl_pipeline1.py` (pandas):**

1. **Extracción:** lee el CSV de zoonosis (`latin-1`).
2. **Transformación:** elimina duplicados, normaliza texto a mayúsculas, corrige caracteres corruptos, estandariza `ubigeo` a 6 dígitos, tipifica `ano`/`semana`/`edad` y calcula el trimestre.
3. **Carga:** genera los CSV de las dimensiones y la tabla de hechos, e intenta procesar el catálogo RENAES.

Resultado: 128 084 registros de entrada → ~125 696 tras quitar duplicados (2 388 filas, 1,86 %).

### 5. Dashboard — Power BI (`06_dashboard`)

Archivo `PROYECTO_BASE_DE_DATOS_KPIs_v5.pbix` (dentro de `Power BI Proyecto.zip`) con tres KPIs y drill-down por jerarquía territorial:

1. **Carga de morbilidad regional** (casos notificados).
2. **Concentración territorial por provincia** (%).
3. **Variación vs. trimestre anterior** (variación estacional).

### 6. Big Data — Apache Spark (`07_bigdata`)

Notebook de Google Colab (`NoteBookG6`) que carga el CSV como DataFrame de PySpark, crea la vista temporal `vista_zoonosis` y ejecuta una agregación por año, provincia y enfermedad con SparkSQL, midiendo el tiempo de ejecución (≈ 4,3 s sobre 128 084 registros). El informe lo compara con la misma consulta en SSMS.

## Requisitos

- **SQL Server** (2017 o superior, por `TRIM`) y SQL Server Management Studio
- **MongoDB** y `mongosh`
- **Python 3.9+** con `pandas` y, para leer el `.xls`, `xlrd`
- **Power BI Desktop**
- **Google Colab** (o PySpark local) para el notebook

## Cómo reproducir el proyecto

1. **Base transaccional:** ejecutar `02_automatizacion/script_01_automatizacion.sql` y luego `Script de Prueba Técnica.sql`.
2. **Seguridad:** ejecutar `03_seguridad/script_02_seguridad_rendimiento.sql` (ajustar la ruta `C:\Backups\` del backup).
3. **NoSQL:** ejecutar `04_nosql/script_03_mongodb_crud.js` con `mongosh`.
4. **Data Warehouse:** ejecutar `05_dw_etl/07_DDL_DataWarehouse.sql`.
5. **ETL:**
   ```bash
   cd 05_dw_etl/ETL
   pip install pandas xlrd
   python etl_pipeline1.py
   ```
   Genera los CSV de `Dim_*` y `Fact_Vigilancia_Limpia.csv` en la misma carpeta.
6. **Dashboard:** descomprimir `06_dashboard/Power BI Proyecto.zip`, abrir el `.pbix` y, si hace falta, actualizar las rutas de origen hacia `01_datos/PROCESSED`.
7. **Spark:** subir `NoteBookG6` a Colab, colocar el CSV en el entorno y ejecutar las celdas.

## Notas conocidas

- En `script_01_automatizacion.sql` el procedimiento `sp_IngestarLoteZoonosis` usa `ALTER PROCEDURE`; en una base nueva debe ser `CREATE PROCEDURE`.
- Algunos nombres con ñ aparecen corruptos en las dimensiones (por ejemplo `FERREÏ¿½AFE`), por la codificación del archivo fuente.
- El ETL exporta los CSV con claves naturales; las claves sustitutas (`*Key`) las asigna el DDL del Data Warehouse al cargar.

## Documentación

- Informe final: [`08_documentacion/Grupo06_CIIN1021P_EF.pdf`](08_documentacion/Grupo06_CIIN1021P_EF.pdf)
- Declaración de uso de Inteligencia Artificial (incluida en la misma carpeta).
# DATASALUD-PERU
# DATASALUD-PERU
