# SFTP Connection Details
$sftpHost = "<Secret>"
$sftpPort = 22
$sftpUsername = "<Secret>"
$sftpPassword = "<Secret>"

# Local Directory
$localDirectory = "C:\TempTest"

# Timestamp File
$timestampFile = "$localDirectory\Timestamps\last_run_timestamp.txt"

# Validate local directory
if (!(Test-Path -Path $localDirectory -PathType Container)) {
    Write-Error "Local directory '$localDirectory' does not exist."
    exit 1
}

# Create the directory for the timestamp file if it doesn't exist
$timestampFileDirectory = Split-Path -Path $timestampFile -Parent
if (!(Test-Path -Path $timestampFileDirectory -PathType Container)) {
    try {
        New-Item -ItemType Directory -Path $timestampFileDirectory | Out-Null
        Write-Host "Created directory '$timestampFileDirectory' for timestamp file."
    }
    catch {
        Write-Error "Failed to create directory '$timestampFileDirectory' for timestamp file. Error: $($_.Exception.Message)"
        exit 1
    }
}

# Load WinSCP .NET assembly
$winscpAssembly = "C:\Program Files\WinSCP\WinSCPnet.dll"
if (Test-Path $winscpAssembly) {
    Add-Type -Path $winscpAssembly
}
else {
    Write-Error "WinSCP .NET assembly not found. Please install WinSCP and update the path in the script."
    exit 1
}

# Set up session options
$sessionOptions = New-Object WinSCP.SessionOptions -Property @{
    Protocol = [WinSCP.Protocol]::Sftp
    HostName = $sftpHost
    PortNumber = $sftpPort
    UserName = $sftpUsername
    Password = $sftpPassword
    GiveUpSecurityAndAcceptAnySshHostKey = $true
}

$session = New-Object WinSCP.Session

try {
    # Create the directory for session log if it doesn't exist
    $sessionLogDirectory = Split-Path -Path "$localDirectory\Sessions\session.log" -Parent
    if (!(Test-Path -Path $sessionLogDirectory -PathType Container)) {
        try {
            New-Item -ItemType Directory -Path $sessionLogDirectory | Out-Null
            Write-Host "Created directory '$sessionLogDirectory' for session log."
        }
        catch {
            Write-Error "Failed to create directory '$sessionLogDirectory' for session log. Error: $($_.Exception.Message)"
            exit 1
        }
    }

    # Enable session resuming
    $session.SessionLogPath = "$localDirectory\Sessions\session.log"

    # Connect to SFTP server
    try {
        $session.Open($sessionOptions)
        Write-Host "Connected to SFTP server '$sftpHost'."
    }
    catch {
        Write-Error "Failed to connect to SFTP server '$sftpHost'. Error: $($_.Exception.Message)"
        exit 1
    }

    # Get the last run timestamp from the file, or use a default value if the file doesn't exist
    if (Test-Path $timestampFile) {
        $lastRunTimestamp = Get-Content $timestampFile | Select-Object -First 1
        if ($lastRunTimestamp -match "^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$") {
            $timestampFilter = [DateTime]::ParseExact($lastRunTimestamp, "yyyy-MM-dd HH:mm:ss", $null)
            Write-Host "Last run timestamp: $lastRunTimestamp"
        }
        else {
            Write-Warning "Invalid timestamp format in file '$timestampFile'. Using default timestamp of 1 day ago."
            $timestampFilter = (Get-Date).AddDays(-1)
        }
    }
    else {
        Write-Host "Timestamp file '$timestampFile' does not exist. Using default timestamp of 1 day ago."
        $timestampFilter = (Get-Date).AddDays(-1)
    }

    # Get the list of files in the SFTP directory modified since the last run
    $remoteFiles = $session.ListDirectory("/In").Files | Where-Object { $_.LastWriteTime -ge $timestampFilter }

    if ($remoteFiles.Count -eq 0) {
        Write-Host "No new files found in the SFTP directory since the last run."
    }
    else {
        Write-Host "Found $($remoteFiles.Count) new file(s) in the SFTP directory since the last run."

        # Get the list of files in the local directory
        $localFiles = Get-ChildItem -Path $localDirectory -File

        # Filter and download new files
        $downloadedCount = 0
        foreach ($remoteFile in $remoteFiles) {
            $localFile = $localFiles | Where-Object { $_.Name -eq $remoteFile.Name }
            if ($null -eq $localFile) {
                try {
                    $session.GetFileToDirectory($remoteFile.FullName, $localDirectory, $False, $transferOptions)
                    Write-Host "Downloaded: $($remoteFile.Name)"
                    $downloadedCount++
                }
                catch {
                    Write-Error "Failed to download file '$($remoteFile.FullName)'. Error: $($_.Exception.Message)"
                }
            }
        }

        Write-Host "Downloaded $downloadedCount new file(s) from the SFTP directory."
    }

    # Update the last run timestamp in the file
    $currentTimestamp = Get-Date
    try {
        $currentTimestamp.ToString("yyyy-MM-dd HH:mm:ss") | Out-File -FilePath $timestampFile -Force
        Write-Host "Updated last run timestamp in file '$timestampFile'."
    }
    catch {
        Write-Error "Failed to update last run timestamp in file '$timestampFile'. Error: $($_.Exception.Message)"
    }
}
catch {
    Write-Error "An error occurred: $($_.Exception.Message)"
    exit 1
}
finally {
    # Disconnect and dispose of the SFTP session
    if ($null -eq $session) {
        try {
            $session.Dispose()
            Write-Host "Disconnected from SFTP server '$sftpHost'."
        }
        catch {
            Write-Error "Failed to dispose of the SFTP session. Error: $($_.Exception.Message)"
        }
    }
}
