[CmdletBinding()]
param(
    [switch]$Full,
    [switch]$Quick,
    [string]$OutputPath = ".",
    [switch]$MemoryDump,
    [switch]$VerboseMode,
    [string]$ToolsPath = "$PSScriptRoot/tools"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-UtcTimestamp {
    (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
}

$RunId = (Get-Date).ToUniversalTime().ToString("yyyyMMdd_HHmmss")
$RootOutput = Join-Path $OutputPath ("DFIR_" + $env:COMPUTERNAME + "_" + $RunId)
$Directories = @(
    "system",
    "network",
    "memory",
    "logs",
    "persistence",
    "users",
    "timeline",
    "security",
    "filesystem",
    "integrity"
)

New-Item -Path $RootOutput -ItemType Directory -Force | Out-Null
foreach ($dir in $Directories) {
    New-Item -Path (Join-Path $RootOutput $dir) -ItemType Directory -Force | Out-Null
}

$LogFile = Join-Path $RootOutput "execution.log"
$CommandLog = Join-Path $RootOutput "commands.log"

function Write-Log {
    param(
        [ValidateSet('INFO', 'WARNING', 'ERROR')]
        [string]$Level,
        [string]$Message
    )
    $line = "$(Get-UtcTimestamp) [$Level] $Message"
    Add-Content -Path $LogFile -Value $line
    if ($VerboseMode) {
        Write-Host $line
    }
}

function Invoke-CommandCapture {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,
        [Parameter(Mandatory = $true)]
        [scriptblock]$Action,
        [Parameter(Mandatory = $true)]
        [string]$OutFile
    )

    try {
        $cmdLine = $Action.ToString()
        Add-Content -Path $CommandLog -Value "$(Get-UtcTimestamp) | $Name | $cmdLine"
        $result = & $Action 2>&1 | Out-String
        Set-Content -Path $OutFile -Value $result -Encoding UTF8
        Write-Log -Level INFO -Message "$Name collected to $OutFile"
    }
    catch {
        Write-Log -Level ERROR -Message "$Name failed: $($_.Exception.Message)"
        Set-Content -Path $OutFile -Value "ERROR: $($_.Exception.Message)" -Encoding UTF8
    }
}

function Invoke-ExternalIfPresent {
    param(
        [string]$ToolPath,
        [string]$Arguments,
        [string]$OutFile,
        [string]$Name
    )
    if (Test-Path $ToolPath) {
        Invoke-CommandCapture -Name $Name -OutFile $OutFile -Action {
            & $ToolPath $Arguments
        }
    }
    else {
        Write-Log -Level WARNING -Message "$Name skipped: tool not found at $ToolPath"
    }
}

function Export-EventLogSafe {
    param(
        [string]$LogName,
        [string]$OutputEvtx,
        [string]$OutputTxt
    )
    try {
        wevtutil epl $LogName $OutputEvtx /ow:true
        Write-Log -Level INFO -Message "EVTX exported: $LogName"
    }
    catch {
        Write-Log -Level ERROR -Message "EVTX export failed for $LogName: $($_.Exception.Message)"
    }

    Invoke-CommandCapture -Name "Get-WinEvent-$LogName" -OutFile $OutputTxt -Action {
        Get-WinEvent -LogName $LogName -MaxEvents 500 | Select-Object TimeCreated, Id, LevelDisplayName, ProviderName, Message
    }
}

function Write-Timeline {
    $timelineCsv = Join-Path $RootOutput "timeline\filesystem_timeline.csv"
    try {
        Get-ChildItem -Path C:\ -Recurse -Force -ErrorAction SilentlyContinue |
            Select-Object FullName, CreationTimeUtc, LastWriteTimeUtc, LastAccessTimeUtc, Length |
            Export-Csv -Path $timelineCsv -NoTypeInformation -Encoding UTF8
        Write-Log -Level INFO -Message "Filesystem timeline generated"
    }
    catch {
        Write-Log -Level ERROR -Message "Timeline generation failed: $($_.Exception.Message)"
    }
}

function Write-Integrity {
    $hashFile = Join-Path $RootOutput "integrity\sha256_manifest.csv"
    $scriptHashFile = Join-Path $RootOutput "integrity\script_hash.txt"

    try {
        Get-ChildItem -Path $RootOutput -File -Recurse |
            Get-FileHash -Algorithm SHA256 |
            Select-Object Path, Algorithm, Hash |
            Export-Csv -Path $hashFile -NoTypeInformation -Encoding UTF8
        Write-Log -Level INFO -Message "SHA256 manifest generated"
    }
    catch {
        Write-Log -Level ERROR -Message "SHA256 manifest failed: $($_.Exception.Message)"
    }

    try {
        Get-FileHash -Path $PSCommandPath -Algorithm SHA256 |
            Format-List | Out-File -FilePath $scriptHashFile -Encoding UTF8
        Write-Log -Level INFO -Message "Script hash generated"
    }
    catch {
        Write-Log -Level ERROR -Message "Script hash generation failed: $($_.Exception.Message)"
    }
}

function Collect-System {
    Write-Log -Level INFO -Message "Collecting system data"
    Invoke-CommandCapture -Name "ComputerInfo" -OutFile (Join-Path $RootOutput "system\computer_info.txt") -Action { Get-ComputerInfo }
    Invoke-CommandCapture -Name "SystemInfo" -OutFile (Join-Path $RootOutput "system\systeminfo.txt") -Action { systeminfo }
    Invoke-CommandCapture -Name "BIOS" -OutFile (Join-Path $RootOutput "system\bios.txt") -Action { Get-CimInstance Win32_BIOS }
    Invoke-CommandCapture -Name "Environment" -OutFile (Join-Path $RootOutput "system\environment.txt") -Action { Get-ChildItem Env: }
}

function Collect-Processes {
    Write-Log -Level INFO -Message "Collecting process data"
    Invoke-CommandCapture -Name "Processes" -OutFile (Join-Path $RootOutput "system\processes.csv") -Action {
        Get-CimInstance Win32_Process |
            Select-Object ProcessId, ParentProcessId, Name, CreationDate, CommandLine, ExecutablePath |
            Export-Csv -Path (Join-Path $RootOutput "system\processes_raw.csv") -NoTypeInformation -Encoding UTF8
        Get-Content (Join-Path $RootOutput "system\processes_raw.csv")
    }
    Invoke-CommandCapture -Name "ProcessTree" -OutFile (Join-Path $RootOutput "system\process_tree.txt") -Action {
        Get-CimInstance Win32_Process | Sort-Object ParentProcessId, ProcessId | Format-Table ProcessId, ParentProcessId, Name, CommandLine -AutoSize
    }

    $sigcheckPath = Join-Path $ToolsPath "sigcheck.exe"
    if (Test-Path $sigcheckPath) {
        Invoke-CommandCapture -Name "SigcheckRunningProcesses" -OutFile (Join-Path $RootOutput "system\sigcheck_processes.txt") -Action {
            & $sigcheckPath -accepteula -u -e -c
        }
    }
    else {
        Write-Log -Level WARNING -Message "sigcheck.exe not found, process signature check skipped"
    }
}

function Collect-Network {
    Write-Log -Level INFO -Message "Collecting network data"
    Invoke-CommandCapture -Name "Netstat" -OutFile (Join-Path $RootOutput "network\netstat_ano.txt") -Action { netstat -ano }
    Invoke-CommandCapture -Name "IPConfig" -OutFile (Join-Path $RootOutput "network\ipconfig_all.txt") -Action { ipconfig /all }
    Invoke-CommandCapture -Name "ARP" -OutFile (Join-Path $RootOutput "network\arp_a.txt") -Action { arp -a }
    Invoke-CommandCapture -Name "DNSCache" -OutFile (Join-Path $RootOutput "network\dns_cache.txt") -Action { ipconfig /displaydns }
    Invoke-CommandCapture -Name "RoutePrint" -OutFile (Join-Path $RootOutput "network\route_print.txt") -Action { route print }
}

function Collect-Persistence {
    Write-Log -Level INFO -Message "Collecting persistence data"
    Invoke-CommandCapture -Name "ScheduledTasks" -OutFile (Join-Path $RootOutput "persistence\scheduled_tasks.txt") -Action { schtasks /query /fo LIST /v }
    Invoke-CommandCapture -Name "Services" -OutFile (Join-Path $RootOutput "persistence\services.txt") -Action { Get-Service | Sort-Object Status, Name }
    Invoke-CommandCapture -Name "RunKeys-HKLM" -OutFile (Join-Path $RootOutput "persistence\run_hklm.txt") -Action { reg query "HKLM\Software\Microsoft\Windows\CurrentVersion\Run" }
    Invoke-CommandCapture -Name "RunKeys-HKCU" -OutFile (Join-Path $RootOutput "persistence\run_hkcu.txt") -Action { reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" }
    Invoke-CommandCapture -Name "WMI-Subscriptions" -OutFile (Join-Path $RootOutput "persistence\wmi_subscriptions.txt") -Action {
        Get-WmiObject -Namespace root\subscription -Class __EventFilter
        Get-WmiObject -Namespace root\subscription -Class CommandLineEventConsumer
        Get-WmiObject -Namespace root\subscription -Class __FilterToConsumerBinding
    }

    $autorunsPath = Join-Path $ToolsPath "Autoruns64.exe"
    if (Test-Path $autorunsPath) {
        Invoke-CommandCapture -Name "Autoruns" -OutFile (Join-Path $RootOutput "persistence\autoruns.csv") -Action {
            & $autorunsPath /accepteula /nobanner /a * /c
        }
    }
    else {
        Write-Log -Level WARNING -Message "Autoruns64.exe not found, autoruns collection skipped"
    }
}

function Collect-Users {
    Write-Log -Level INFO -Message "Collecting user/session data"
    Invoke-CommandCapture -Name "LocalUsers" -OutFile (Join-Path $RootOutput "users\local_users.txt") -Action { net user }
    Invoke-CommandCapture -Name "LocalGroups" -OutFile (Join-Path $RootOutput "users\local_groups.txt") -Action { net localgroup }
    Invoke-CommandCapture -Name "WhoAmI" -OutFile (Join-Path $RootOutput "users\whoami_all.txt") -Action { whoami /all }
    Invoke-CommandCapture -Name "Sessions" -OutFile (Join-Path $RootOutput "users\sessions.txt") -Action { quser }
    Invoke-CommandCapture -Name "LoggedOnUsers" -OutFile (Join-Path $RootOutput "users\loggedon_users.txt") -Action { query user }
}

function Collect-Logs {
    Write-Log -Level INFO -Message "Collecting logs"
    Export-EventLogSafe -LogName "Security" -OutputEvtx (Join-Path $RootOutput "logs\Security.evtx") -OutputTxt (Join-Path $RootOutput "logs\Security_recent.txt")
    Export-EventLogSafe -LogName "System" -OutputEvtx (Join-Path $RootOutput "logs\System.evtx") -OutputTxt (Join-Path $RootOutput "logs\System_recent.txt")
    Export-EventLogSafe -LogName "Application" -OutputEvtx (Join-Path $RootOutput "logs\Application.evtx") -OutputTxt (Join-Path $RootOutput "logs\Application_recent.txt")
    Export-EventLogSafe -LogName "Windows PowerShell" -OutputEvtx (Join-Path $RootOutput "logs\WindowsPowerShell.evtx") -OutputTxt (Join-Path $RootOutput "logs\WindowsPowerShell_recent.txt")
}

function Collect-FileSystemArtifacts {
    Write-Log -Level INFO -Message "Collecting filesystem artifacts"
    Invoke-CommandCapture -Name "RecentFiles" -OutFile (Join-Path $RootOutput "filesystem\recent_files.txt") -Action {
        Get-ChildItem "$env:APPDATA\Microsoft\Windows\Recent" -Force -ErrorAction SilentlyContinue
    }
    Invoke-CommandCapture -Name "TempFiles" -OutFile (Join-Path $RootOutput "filesystem\temp_files.txt") -Action {
        Get-ChildItem "$env:TEMP" -Force -ErrorAction SilentlyContinue
    }
    Invoke-CommandCapture -Name "Prefetch" -OutFile (Join-Path $RootOutput "filesystem\prefetch.txt") -Action {
        Get-ChildItem "C:\Windows\Prefetch" -Force -ErrorAction SilentlyContinue
    }
    Invoke-CommandCapture -Name "RecycleBin" -OutFile (Join-Path $RootOutput "filesystem\recycle_bin.txt") -Action {
        Get-ChildItem "C:\$Recycle.Bin" -Force -Recurse -ErrorAction SilentlyContinue
    }
    Invoke-CommandCapture -Name "LNKFiles" -OutFile (Join-Path $RootOutput "filesystem\lnk_files.txt") -Action {
        Get-ChildItem "C:\Users" -Filter *.lnk -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Collect-Security {
    Write-Log -Level INFO -Message "Collecting security posture"
    Invoke-CommandCapture -Name "DefenderStatus" -OutFile (Join-Path $RootOutput "security\defender_status.txt") -Action { Get-MpComputerStatus }
    Invoke-CommandCapture -Name "FirewallRules" -OutFile (Join-Path $RootOutput "security\firewall_rules.txt") -Action { netsh advfirewall firewall show rule name=all }
    Invoke-CommandCapture -Name "AVProducts" -OutFile (Join-Path $RootOutput "security\av_products.txt") -Action {
        Get-CimInstance -Namespace root/SecurityCenter2 -ClassName AntivirusProduct
    }
}

function Collect-Memory {
    if (-not $MemoryDump) {
        Write-Log -Level INFO -Message "Memory collection skipped"
        return
    }

    Write-Log -Level INFO -Message "Collecting memory artifacts"
    Invoke-CommandCapture -Name "LoadedModules" -OutFile (Join-Path $RootOutput "memory\loaded_modules.txt") -Action {
        Get-Process | Select-Object ProcessName, Id, Path, Modules
    }

    $procdumpPath = Join-Path $ToolsPath "procdump64.exe"
    if (Test-Path $procdumpPath) {
        $dumpTarget = Join-Path $RootOutput "memory\lsass.dmp"
        Invoke-CommandCapture -Name "ProcDump-LSASS" -OutFile (Join-Path $RootOutput "memory\memory_dump_status.txt") -Action {
            & $procdumpPath -accepteula -ma lsass.exe $dumpTarget
        }
    }
    else {
        Write-Log -Level WARNING -Message "procdump64.exe not found, dump skipped"
    }
}

function Write-Summary {
    $summary = [ordered]@{
        RunId = $RunId
        Hostname = $env:COMPUTERNAME
        UTCCompleted = Get-UtcTimestamp
        FullMode = [bool]$Full
        QuickMode = [bool]$Quick
        MemoryDump = [bool]$MemoryDump
        OutputRoot = $RootOutput
    }
    $summary | ConvertTo-Json | Set-Content -Path (Join-Path $RootOutput "summary.json") -Encoding UTF8
    Write-Host "DFIR collection complete. Output: $RootOutput"
}

Write-Log -Level INFO -Message "DFIR collection started"

Collect-System
Collect-Processes
Collect-Network
Collect-Persistence
Collect-Users
Collect-Logs
Collect-FileSystemArtifacts
Collect-Security

if ($Full -or (-not $Quick)) {
    Write-Timeline
}
else {
    Write-Log -Level INFO -Message "Quick mode enabled: timeline skipped"
}

Collect-Memory
Write-Integrity
Write-Summary
Write-Log -Level INFO -Message "DFIR collection completed"
