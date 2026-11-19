# Run this script in PowerShell
# Auto-elevates to Administrator if run as a standard user.

# --- AUTO-ELEVATION BLOCK ---
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Not running as Administrator. Elevating..." -ForegroundColor Yellow
    $processInfo = New-Object System.Diagnostics.ProcessStartInfo
    $processInfo.FileName = "powershell.exe"
    $processInfo.Arguments = "-File `"$($MyInvocation.MyCommand.Path)`""
    $processInfo.Verb = "RunAs"
    $process = [System.Diagnostics.Process]::Start($processInfo)
    exit
}

# Explanation
Write-Host "----------------------------------------------------------------" -ForegroundColor Cyan
Write-Host "                       EXPLANATION                              " -ForegroundColor Cyan
Write-Host "----------------------------------------------------------------" -ForegroundColor Cyan
Write-Host "This script disables NVIDIA's 'nvtopps' plugin, which is loaded by the"
Write-Host "NVIDIA Display Container (NVDisplay.ContainerLocalSystem) service."
Write-Host ""
Write-Host "The plugin runs the NVIDIA-NVTOPPS-FILTER ETW trace session, which"
Write-Host "monitors processes in the background. It has been linked to periodic"
Write-Host "stutter, DPC latency spikes, and extra CPU usage on some systems."
Write-Host ""
Write-Host "NOTE: For NVIDIA GPU systems only. NVIDIA driver updates may" -ForegroundColor Yellow
Write-Host "recreate the registry key, so re-run this script after updating." -ForegroundColor Yellow
Write-Host ""
Write-Host "Actions:"
Write-Host "1. logman stop NVIDIA-NVTOPPS-FILTER -ets"
Write-Host "2. Set DisableLoad = 1 under:"
Write-Host "   HKLM:\SYSTEM\CurrentControlSet\Services\NVDisplay.ContainerLocalSystem\Parameters\LocalSystem_nvtopps"
Write-Host "----------------------------------------------------------------" -ForegroundColor Cyan

# Pause for user to read
Write-Host "Press any key to apply this tweak (or Ctrl+C to cancel)..." -ForegroundColor Yellow
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

# Logic
$serviceKey = "HKLM:\SYSTEM\CurrentControlSet\Services\NVDisplay.ContainerLocalSystem"
if (-not (Test-Path $serviceKey)) {
    Write-Warning "NVIDIA Display Container service not found. This tweak only applies to systems with NVIDIA drivers installed."
    Write-Host "Press any key to exit..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit
}

# 1. Stop the running ETW trace session
Write-Host "Stopping NVIDIA-NVTOPPS-FILTER trace session..." -ForegroundColor White
$output1 = cmd /c "logman stop NVIDIA-NVTOPPS-FILTER -ets 2>&1"
if ($LASTEXITCODE -eq 0) {
    Write-Host "Successfully stopped 'NVIDIA-NVTOPPS-FILTER'." -ForegroundColor Green
} elseif ($output1 -match "not found|does not exist") {
    Write-Host "'NVIDIA-NVTOPPS-FILTER' is not running." -ForegroundColor Green
} else {
    Write-Warning "Failed to stop 'NVIDIA-NVTOPPS-FILTER': $output1"
}

# 2. Prevent the plugin from loading on next service start
Write-Host "Disabling nvtopps plugin load..." -ForegroundColor White
try {
    $pluginKey = "$serviceKey\Parameters\LocalSystem_nvtopps"
    New-Item -Path $pluginKey -Force -ErrorAction Stop | Out-Null
    New-ItemProperty -Path $pluginKey -Name "DisableLoad" -PropertyType DWord -Value 1 -Force -ErrorAction Stop | Out-Null
    Write-Host "Successfully set 'DisableLoad' to 1." -ForegroundColor Green
} catch {
    Write-Warning "Failed to set 'DisableLoad': $_"
}

Write-Host "You may need to restart your computer for changes to take effect." -ForegroundColor White -BackgroundColor DarkGreen
Write-Host "Press any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
