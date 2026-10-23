[CmdletBinding()]
param(
    [ValidatePattern("^(?:[01]\d|2[0-3]):[0-5]\d$")]
    [string]$Hora = "02:00",
    [string]$NombreTarea = "StayChain-DW - Carga diaria",
    [string]$MySqlHost = "localhost",
    [ValidateRange(1, 65535)]
    [int]$MySqlPort = 3306,
    [string]$MySqlUser = "root",
    [string]$MySqlDatabase = "staychain"
)

$ErrorActionPreference = "Stop"
$projectDir = $PSScriptRoot
$runnerPath = Join-Path $projectDir "ejecutar_carga.ps1"

if (-not (Test-Path -LiteralPath $runnerPath -PathType Leaf)) {
    throw "Falta ejecutar_carga.ps1 en $projectDir."
}
if (-not (Test-Path -LiteralPath (Join-Path $projectDir "cargar_dw.py") -PathType Leaf)) {
    throw "Falta cargar_dw.py en $projectDir."
}

$venvPython = Join-Path $projectDir ".venv\Scripts\python.exe"
$pythonFound = (Test-Path -LiteralPath $venvPython -PathType Leaf) -or
    ($null -ne (Get-Command py.exe -ErrorAction SilentlyContinue)) -or
    ($null -ne (Get-Command python.exe -ErrorAction SilentlyContinue))
if (-not $pythonFound) {
    throw "No se encontró Python 3. Instálelo o cree .venv antes de continuar."
}

$credential = Get-Credential -UserName $MySqlUser -Message "Credencial local de MySQL para StayChain-DW"
if ($null -eq $credential) { throw "No se proporcionó la credencial MySQL." }
if ($credential.UserName -ne $MySqlUser) {
    throw "El usuario ingresado no coincide con -MySqlUser ($MySqlUser)."
}

$credentialDir = Join-Path $projectDir "credenciales"
New-Item -ItemType Directory -Path $credentialDir -Force | Out-Null
$credentialPath = Join-Path $credentialDir "mysql.credential.xml"
$credential | Export-Clixml -LiteralPath $credentialPath -Force

$config = [ordered]@{
    mysql_host = $MySqlHost
    mysql_port = $MySqlPort
    mysql_user = $MySqlUser
    mysql_database = $MySqlDatabase
}
$config | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $projectDir "config.local.json") -Encoding utf8

$escapedRunner = $runnerPath.Replace('"', '\"')
$actionArgs = "-NoProfile -NonInteractive -ExecutionPolicy Bypass -File `"$escapedRunner`""
$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument $actionArgs -WorkingDirectory $projectDir
$at = [datetime]::Today.Add([timespan]::ParseExact($Hora, "hh\:mm", $null))
$trigger = New-ScheduledTaskTrigger -Daily -At $at
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -MultipleInstances IgnoreNew
$principal = New-ScheduledTaskPrincipal -UserId ([System.Security.Principal.WindowsIdentity]::GetCurrent().Name) -LogonType Interactive -RunLevel Limited

Register-ScheduledTask -TaskName $NombreTarea -Action $action -Trigger $trigger `
    -Settings $settings -Principal $principal -Description "Carga diaria del Data Warehouse StayChain" -Force | Out-Null

Write-Host "Tarea '$NombreTarea' registrada para las $Hora."
Write-Host "Se ejecutará con el usuario actual mientras tenga una sesión iniciada."
Write-Host "Registro: $(Join-Path $projectDir 'logs\staychain_dw.log')"
