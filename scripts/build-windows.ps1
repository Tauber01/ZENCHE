param(
    [ValidateSet("win-x64", "win-arm64")]
    [string]$Runtime = "win-x64",
    [string]$LibUsbDll = $env:NIKONLINK_LIBUSB_DLL,
    [switch]$FrameworkDependent
)

$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$ProjectFile = Join-Path $ProjectRoot "native/windows/NikonLink.Windows.csproj"
$BuildRoot = Join-Path $ProjectRoot "build/windows"
$PublishDirectory = Join-Path $BuildRoot $Runtime
$DistDirectory = Join-Path $ProjectRoot "dist"
$Architecture = if ($Runtime -eq "win-arm64") { "arm64" } else { "x64" }
$ArchiveName = "NikonLink-0.7.3-Windows-$Architecture.zip"
$ArchivePath = Join-Path $DistDirectory $ArchiveName

if (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) {
    throw ".NET 8 SDK is required. Install it from https://dotnet.microsoft.com/download/dotnet/8.0"
}
if ([string]::IsNullOrWhiteSpace($LibUsbDll)) {
    throw "Pass -LibUsbDll or set NIKONLINK_LIBUSB_DLL to the matching official libusb-1.0.dll."
}
$ResolvedLibUsb = (Resolve-Path -LiteralPath $LibUsbDll).Path
if ([IO.Path]::GetFileName($ResolvedLibUsb) -ne "libusb-1.0.dll") {
    throw "The native dependency must be named libusb-1.0.dll."
}

New-Item -ItemType Directory -Force -Path $BuildRoot, $DistDirectory | Out-Null
if (Test-Path -LiteralPath $PublishDirectory) {
    Remove-Item -LiteralPath $PublishDirectory -Recurse -Force
}

$SelfContained = if ($FrameworkDependent) { "false" } else { "true" }
dotnet publish $ProjectFile `
    --configuration Release `
    --runtime $Runtime `
    --self-contained $SelfContained `
    -p:PublishSingleFile=false `
    -p:DebugType=None `
    -p:DebugSymbols=false `
    --output $PublishDirectory

Copy-Item -LiteralPath $ResolvedLibUsb `
    -Destination (Join-Path $PublishDirectory "libusb-1.0.dll")
if (Test-Path -LiteralPath $ArchivePath) {
    Remove-Item -LiteralPath $ArchivePath -Force
}
Compress-Archive `
    -Path (Join-Path $PublishDirectory "*") `
    -DestinationPath $ArchivePath `
    -CompressionLevel Optimal

$Digest = (Get-FileHash -Algorithm SHA256 -LiteralPath $ArchivePath).Hash.ToLowerInvariant()
$ChecksumPath = "$ArchivePath.sha256"
[IO.File]::WriteAllText(
    $ChecksumPath,
    "$Digest  $ArchiveName`n",
    [Text.UTF8Encoding]::new($false)
)

Write-Host "Windows package: $ArchivePath"
Write-Host "SHA-256:        $ChecksumPath"
