param(
    [ValidateSet("win-x64", "win-arm64")]
    [string]$Runtime = "win-x64",
    [string]$LibUsbDll = $env:NIKONLINK_LIBUSB_DLL,
    [string]$MakeNsisPath,
    [switch]$FrameworkDependent
)

$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$ProjectFile = Join-Path $ProjectRoot "native/windows/NikonLink.Windows.csproj"
$InstallerScript = Join-Path $ProjectRoot "native/windows/Installer/NikonLink.nsi"
$PrepareNikonSdk = Join-Path $ProjectRoot "scripts/prepare-nikon-sdk.ps1"
$PrepareSonySdk = Join-Path $ProjectRoot "scripts/prepare-sony-sdk.ps1"
$BuildRoot = Join-Path $ProjectRoot "build/windows"
$NikonSdkRoot = Join-Path $ProjectRoot "build/nikon-sdk/windows"
$SonySdkRoot = Join-Path $ProjectRoot "build/sony-sdk/windows"
$PublishDirectory = Join-Path $BuildRoot $Runtime
$DistDirectory = Join-Path $ProjectRoot "dist"
$Architecture = if ($Runtime -eq "win-arm64") { "arm64" } else { "x64" }
$PackageVersion = "1.5.15"
$BuildNumber = 42
$FileVersion = "$PackageVersion.$BuildNumber"
$ArchiveName = "ZENCHE-$PackageVersion-Windows-$Architecture.zip"
$ArchivePath = Join-Path $DistDirectory $ArchiveName
$InstallerName = "ZENCHE-$PackageVersion-Windows-$Architecture-Setup.exe"
$InstallerPath = Join-Path $DistDirectory $InstallerName
$PublishGlob = if ($env:OS -eq "Windows_NT") {
    "$PublishDirectory\*"
} else {
    "$PublishDirectory/*"
}

function Resolve-MakeNsis {
    if (-not [string]::IsNullOrWhiteSpace($MakeNsisPath)) {
        return (Resolve-Path -LiteralPath $MakeNsisPath).Path
    }

    $Command = Get-Command makensis -ErrorAction SilentlyContinue
    if ($Command) {
        return $Command.Source
    }

    $Candidates = @()
    if ($env:ProgramFiles) {
        $Candidates += Join-Path $env:ProgramFiles "NSIS/makensis.exe"
    }
    if (${env:ProgramFiles(x86)}) {
        $Candidates += Join-Path ${env:ProgramFiles(x86)} "NSIS/makensis.exe"
    }
    foreach ($Candidate in $Candidates) {
        if (Test-Path -LiteralPath $Candidate) {
            return $Candidate
        }
    }

    throw "NSIS 3 is required to create the EXE installer. Install it from https://nsis.sourceforge.io/Download or pass -MakeNsisPath."
}

