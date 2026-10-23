[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$projectDir = $PSScriptRoot
$configPath = Join-Path $projectDir "config.local.json"
$credentialPath = Join-Path $projectDir "credenciales\mysql.credential.xml"
$logDir = Join-Path $projectDir "logs"

function Stop-WithError([string]$Message, [int]$Code = 1) {
    $line = "{0} ERROR: {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Message
    if (Test-Path -LiteralPath $logDir) {
        $line | Out-File -LiteralPath (Join-Path $logDir "staychain_dw.log") -Append -Encoding utf8
    }
    Write-Error $Message
    exit $Code
}

if (-not (Test-Path -LiteralPath $configPath -PathType Leaf)) {
    Stop-WithError "Falta config.local.json. Ejecute configurar_tarea.ps1 primero."
}
if (-not (Test-Path -LiteralPath $credentialPath -PathType Leaf)) {
    Stop-WithError "Falta la credencial MySQL cifrada. Ejecute configurar_tarea.ps1 primero."
}
if (-not (Test-Path -LiteralPath (Join-Path $projectDir "cargar_dw.py") -PathType Leaf)) {
    Stop-WithError "No se encontro cargar_dw.py en $projectDir."
}

New-Item -ItemType Directory -Path $logDir -Force | Out-Null

try {
    $config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
    foreach ($property in @("mysql_host", "mysql_port", "mysql_user", "mysql_database")) {
        if ($null -eq $config.$property -or [string]::IsNullOrWhiteSpace([string]$config.$property)) {
            throw "La propiedad '$property' falta en config.local.json."
        }
    }
    $credential = Import-Clixml -LiteralPath $credentialPath
    if ($credential -isnot [System.Management.Automation.PSCredential]) {
        throw "El archivo de credencial no contiene una credencial valida."
    }
    if ($credential.UserName -ne $config.mysql_user) {
        throw "El usuario de la credencial no coincide con mysql_user."
    }
} catch {
    Stop-WithError "No se pudo leer la configuracion local: $($_.Exception.Message)"
}

$pythonExe = $null
$pythonArgs = @()
$venvPython = Join-Path $projectDir ".venv\Scripts\python.exe"
if (Test-Path -LiteralPath $venvPython -PathType Leaf) {
    $pythonExe = $venvPython
} else {
    $py = Get-Command py.exe -ErrorAction SilentlyContinue
    if ($null -ne $py) {
        $pythonExe = $py.Source
        $pythonArgs = @("-3")
    } else {
        $python = Get-Command python.exe -ErrorAction SilentlyContinue
        if ($null -ne $python) { $pythonExe = $python.Source }
    }
}
if ($null -eq $pythonExe) {
    Stop-WithError "No se encontro Python 3 ni .venv\Scripts\python.exe."
}

$logPath = Join-Path $logDir "staychain_dw.log"
$passwordPointer = [IntPtr]::Zero
try {
    $passwordPointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($credential.Password)
    $env:STAYCHAIN_MYSQL_PASSWORD = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($passwordPointer)
    $env:STAYCHAIN_MYSQL_HOST = [string]$config.mysql_host
    $env:STAYCHAIN_MYSQL_PORT = [string]$config.mysql_port
    $env:STAYCHAIN_MYSQL_USER = [string]$config.mysql_user
    $env:STAYCHAIN_MYSQL_DATABASE = [string]$config.mysql_database

    "`r`n{0} INICIO de carga" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss") |
        Out-File -LiteralPath $logPath -Append -Encoding utf8
    # PowerShell 5.1 usa UTF-16 al redirigir con *>>. Convertimos la salida a
    # texto y la escribimos explicitamente como UTF-8 para no mezclar formatos.
    & $pythonExe @pythonArgs (Join-Path $projectDir "cargar_dw.py") 2>&1 |
        Out-File -LiteralPath $logPath -Append -Encoding utf8
    $exitCode = $LASTEXITCODE
    "{0} FIN de carga (codigo {1})" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $exitCode |
        Out-File -LiteralPath $logPath -Append -Encoding utf8
    exit $exitCode
} catch {
    Stop-WithError "No se pudo ejecutar la carga: $($_.Exception.Message)"
} finally {
    Remove-Item Env:\STAYCHAIN_MYSQL_PASSWORD -ErrorAction SilentlyContinue
    if ($passwordPointer -ne [IntPtr]::Zero) {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($passwordPointer)
    }
}
