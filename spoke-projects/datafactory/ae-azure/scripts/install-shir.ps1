param(
    [Parameter(Mandatory=$true)]    [string]    $irAuthKey1,
    [Parameter(Mandatory=$false)]   [string]    $name
)

function downloadFile {
    param(
        [Parameter(Mandatory=$true)]    [string]    $url,
        [Parameter(Mandatory=$true)]    [string]    $local
    )
    $wc = New-Object System.Net.WebClient
    try {
        $wc.DownloadFile($url, $local)
    } catch {
        throw "Failed to download file from $url to $local"
    }
}
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$me = [Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
if (-not $me.IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator"))
{
    Write-Warning "You do not have Administrator rights to run this script!`nPlease re-run this script as an Administrator!"
    exit 1
}
$pwshPath = "C:\Program Files\PowerShell\7\pwsh.exe"
$irPath = "C:\Program Files\Microsoft Integration Runtime\5.0\Shared\dmgcmd.exe"
if ((Test-Path $pwshPath) -eq $false) {
    $pwshRelease = Invoke-RestMethod "https://api.github.com/repos/PowerShell/PowerShell/releases/latest"
    $pwshAsset = $pwshRelease.assets | Where-Object { $_.name -match '^PowerShell-[\d.]+-win-x64\.msi$' } | Select-Object -First 1
    if (-not $pwshAsset) {
        throw "No PowerShell win-x64 MSI in GitHub latest release $($pwshRelease.tag_name)"
    }
    $pwshLocal = "$env:TEMP\$($pwshAsset.name)"
    $pwshMsiArgs=@(
        "/i `"$($pwshLocal)`"",
        "/quiet",
        "/log `"$env:TEMP\pwsh-install.log`"",
        "ADD_EXPLORER_CONTEXT_MENU_OPENPOWERSHELL=0",
        "ADD_FILE_CONTEXT_MENU_RUNPOWERSHELL=0",
        "ENABLE_PSREMOTING=0",
        "REGISTER_MANIFEST=1",
        "ADD_PATH=1"
    )
    downloadFile $pwshAsset.browser_download_url $pwshLocal
    $process = Start-Process "msiexec.exe" "$pwshMsiArgs" -Wait -PassThru
    if ($process.ExitCode -ne 0) {
        Write-Error "Failed to install PowerShell. msiexec exit code: $($process.ExitCode)"
        exit $process.ExitCode
    }
    Remove-Item $pwshLocal
} else {
    Write-Host "PowerShell already installed"
}

# If Az module is not installed, install it
$azInstalled = & $pwshPath -Command "Get-InstalledModule -Name Az.DataFactory -ErrorAction SilentlyContinue"
if (!$azInstalled) {
    Write-Host "Installing Az module..."
    & $pwshPath -Command "
        Install-Module -Name Az -AllowClobber -Scope AllUsers -Force
    "
    $azExit = $LastExitCode
    if($azExit) {
        Write-Error "Failed to install Az module. Exit code: $azExit"
        exit $azExit
    }
} else {
    Write-Host "Az module already installed."
}

# Install latest OpenJDK 11 for Parquet (https://learn.microsoft.com/en-us/java/openjdk/download-major-urls)
$openJdkJava = Get-ChildItem "C:\Program Files\Microsoft\jdk-11*\bin\java.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $openJdkJava) {
    Write-Host "Installing OpenJDK 11..."
    $jdkUrl = "https://aka.ms/download-jdk/microsoft-jdk-11-windows-x64.msi"
    $jdkLocal = "$env:TEMP\microsoft-jdk-11.msi"
    $jdkMsiArgs =@(
        "/i `"$jdkLocal`"",
        "/quiet",
        "/lv `"$env:TEMP\openjdk-install.log`"",
        "ADDLOCAL=`"FeatureMain,FeatureEnvironment,FeatureJarFileRunWith,FeatureJavaHome`"",
        "INSTALLDIR=`"C:\Program Files\Microsoft\`""
    )
    downloadFile $jdkUrl $jdkLocal
    $process = Start-Process "msiexec.exe" "$jdkMsiArgs" -NoNewWindow -Wait -PassThru
    if ($process.ExitCode -ne 0)
    {
        throw "Failed to install Microsoft openJDK. msiexec exit code: $($process.ExitCode)"
    }
    Remove-Item $jdkLocal
    Write-Host "OpenJDK 11 installed."
} else {
    Write-Host "OpenJDK 11 already installed."
}

# If dgcmd is not installed, install it
if ((Test-Path $irPath) -eq $false) {
    Write-Host "Installing Integration Runtime..."
    $irUrl = "https://go.microsoft.com/fwlink/?linkid=839822"
    $irLocal = "$env:TEMP\IntegrationRuntime.msi"
    downloadFile $irUrl $irLocal
    $irMsiArgs=@(
        "/i `"$($irLocal)`"",
        "/quiet",
        "/lv `"$env:TEMP\ir-install.log`""
    )
    $process = Start-Process "msiexec.exe" "$irMsiArgs" -Wait -PassThru
    if ($process.ExitCode -ne 0)
    {
        throw "Failed to install Microsoft Integration Runtime. msiexec exit code: $($process.ExitCode)"
    }
    Remove-Item $irLocal
    Write-Host "Integration Runtime installed."
} else {
    Write-Host "Integration Runtime already installed."
}

# Register IR with the factory. -k/-Key updates a key on an existing node; this VM is a new node.
Write-Host "Registering Integration Runtime..."
$nodeName = if ($name) { $name } else { $env:COMPUTERNAME }
$process = Start-Process -FilePath $irPath -ArgumentList @("-RegisterNewNode", $irAuthKey1, $nodeName) -Wait -PassThru -NoNewWindow
if ($process.ExitCode -ne 0) {
    throw "Failed to register Microsoft Integration Runtime. Exit code: $($process.ExitCode)"
}

#  dmgcmd [
#     -EnableLocalMachineAccess
#     -DisableLocalMachineAccess
#     -EnableLocalFolderPathValidation
#     -DisableLocalFolderPathValidation
#     -SetAdditionalConnectionStringPropertyAllowlist <allow list>
#     -GetAdditionalConnectionStringPropertyAllowlist
#     -EnableRemoteAccess "<port>" ["<thumbprint>"]
#     -EnableRemoteAccessInContainer "<port>" ["<thumbprint>"]
#     -DisableRemoteAccess -Key "<AuthenticationKey>"
#     -GenerateBackupFile "<filePath>" "<password>"
#     -ImportBackupFile "<filePath>" "<password>"
#     -SwitchServiceAccount "<domain\user>" ["password"]
#     -Loglevel <logLevel>
#     -EventLogVerboseSetting <On/Off>
#     -EnableExecuteSsisPackage
#     -DisableExecuteSsisPackage
#     -GetExecuteSsisPackage
#  ]

# Detail:
#     -EnableLocalMachineAccess               Enable access to localhost and private IP of the machine.
#     -DisableLocalMachineAccess              Disable access to localhost and private IP of the machine.
#     -EnableLocalFolderPathValidation        Enable validation against local folder paths of the machine.
#     -DisableLocalFolderPathValidation       Disable validation against local folder paths of the machine.
#     -SetAdditionalConnectionStringPropertyAllowlist <allow list>    Set additional connection string property allow list for ODBC drivers.

#     -GetAdditionalConnectionStringPropertyAllowlist Get additional connection string property allow list for ODBC drivers.
#     -EnableRemoteAccess "<port>" ["<thumbprint>"]   Enable remote access to current node from High Availability nodes and/or Credential Manager
#     -EnableRemoteAccessInContainer "<port>" ["<thumbprint>"]        Enable remote access to current node when the node is running in Container
#     -DisableRemoteAccess    Disable remote access to current node
#     -Key "<AuthenticationKey>"      Renew the Authentication Key

#     -GenerateBackupFile "<filePath>" "<password>"   Generate a backup file for current node, including the node authentication key and data store credentials
#     -ImportBackupFile "<filePath>" "<password>"     Restore the node from a backup file
#     -SwitchServiceAccount "<domain\user>" ["password"]      Set DIAHostService to run as a new account. Use empty password ("") for system account or virtual account.
#     -Loglevel <logLevel>    Set ETW log level (Off, Error, Verbose or All)
#     -EventLogVerboseSetting <On/Off>        Set Event Log Verbose level (Off, On)

#     -EnableExecuteSsisPackage       Enable SSIS package execution on local Self-hosted Integration Runtime machine.
#     -DisableExecuteSsisPackage      Disable SSIS package execution on local Self-hosted Integration Runtime machine.
#     -GetExecuteSsisPackage  Get the value if ExecuteSsisPackage is enabled on Self-hosted Integration Runtime machine.
