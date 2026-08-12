param(
    [Parameter(Mandatory=$true)]
    [string]$WindowsUser,

    [Parameter(Mandatory=$true)]
    [string]$WindowsHost,

    [switch]$InstallDockerDesktop,
    [switch]$CreateFirewallRule
)

function Show-Usage {
    Write-Host "Usage: .\setup-windows-docker.ps1 -WindowsUser <username> -WindowsHost <hostname-or-ip> [-InstallDockerDesktop] [-CreateFirewallRule]"
    Write-Host "Example: .\setup-windows-docker.ps1 -WindowsUser Dell -WindowsHost winpc.local -InstallDockerDesktop -CreateFirewallRule"
}

if ($WindowsUser -match '[<>]' -or $WindowsHost -match '[<>]') {
    Write-Error "Placeholders must be replaced with actual values. Do not include '<' or '>' characters."
    Show-Usage
    exit 1
}

function Assert-Administrator {
    if (-not ([bool](New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))) {
        Write-Error "This script must be run as Administrator. Restart PowerShell with 'Run as administrator'."
        exit 1
    }
}

function Ensure-OpenSshServer {
    Write-Host "Checking OpenSSH Server..."
    $sshCap = Get-WindowsCapability -Online | Where-Object { $_.Name -like 'OpenSSH.Server*' }

    if ($sshCap -and $sshCap.State -eq 'Installed') {
        Write-Host "OpenSSH Server is already installed."
    } else {
        Write-Host "Installing OpenSSH Server..."
        Add-WindowsCapability -Online -Name 'OpenSSH.Server~~~~0.0.1.0' | Out-Null
    }

    Write-Host "Configuring SSH service..."
    Set-Service -Name sshd -StartupType Automatic
    Start-Service -Name sshd

    if ($CreateFirewallRule) {
        Write-Host "Ensuring firewall rule for SSH port 22 exists..."
        $ruleExists = (Get-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -ErrorAction SilentlyContinue) -or (Get-NetFirewallRule -DisplayName 'OpenSSH-Server-In-TCP' -ErrorAction SilentlyContinue)
        if (-not $ruleExists) {
            New-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -DisplayName 'OpenSSH-Server-In-TCP' -Enabled True -Direction Inbound -Protocol TCP -LocalPort 22 -Action Allow
        } else {
            Write-Host "Firewall rule already exists."
        }
    }
}

function Install-DockerDesktop {
    Write-Host "Installing Docker Desktop for Windows via winget..."
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Error "winget is not available. Install Windows Package Manager first."
        exit 1
    }

    winget install --id Docker.DockerDesktop --silent --accept-package-agreements --accept-source-agreements
}

function Ensure-DockerEngine {
    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
        Write-Warning "Docker CLI is not available in PATH. Ensure Docker Desktop has been installed and the shell is restarted."
    }
    else {
        Write-Host "Docker CLI is available: $(docker --version)"
    }
}

function Add-DockerUserGroup {
    try {
        if (Get-Command Add-LocalGroupMember -ErrorAction SilentlyContinue) {
            $existingMember = Get-LocalGroupMember -Group docker-users -ErrorAction SilentlyContinue | Where-Object {
                $_.Name -eq $WindowsUser -or $_.Name.EndsWith("\\$WindowsUser")
            }
            if (-not $existingMember) {
                Add-LocalGroupMember -Group docker-users -Member $WindowsUser -ErrorAction Stop
                Write-Host "Added $WindowsUser to docker-users group."
            } else {
                Write-Host "$WindowsUser is already in docker-users group."
            }
            return
        }

        $group = [ADSI]"WinNT://./docker-users,group"
        $user = [ADSI]"WinNT://./$WindowsUser,user"
        $group.Add($user.Path) | Out-Null
        Write-Host "Added $WindowsUser to docker-users group."
    } catch {
        if ($_.Exception.Message -match 'already a member') {
            Write-Host "$WindowsUser is already in docker-users group."
        } else {
            Write-Warning "Could not add $WindowsUser to docker-users group: $_"
        }
    }
}

Assert-Administrator

if ($InstallDockerDesktop) {
    Install-DockerDesktop
}

Ensure-OpenSshServer
Add-DockerUserGroup
Ensure-DockerEngine

Write-Host ""
Write-Host "Windows setup complete. Use the following SSH address from your Mac:"
Write-Host "  $WindowsUser@$WindowsHost"
Write-Host ""
Write-Host "On the Mac, run the remote setup script and pass that address as the argument."
Write-Host "Example: ./setup-mac-remote-docker.sh $WindowsUser@$WindowsHost"
