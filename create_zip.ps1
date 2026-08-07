# PowerShell Script to Package Video Platform Project into ZIP
$SourceDir = "c:\Users\anjin\Downloads\video-final app\video-platform"
$ZipFile = "c:\Users\anjin\Downloads\video-platform-updated.zip"

Write-Host "Packaging project into $ZipFile..." -ForegroundColor Cyan

if (Test-Path $ZipFile) {
    Remove-Item $ZipFile -Force
}

Add-Type -AssemblyName System.IO.Compression.FileSystem

$compressionLevel = [System.IO.Compression.CompressionLevel]::Optimal
$excludeFolders = @('.git', '.dart_tool', 'build', 'node_modules', '.idea', '.vscode')

$files = Get-ChildItem -Path $SourceDir -Recurse | Where-Object {
    $full = $_.FullName
    $exclude = $false
    foreach ($ef in $excludeFolders) {
        if ($full -like "*\$ef\*" -or $full -like "*\$ef") {
            $exclude = $true
            break
        }
    }
    -not $exclude -and -not $_.PSIsContainer
}

$zip = [System.IO.Compression.ZipFile]::Open($ZipFile, [System.IO.Compression.ZipArchiveMode]::Create)

try {
    foreach ($file in $files) {
        $relPath = $file.FullName.Substring($SourceDir.Length + 1)
        [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $file.FullName, $relPath, $compressionLevel) | Out-Null
    }
} finally {
    $zip.Dispose()
}

Write-Host "SUCCESS: ZIP created at $ZipFile" -ForegroundColor Green
