
from pathlib import Path
from getpass import getpass
import csv
import mysql.connector

# Ubicación de los archivos CSV
CARPETA = Path(__file__).resolve().parent
CARPETA_CSV = CARPETA / "csv"

# Primero cargamos dimensiones y después tablas de hechos
TABLAS = [
    "DIM_HOTEL",
    "DIM_HABITACION",
    "DIM_CANAL",
    "DIM_CLIENTE",
    "DIM_TEMPORADA",
    "DIM_FECHA",
    "FACT_RESERVA",
    "FACT_CANCELACION"
]

# Columnas booleanas que requieren conversión
BOOLEANOS = {
    "DIM_CLIENTE": {"es_recurrente"},
    "DIM_FECHA": {"es_fin_semana", "es_feriado"},
    "FACT_RESERVA": {"is_cancelada"}
}

# Conexión a MySQL
contrasena = getpass("Contraseña de MySQL: ")

conexion = mysql.connector.connect(
    host="localhost",
    port=3306,
    user="root",
    password=contrasena,
    database="staychain"
)

cursor = conexion.cursor()

try:
    for tabla in TABLAS:

        archivo = CARPETA_CSV / f"{tabla}.csv"
        print(f"\nProcesando {archivo.name}...")

        with open(archivo, "r", encoding="utf-8-sig", newline="") as f:
            lector = csv.DictReader(f)
            columnas = lector.fieldnames

            if not columnas:
                raise ValueError(f"El archivo {archivo.name} no tiene columnas")

            # Consulta para insertar sin modificar registros existentes
            nombres = ", ".join(f"`{col}`" for col in columnas)
            parametros = ", ".join(["%s"] * len(columnas))

            consulta = (
                f"INSERT INTO `{tabla}` "
                f"({nombres}) VALUES ({parametros}) "
                "ON DUPLICATE KEY UPDATE "
                f"`{columnas[0]}` = `{columnas[0]}`"
            )

            datos = []

            # Leer y preparar los registros
            for fila in lector:
                valores = []

                for columna in columnas:
                    valor = fila[columna]

                    # Convertir booleanos de texto a números
                    if columna in BOOLEANOS.get(tabla, set()):
                        if valor.lower() == "true":
                            valor = 1
                        elif valor.lower() == "false":
                            valor = 0
                        else:
                            raise ValueError(
                                f"Booleano inválido en {tabla}.{columna}: {valor}"
                            )

                    valores.append(valor)

                datos.append(tuple(valores))

        # Contar registros antes de insertar
        cursor.execute(f"SELECT COUNT(*) FROM `{tabla}`")
        cantidad_antes = cursor.fetchone()[0]

        # Insertar los registros
        if datos:
            cursor.executemany(consulta, datos)

        # Contar registros después de insertar
        cursor.execute(f"SELECT COUNT(*) FROM `{tabla}`")
        cantidad_despues = cursor.fetchone()[0]

        nuevos = cantidad_despues - cantidad_antes

        print(f"Registros nuevos insertados: {nuevos}")

    # Confirmar todas las inserciones
    conexion.commit()
    print("\nCarga finalizada correctamente.")

except Exception as error:
    conexion.rollback()
    print(f"\nError durante la carga: {error}")
    print("Se cancelaron las inserciones de esta ejecución.")

finally:
    cursor.close()
    conexion.close()