function Write-Checksum([string]$Path, [string]$FileName) {
    $Digest = (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant()
    [IO.File]::WriteAllText(
        "$Path.sha256",
        "$Digest  $FileName`n",
        [Text.UTF8Encoding]::new($false)
    )
}

if (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) {
    throw ".NET 8 SDK is required. Install it from https://dotnet.microsoft.com/download/dotnet/8.0"
}
$ProjectXml = [xml](Get-Content -LiteralPath $ProjectFile -Raw)
$ProjectVersionNode = Select-Xml -Xml $ProjectXml -XPath "/Project/PropertyGroup/Version" |
    Select-Object -First 1
if (-not $ProjectVersionNode -or $ProjectVersionNode.Node.InnerText -ne $PackageVersion) {
    throw "Windows project version must match package version $PackageVersion."
}
if ([string]::IsNullOrWhiteSpace($LibUsbDll)) {
    throw "Pass -LibUsbDll or set NIKONLINK_LIBUSB_DLL to the matching official libusb-1.0.dll."
}
if ($Runtime -ne "win-x64") {
    throw "Nikon's official Remote SDK and Image SDK in the supplied archives are x64-only. Build win-x64 for the SDK-enabled Windows package."
}
$ResolvedLibUsb = (Resolve-Path -LiteralPath $LibUsbDll).Path
if ([IO.Path]::GetFileName($ResolvedLibUsb) -ne "libusb-1.0.dll") {
    throw "The native dependency must be named libusb-1.0.dll."
}
$ResolvedMakeNsis = Resolve-MakeNsis

New-Item -ItemType Directory -Force -Path $BuildRoot, $DistDirectory | Out-Null
if (Test-Path -LiteralPath $PublishDirectory) {
    Remove-Item -LiteralPath $PublishDirectory -Recurse -Force
}

$SelfContained = if ($FrameworkDependent) { "false" } else { "true" }
dotnet publish $ProjectFile `
    --configuration Release `
    --runtime $Runtime `
    --self-contained $SelfContained `
    -p:PublishSingleFile=true `
    -p:IncludeNativeLibrariesForSelfExtract=true `
    -p:EnableCompressionInSingleFile=true `
    -p:DebugType=None `
    -p:DebugSymbols=false `
    --output $PublishDirectory
if ($LASTEXITCODE -ne 0) {
    throw "dotnet publish failed with exit code $LASTEXITCODE."
}

Copy-Item -LiteralPath $ResolvedLibUsb `
    -Destination (Join-Path $PublishDirectory "libusb-1.0.dll")
$NikonImageArchive = if ([string]::IsNullOrWhiteSpace($env:NIKON_IMAGE_SDK_ZIP)) {
    Join-Path $ProjectRoot "S-SDKNEF-001BF-ALLIN.zip"
} else { $env:NIKON_IMAGE_SDK_ZIP }
$NikonRemoteArchive = if ([string]::IsNullOrWhiteSpace($env:NIKON_REMOTE_SDK_ZIP)) {
    Join-Path $ProjectRoot "S-SDKZ-200BF-ALLIN.zip"
} else { $env:NIKON_REMOTE_SDK_ZIP }
if ((Test-Path -LiteralPath $NikonImageArchive -PathType Leaf) -and
    (Test-Path -LiteralPath $NikonRemoteArchive -PathType Leaf)) {
    & $PrepareNikonSdk -OutputDirectory $NikonSdkRoot
    if ($LASTEXITCODE -ne 0) {
        throw "Preparing the Nikon SDK runtime failed with exit code $LASTEXITCODE."
    }
} elseif (-not (Test-Path -LiteralPath (Join-Path $NikonSdkRoot "Image/NkImgSDK.dll") -PathType Leaf) -or
          -not (Test-Path -LiteralPath (Join-Path $NikonSdkRoot "Remote/ControlServiceLayer.dll") -PathType Leaf)) {
    throw "Nikon SDK archives and prepared Windows runtime are both unavailable."
}
Copy-Item -LiteralPath $NikonSdkRoot `
    -Destination (Join-Path $PublishDirectory "NikonSDK") -Recurse -Force
$SonyArchive = if ([string]::IsNullOrWhiteSpace($env:SONY_CRSDK_WIN64_ZIP)) {
    Join-Path $ProjectRoot "CrSDK_v2.02.00_20260610a_Win64.zip"
} else { $env:SONY_CRSDK_WIN64_ZIP }
if (Test-Path -LiteralPath $SonyArchive -PathType Leaf) {
    & $PrepareSonySdk -OutputDirectory $SonySdkRoot
    if ($LASTEXITCODE -ne 0) {
        throw "Preparing the Sony Camera Remote SDK runtime failed with exit code $LASTEXITCODE."
    }
} elseif (-not (Test-Path -LiteralPath (Join-Path $SonySdkRoot "Cr_Core.dll") -PathType Leaf) -or
          -not (Test-Path -LiteralPath (Join-Path $SonySdkRoot "CrAdapter/Cr_PTP_USB.dll") -PathType Leaf)) {
    throw "Sony SDK archive and prepared Windows runtime are both unavailable."
}
Get-ChildItem -LiteralPath $SonySdkRoot -Filter "*.dll" -File |
    Copy-Item -Destination $PublishDirectory -Force
Copy-Item -LiteralPath (Join-Path $SonySdkRoot "CrAdapter") `
    -Destination (Join-Path $PublishDirectory "CrAdapter") -Recurse -Force
Copy-Item -LiteralPath (Join-Path $SonySdkRoot "documentation") `
    -Destination (Join-Path $PublishDirectory "SonySDK") -Recurse -Force
Copy-Item -LiteralPath (Join-Path $ProjectRoot "LICENSE") `
    -Destination (Join-Path $PublishDirectory "LICENSE.txt")
Copy-Item -LiteralPath (Join-Path $ProjectRoot "THIRD_PARTY_NOTICES.md") `
    -Destination (Join-Path $PublishDirectory "THIRD_PARTY_NOTICES.md")

if (Test-Path -LiteralPath $ArchivePath) {
    Remove-Item -LiteralPath $ArchivePath -Force
}
Compress-Archive `
    -Path (Join-Path $PublishDirectory "*") `
    -DestinationPath $ArchivePath `
    -CompressionLevel Optimal

if (Test-Path -LiteralPath $InstallerPath) {
    Remove-Item -LiteralPath $InstallerPath -Force
}
$NsisOptionPrefix = if ($env:OS -eq "Windows_NT") { "/" } else { "-" }
& $ResolvedMakeNsis `
    "${NsisOptionPrefix}V2" `
    "${NsisOptionPrefix}DPRODUCT_VERSION=$PackageVersion" `
    "${NsisOptionPrefix}DFILE_VERSION=$FileVersion" `
    "${NsisOptionPrefix}DAPP_ARCHITECTURE=$Architecture" `
    "${NsisOptionPrefix}DPUBLISH_GLOB=$PublishGlob" `
    "${NsisOptionPrefix}DPROJECT_ROOT=$ProjectRoot" `
    "${NsisOptionPrefix}DOUTPUT_FILE=$InstallerPath" `
    $InstallerScript
if ($LASTEXITCODE -ne 0) {
    throw "NSIS failed with exit code $LASTEXITCODE."
}
if (-not (Test-Path -LiteralPath $InstallerPath)) {
    throw "NSIS completed without producing $InstallerPath."
}

Write-Checksum -Path $ArchivePath -FileName $ArchiveName
Write-Checksum -Path $InstallerPath -FileName $InstallerName

Write-Host "Windows installer: $InstallerPath"
Write-Host "SHA-256:          $InstallerPath.sha256"
Write-Host "Portable archive: $ArchivePath"
Write-Host "SHA-256:          $ArchivePath.sha256"
