[CmdletBinding()]
param(
    [string]$NombreTarea = "StayChain-DW - Carga diaria",
    [switch]$EliminarConfiguracionLocal
)

$ErrorActionPreference = "Stop"
$task = Get-ScheduledTask -TaskName $NombreTarea -ErrorAction SilentlyContinue
if ($null -ne $task) {
    Unregister-ScheduledTask -TaskName $NombreTarea -Confirm:$false
    Write-Host "Tarea '$NombreTarea' eliminada."
} else {
    Write-Host "La tarea '$NombreTarea' no existe; no hay nada que eliminar."
}

if ($EliminarConfiguracionLocal) {
    $targets = @(
        (Join-Path $PSScriptRoot "config.local.json"),
        (Join-Path $PSScriptRoot "credenciales\mysql.credential.xml")
    )
    foreach ($target in $targets) {
        if (Test-Path -LiteralPath $target -PathType Leaf) {
            Remove-Item -LiteralPath $target -Force
        }
    }
    Write-Host "Configuración y credencial locales eliminadas. Los registros se conservaron."
}
