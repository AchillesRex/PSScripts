# Local Directory
$localDirectory = "C:\TempTest"

# Validate local directory
if (!(Test-Path $localDirectory -PathType Container)) {
    Write-Error "Invalid local directory path: $localDirectory"
    exit 1
}

# Get the current date
$currentDate = Get-Date

# Calculate the date 60 days ago
$cutoffDate = $currentDate.AddDays(-60)

# Get all files in the specified directory
$files = Get-ChildItem -Path $localDirectory -File

# Check if there are any files in the directory
if ($files.Count -eq 0) {
    Write-Host "No files found in the directory '$localDirectory'."
    exit 0
}

# Delete files older than 60 days
$deletedCount = 0
$deletionErrors = 0

foreach ($file in $files) {
    if ($file.LastWriteTime -lt $cutoffDate) {
        try {
            Remove-Item -Path $file.FullName -Force
            Write-Host "Deleted: $($file.FullName)"
            $deletedCount++
        }
        catch {
            Write-Error "Failed to delete file: $($file.FullName). Error: $($_.Exception.Message)"
            $deletionErrors++
        }
    }
}

# Display summary of deleted files and errors
Write-Host "Deleted $deletedCount file(s) older than 60 days."

if ($deletionErrors -gt 0) {
    Write-Warning "Encountered $deletionErrors error(s) during file deletion."
}

# Check if all files were deleted successfully
if ($deletedCount -eq $files.Count) {
    Write-Host "All files older than 60 days have been deleted successfully."
}
else {
    $remainingFiles = $files.Count - $deletedCount
    Write-Host "$remainingFiles file(s) newer than 60 days remain in the directory."
}