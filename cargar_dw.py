
from pathlib import Path
from getpass import getpass
import csv
import os
import sys
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

# En una ejecución automática, el lanzador coloca la contraseña descifrada
# solamente en el entorno de este proceso. En una ejecución manual se pide
# de forma interactiva, como antes.
contrasena = os.environ.get("STAYCHAIN_MYSQL_PASSWORD")
if contrasena is None:
    if not sys.stdin.isatty():
        print(
            "Error: no hay una contraseña MySQL disponible y la ejecución "
            "no es interactiva.",
            file=sys.stderr,
        )
        sys.exit(2)
    contrasena = getpass("Contraseña de MySQL: ")

conexion = None
cursor = None

try:
    conexion = mysql.connector.connect(
        host=os.environ.get("STAYCHAIN_MYSQL_HOST", "localhost"),
        port=int(os.environ.get("STAYCHAIN_MYSQL_PORT", "3306")),
        user=os.environ.get("STAYCHAIN_MYSQL_USER", "root"),
        password=contrasena,
        database=os.environ.get("STAYCHAIN_MYSQL_DATABASE", "staychain"),
    )
    cursor = conexion.cursor()

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
    if conexion is not None and conexion.is_connected():
        conexion.rollback()
    print(f"\nError durante la carga: {error}")
    print("Se cancelaron las inserciones de esta ejecución.")
    sys.exit(1)

finally:
    if cursor is not None:
        cursor.close()
    if conexion is not None and conexion.is_connected():
        conexion.close()

