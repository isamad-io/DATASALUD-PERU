// BLOQUE 3: EXPLORACIÓN NOSQL - HISTORIAS CLÍNICAS (MONGODB)
// 1. Seleccionar o crear la base de datos
use DataSalud_NoSQL;

// 2. CREATE (Inserción de un documento JSON complejo y anidado)
db.atenciones_zoonosis.insertOne({
    "codigo_atencion": "AT-2026-002",
    "fecha_registro": new Date("2026-09-23T09:15:00Z"),
    "paciente": {
        "edad": 42,
        "sexo": "M",
        "distrito": "LAREDO",
        "provincia": "TRUJILLO"
    },
    "enfermedad": "LEPTOSPIROSIS",
    "clasificacion": "CONFIRMADO",
    "detalles_clinicos": {
        "exposicion": "Aguas estancadas en acequia de regadío",
        "severidad": "Moderada",
        "sintomas": [
            "Mialgias intensas",
            "Inyección conjuntival",
            "Ictericia leve"
        ],
        "requiere_hospitalizacion": false
    },
    "estado_paciente": "En monitoreo",
    "ipress_notificante": {
        "codigo_renaes": "0000033041",
        "nombre": "PUESTO DE SALUD LAREDO"
    }
});

// 3. READ (Lectura analítica buscando por nivel de severidad)
db.atenciones_zoonosis.find({
    "detalles_clinicos.severidad": "Moderada"
});

// 4. UPDATE (Actualización de la evolución clínica)
db.atenciones_zoonosis.updateOne(
    { "codigo_atencion": "AT-2026-002" },
    { 
        $set: { 
            "estado_paciente": "Favorable en monitoreo ambulatorio",
            "tratamiento": "Doxiciclina 100mg cada 12h por 7 días"
        }
    }
);

// 5. READ (Verificar actualización)
db.atenciones_zoonosis.find({ "codigo_atencion": "AT-2026-002" });