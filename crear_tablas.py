
from pathlib import Path
from getpass import getpass
import mysql.connector

# Buscamos el archivo SQL en la carpeta del proyecto
carpeta = Path(__file__).resolve().parent
archivo_sql = carpeta / "01_crear_tablas.sql"

# Pedimos la contraseña y nos conectamos
contrasena = getpass("Contraseña de MySQL: ")

conexion = mysql.connector.connect(
    host="localhost",
    port=3306,
    user="root",
    password=contrasena
)

cursor = conexion.cursor(buffered=True)

# Leemos el archivo que contiene las tablas
sql = archivo_sql.read_text(encoding="utf-8-sig")

# Ejecutamos las instrucciones SQL
for instruccion in sql.split(";"):
    instruccion = instruccion.strip()

    if instruccion:
        cursor.execute(instruccion)

# Comprobamos qué tablas se crearon
cursor.execute("SHOW TABLES FROM staychain")

print("\nTablas encontradas:")
for tabla in cursor:
    print(tabla[0])

# Cerramos la conexión
cursor.close()
conexion.close()

print("\nProceso finalizado correctamente.")