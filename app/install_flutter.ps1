$ErrorActionPreference = "Stop"

$version = "3.44.2"
$zipPath = "D:\flutter_windows_3.44.2-stable.zip"
$destDir = "D:\"
$flutterBin = "D:\flutter\bin"

Write-Host "1. Downloading Flutter SDK $version..."
$url = "https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_$version-stable.zip"

if (Test-Path $zipPath) {
    Write-Host "Zip file already exists, skipping download."
} else {
    # Using WebClient to download
    $webClient = New-Object System.Net.WebClient
    $webClient.DownloadFile($url, $zipPath)
}

Write-Host "2. Extracting Flutter SDK to $destDir..."
if (Test-Path "D:\flutter") {
    Write-Host "D:\flutter directory already exists. Re-extracting..."
}
Expand-Archive -Path $zipPath -DestinationPath $destDir -Force

Write-Host "3. Cleaning up zip file..."
Remove-Item -Force $zipPath

Write-Host "4. Adding Flutter to User Environment PATH..."
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($userPath -notlike "*D:\flutter\bin*") {
    $newUserPath = $userPath + ";D:\flutter\bin"
    [Environment]::SetEnvironmentVariable("Path", $newUserPath, "User")
    Write-Host "Successfully added D:\flutter\bin to User PATH."
} else {
    Write-Host "D:\flutter\bin is already in PATH."
}

# Update current process PATH
$env:PATH += ";D:\flutter\bin"

Write-Host "5. Verifying installation with flutter doctor..."
& flutter doctor

Write-Host "Installation completed successfully!"
