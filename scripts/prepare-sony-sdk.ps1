param(
    [string]$SdkZip = $env:SONY_CRSDK_WIN64_ZIP,
    [string]$OutputDirectory
)

$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($SdkZip)) {
    $SdkZip = Join-Path $ProjectRoot "CrSDK_v2.02.00_20260610a_Win64.zip"
}
if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $OutputDirectory = Join-Path $ProjectRoot "build/sony-sdk/windows"
}
if (-not (Test-Path -LiteralPath $SdkZip -PathType Leaf)) {
    throw "Sony Camera Remote SDK archive not found: $SdkZip"
}

$TemporaryRoot = Join-Path ([IO.Path]::GetTempPath()) (
    "zenche-sony-sdk-" + [Guid]::NewGuid().ToString("N"))
try {
    New-Item -ItemType Directory -Force -Path $TemporaryRoot | Out-Null
    $Outer = Join-Path $TemporaryRoot "outer"
    [IO.Compression.ZipFile]::ExtractToDirectory($SdkZip, $Outer)
    $SimpleZip = Join-Path $Outer "SimpleCli.zip"
    if (-not (Test-Path -LiteralPath $SimpleZip -PathType Leaf)) {
        throw "SimpleCli.zip is missing from the Sony SDK archive."
    }
    $Simple = Join-Path $TemporaryRoot "simple"
    [IO.Compression.ZipFile]::ExtractToDirectory($SimpleZip, $Simple)
    $HeaderRoot = Join-Path $Simple "app/CRSDK"
    $RuntimeRoot = Join-Path $Simple "external/crsdk"
    foreach ($Required in @(
        (Join-Path $HeaderRoot "CameraRemote_SDK.h"),
        (Join-Path $RuntimeRoot "Cr_Core.dll"),
        (Join-Path $RuntimeRoot "monitor_protocol.dll"),
        (Join-Path $RuntimeRoot "monitor_protocol_pf.dll"),
        (Join-Path $RuntimeRoot "CrAdapter/Cr_PTP_USB.dll"),
        (Join-Path $RuntimeRoot "CrAdapter/Cr_PTP_IP.dll"),
        (Join-Path $RuntimeRoot "CrAdapter/libusb-1.0.dll"),
        (Join-Path $RuntimeRoot "CrAdapter/libssh2.dll")
    )) {
        if (-not (Test-Path -LiteralPath $Required)) {
            throw "Required Sony SDK file is missing: $Required"
        }
    }

    if (Test-Path -LiteralPath $OutputDirectory) {
        Remove-Item -LiteralPath $OutputDirectory -Recurse -Force
    }
    $IncludeOutput = Join-Path $OutputDirectory "include/CRSDK"
    $AdapterOutput = Join-Path $OutputDirectory "CrAdapter"
    $DocumentationOutput = Join-Path $OutputDirectory "documentation"
    New-Item -ItemType Directory -Force -Path `
        $IncludeOutput, $AdapterOutput, $DocumentationOutput | Out-Null
    Get-ChildItem -LiteralPath $HeaderRoot -Filter "*.h" -File |
        Copy-Item -Destination $IncludeOutput -Force
    Get-ChildItem -LiteralPath $RuntimeRoot -Filter "*.dll" -File |
        Copy-Item -Destination $OutputDirectory -Force
    Get-ChildItem -LiteralPath (Join-Path $RuntimeRoot "CrAdapter") `
        -Filter "*.dll" -File |
        Copy-Item -Destination $AdapterOutput -Force
    Copy-Item -LiteralPath `
        (Join-Path $Outer "Camera_Remote_SDK_Readme_v2.02.00.pdf") `
        -Destination $DocumentationOutput -Force
    Write-Output $OutputDirectory
}
finally {
    if (Test-Path -LiteralPath $TemporaryRoot) {
        Remove-Item -LiteralPath $TemporaryRoot -Recurse -Force
    }
}
