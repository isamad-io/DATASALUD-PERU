import pandas as pd
print("======================================================")
print(" LOG DE EJECUCIÓN DEL SCRIPT PYTHON - PROCESO ETL LOCAL")
print("======================================================")

print("\n[Fase 1] Extracción de datos (Conteos de Entrada)")
archivo_csv = 'datos_abiertos_vigilancia_zoonosis_2000_2024.csv'
df_zoo = pd.read_csv(archivo_csv, encoding='latin-1', low_memory=False)

registros_entrada = len(df_zoo)
print(f"-> Registros leídos desde la fuente (MINSA): {registros_entrada}")

print("\n[Fase 2] Transformación, Normalización y Calidad de Datos")
df_clean = df_zoo.drop_duplicates().reset_index(drop=True)

duplicados = registros_entrada - len(df_clean)
print(f"-> Duplicados descartados: {duplicados}")

print("-> Ejecutando saneamiento de caracteres y estandarización territorial...")
df_clean['distrito'] = df_clean['distrito'].fillna('DESCONOCIDO').astype(str).str.strip().str.upper()
df_clean['localidad'] = df_clean['localidad'].fillna(df_clean['distrito']).astype(str).str.strip().str.upper()
df_clean['diagnostic'] = df_clean['diagnostic'].fillna('NO ESPECIFICADO').astype(str).str.strip().str.upper()

if 'ubigeo' in df_clean.columns:
    df_clean['ubigeo'] = df_clean['ubigeo'].astype(str).str.strip().str.replace(r'\.0$', '', regex=True).str.zfill(6)

columnas_texto = ['departamento', 'provincia', 'distrito', 'localidad', 'enfermedad', 'diagnostic', 'sexo', 'tipo_edad']
for col in columnas_texto:
    if col in df_clean.columns:
        df_clean[col] = df_clean[col].astype(str).str.strip().str.upper()
        df_clean[col] = df_clean[col].str.replace('ï¿½', 'Ñ', regex=False).str.replace('Ã\x91', 'Ñ', regex=False).str.replace('\ufffd', 'Ñ', regex=False)

# Garantizar tipos para cruzarlos luego en Power BI
df_clean['ano'] = pd.to_numeric(df_clean['ano'], errors='coerce').fillna(2000).astype(int)
df_clean['semana'] = pd.to_numeric(df_clean['semana'], errors='coerce').fillna(1).astype(int)
df_clean['edad'] = pd.to_numeric(df_clean['edad'], errors='coerce').fillna(0).astype(int)
df_clean['Trimestre'] = (((df_clean['semana'] - 1) // 13) + 1).clip(lower=1, upper=4)

print("\n[Fase 3] Generando Archivos Limpios (Modelo Estrella)")

# 1. Dimensión Tiempo
dim_tiempo = df_clean[['ano', 'semana', 'Trimestre']].drop_duplicates()
dim_tiempo.columns = ['Ano', 'Semana', 'Trimestre']
dim_tiempo.to_csv('Dim_Tiempo_Limpia.csv', index=False)
print(f"-> Guardado: Dim_Tiempo_Limpia.csv ({len(dim_tiempo)} registros)")

# 2. Dimensión Ubicación
dim_ubicacion = df_clean[['ubigeo', 'departamento', 'provincia', 'distrito', 'localidad']].drop_duplicates()
dim_ubicacion.columns = ['Ubigeo', 'Departamento', 'Provincia', 'Distrito', 'Localidad']
dim_ubicacion.to_csv('Dim_Ubicacion_Limpia.csv', index=False)
print(f"-> Guardado: Dim_Ubicacion_Limpia.csv ({len(dim_ubicacion)} registros)")

# 3. Dimensión Enfermedad
dim_enfermedad = df_clean[['enfermedad', 'diagnostic']].drop_duplicates()
dim_enfermedad.columns = ['Enfermedad', 'Diagnostico']
dim_enfermedad.to_csv('Dim_Enfermedad_Limpia.csv', index=False)
print(f"-> Guardado: Dim_Enfermedad_Limpia.csv ({len(dim_enfermedad)} registros)")

# 4. Tabla de Hechos (Fact_VigilanciaZoonosis)
fact_zoonosis = df_clean[['ano', 'semana', 'ubigeo', 'localidad', 'enfermedad', 'diagnostic', 'edad', 'tipo_edad', 'sexo']].copy()
fact_zoonosis['CantidadCasos'] = 1
fact_zoonosis.to_csv('Fact_Vigilancia_Limpia.csv', index=False)

registros_salida = len(fact_zoonosis)
print(f"-> Guardado: Fact_Vigilancia_Limpia.csv ({registros_salida} registros insertados)")

# (Opcional) Exportar RENAES Limpio si decides usarlo en PowerBI
try:
    df_est = pd.read_excel('USLRC20260909215543_xp.xls', sheet_name=0)
    df_est.to_csv('Dim_Establecimiento_Limpia.csv', index=False)
    print("-> Guardado: Dim_Establecimiento_Limpia.csv")
except Exception as e:
    print("-> No se procesó RENAES (archivo no encontrado).")

print("\n======================================================")
print(" ¡PROCESO ETL COMPLETADO CON ÉXITO!")
print("======================================================")