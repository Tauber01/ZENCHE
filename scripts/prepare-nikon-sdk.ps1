param(
    [string]$ImageSdkZip = $env:NIKON_IMAGE_SDK_ZIP,
    [string]$RemoteSdkZip = $env:NIKON_REMOTE_SDK_ZIP,
    [string]$OutputDirectory
)

$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($ImageSdkZip)) {
    $ImageSdkZip = Join-Path $ProjectRoot "S-SDKNEF-001BF-ALLIN.zip"
}
if ([string]::IsNullOrWhiteSpace($RemoteSdkZip)) {
    $RemoteSdkZip = Join-Path $ProjectRoot "S-SDKZ-200BF-ALLIN.zip"
}
if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $OutputDirectory = Join-Path $ProjectRoot "build/nikon-sdk/windows"
}
if (-not (Test-Path -LiteralPath $ImageSdkZip -PathType Leaf)) {
    throw "Nikon Image SDK archive not found: $ImageSdkZip"
}
if (-not (Test-Path -LiteralPath $RemoteSdkZip -PathType Leaf)) {
    throw "Nikon Remote SDK archive not found: $RemoteSdkZip"
}

$TemporaryRoot = Join-Path ([IO.Path]::GetTempPath()) (
    "zenche-nikon-sdk-" + [Guid]::NewGuid().ToString("N"))
try {
    New-Item -ItemType Directory -Force -Path $TemporaryRoot | Out-Null
    $ImageExtract = Join-Path $TemporaryRoot "image"
    $RemoteExtract = Join-Path $TemporaryRoot "remote"
    [IO.Compression.ZipFile]::ExtractToDirectory($ImageSdkZip, $ImageExtract)
    [IO.Compression.ZipFile]::ExtractToDirectory($RemoteSdkZip, $RemoteExtract)

    if (Test-Path -LiteralPath $OutputDirectory) {
        Remove-Item -LiteralPath $OutputDirectory -Recurse -Force
    }
    $ImageOutput = Join-Path $OutputDirectory "Image"
    $RemoteOutput = Join-Path $OutputDirectory "Remote"
    New-Item -ItemType Directory -Force -Path $ImageOutput, $RemoteOutput |
        Out-Null

    $ImageRuntime = Join-Path $ImageExtract `
        "Image SDK/Library/win/Bin/x64/Release"
    $ImageProfiles = Join-Path $ImageExtract `
        "Image SDK/Library/win/Profiles"
    $RemoteRuntime = Join-Path $RemoteExtract "Module/Win/BinaryFile"
    if (-not (Test-Path -LiteralPath $ImageRuntime -PathType Container)) {
        throw "Nikon Image SDK x64 runtime is missing from the archive."
    }
    if (-not (Test-Path -LiteralPath $RemoteRuntime -PathType Container)) {
        throw "Nikon Remote SDK x64 runtime is missing from the archive."
    }

    foreach ($Name in @(
        "NkImgSDK.dll",
        "Elm.dll",
        "Elm.nlf",
        "RCSigProc.dll",
        "tbb.dll",
        "tbbmalloc.dll",
        "prm.bin"
    )) {
        $Source = Join-Path $ImageRuntime $Name
        if (-not (Test-Path -LiteralPath $Source -PathType Leaf)) {
            throw "Required Nikon Image SDK runtime file is missing: $Name"
        }
        Copy-Item -LiteralPath $Source -Destination $ImageOutput -Force
    }
    if (Test-Path -LiteralPath $ImageProfiles -PathType Container) {
        Copy-Item -LiteralPath $ImageProfiles `
            -Destination (Join-Path $ImageOutput "Profiles") -Recurse -Force
    }
    Get-ChildItem -LiteralPath $RemoteRuntime -File |
        Where-Object { $_.Name -ne "TestApp.exe" } |
        Copy-Item -Destination $RemoteOutput -Force
    Write-Output $OutputDirectory
}
finally {
    if (Test-Path -LiteralPath $TemporaryRoot) {
        Remove-Item -LiteralPath $TemporaryRoot -Recurse -Force
    }
}
