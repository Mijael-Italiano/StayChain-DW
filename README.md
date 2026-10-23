# StayChain-DW: carga automática en Windows

Este prototipo ejecuta `cargar_dw.py` una vez por día mediante el Programador de tareas de Windows. Conserva la lógica existente de carga incremental: no cambia los CSV, las tablas ni los datos históricos.

## Requisitos

- Windows 10 u 11 con PowerShell 5.1 o posterior.
- Python 3 disponible mediante `py`, `python` o un entorno `.venv` dentro del proyecto.
- MySQL en funcionamiento, con la base `staychain` y sus tablas ya creadas.
- Permiso del usuario actual para crear una tarea programada.

## Preparación

Abra PowerShell en la carpeta del proyecto y, de forma recomendada, cree un entorno virtual:

```powershell
py -3 -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
```

Si no usa un entorno virtual:

```powershell
py -3 -m pip install -r requirements.txt
```

La ejecución manual continúa solicitando la contraseña sin mostrarla:

```powershell
py -3 .\cargar_dw.py
```

## Instalar la tarea

El siguiente comando solicita la contraseña de MySQL y programa la carga diaria a las 02:00:

```powershell
.\configurar_tarea.ps1
```

Para elegir otro horario o datos de conexión:

```powershell
.\configurar_tarea.ps1 -Hora "21:30" -MySqlHost "localhost" -MySqlPort 3306 -MySqlUser "root" -MySqlDatabase "staychain"
```

El horario debe usar el formato `HH:mm`. El script detecta la carpeta del proyecto y Python automáticamente. Registrar de nuevo la tarea actualiza su configuración.

La tarea usa el usuario actual y se ejecuta cuando ese usuario tiene una sesión iniciada. Esto evita guardar la contraseña de Windows en el Programador de tareas y resulta adecuado para una demostración portable.

## Credenciales y archivos locales

La contraseña MySQL se guarda en `credenciales/mysql.credential.xml`, cifrada mediante DPAPI para el usuario de Windows que ejecutó el instalador. No es reutilizable por otro usuario ni, normalmente, en otra computadora. Durante la carga se descifra sólo en memoria y no se imprime en el registro.

`config.local.json`, `credenciales/` y `logs/` están excluidos por `.gitignore`. No copie el archivo de credencial: en otra computadora, vuelva a ejecutar el instalador.

## Probar y verificar

Después de instalar, puede probar el mismo lanzador que usa la tarea:

```powershell
.\ejecutar_carga.ps1
```

O iniciar la tarea desde Windows:

```powershell
Start-ScheduledTask -TaskName "StayChain-DW - Carga diaria"
```

Consulte el resultado en:

```text
logs\staychain_dw.log
```

También puede revisar el estado sin ejecutarla:

```powershell
Get-ScheduledTask -TaskName "StayChain-DW - Carga diaria" | Get-ScheduledTaskInfo
```

Un código final `0` indica éxito. Si faltan Python, la configuración, la credencial o el script de carga, el lanzador registra un error claro y termina con código distinto de cero.

## Desinstalar

Para quitar solamente la tarea y conservar configuración, credencial y registros:

```powershell
.\desinstalar_tarea.ps1
```

Para quitar también la configuración y la credencial locales (los registros se conservan):

```powershell
.\desinstalar_tarea.ps1 -EliminarConfiguracionLocal
```

Estos comandos no borran CSV, tablas MySQL ni datos históricos.

## Política de ejecución

Si Windows bloquea los scripts, habilítelos sólo para esa ventana de PowerShell y vuelva a ejecutar el comando deseado:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```
