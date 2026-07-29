!ifndef PRODUCT_VERSION
  !error "PRODUCT_VERSION is required."
!endif
!ifndef FILE_VERSION
  !error "FILE_VERSION is required."
!endif
!ifndef APP_ARCHITECTURE
  !error "APP_ARCHITECTURE is required."
!endif
!ifndef PUBLISH_DIR
  !error "PUBLISH_DIR is required."
!endif
!ifndef PROJECT_ROOT
  !error "PROJECT_ROOT is required."
!endif
!ifndef OUTPUT_FILE
  !error "OUTPUT_FILE is required."
!endif

!include "MUI2.nsh"

Unicode true
Name "帧澈 ZENCHE"
Caption "帧澈 ZENCHE ${PRODUCT_VERSION} 安装程序"
BrandingText "帧澈 ZENCHE"
OutFile "${OUTPUT_FILE}"
InstallDir "$PROGRAMFILES64\帧澈 ZENCHE"
InstallDirRegKey HKLM "Software\NikonLink" "InstallDir"
RequestExecutionLevel admin
ManifestDPIAware true
SetCompressor /SOLID lzma
SetCompressorDictSize 64

VIProductVersion "${FILE_VERSION}"
VIAddVersionKey /LANG=2052 "ProductName" "帧澈 ZENCHE"
VIAddVersionKey /LANG=2052 "ProductVersion" "${PRODUCT_VERSION}"
VIAddVersionKey /LANG=2052 "FileDescription" "帧澈 ZENCHE ${APP_ARCHITECTURE} 安装程序"
VIAddVersionKey /LANG=2052 "FileVersion" "${PRODUCT_VERSION}"
VIAddVersionKey /LANG=2052 "CompanyName" "帧澈 ZENCHE contributors"
VIAddVersionKey /LANG=2052 "LegalCopyright" "Copyright (c) 2026 Tauber01"

!define MUI_ABORTWARNING
!define MUI_ICON "${PROJECT_ROOT}/native/windows/Assets/app-icon.ico"
!define MUI_UNICON "${PROJECT_ROOT}/native/windows/Assets/app-icon.ico"
!define MUI_FINISHPAGE_RUN "$INSTDIR\ZENCHE.exe"
!define MUI_FINISHPAGE_RUN_TEXT "启动 帧澈 ZENCHE"

Var StartMenuFolder

!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_LICENSE "${PROJECT_ROOT}/LICENSE"
!insertmacro MUI_PAGE_DIRECTORY

!define MUI_STARTMENUPAGE_REGISTRY_ROOT "HKLM"
!define MUI_STARTMENUPAGE_REGISTRY_KEY "Software\NikonLink"
!define MUI_STARTMENUPAGE_REGISTRY_VALUENAME "StartMenuFolder"
!insertmacro MUI_PAGE_STARTMENU Application $StartMenuFolder

!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH

!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES

!insertmacro MUI_LANGUAGE "SimpChinese"
!insertmacro MUI_LANGUAGE "English"

Function .onInit
check_running:
  FindWindow $0 "" "帧澈 ZENCHE"
  IntCmp $0 0 app_closed
  MessageBox MB_RETRYCANCEL|MB_ICONEXCLAMATION \
    "请先关闭正在运行的 帧澈 ZENCHE，然后选择“重试”继续安装。" \
    IDRETRY check_running
  Abort

app_closed:
FunctionEnd

Section "帧澈 ZENCHE" SecApplication
  SectionIn RO
  SetShellVarContext all
  SetRegView 64

  SetOutPath "$INSTDIR"
  File /r /x ".DS_Store" "${PUBLISH_DIR}/*"

  WriteUninstaller "$INSTDIR\Uninstall.exe"
  WriteRegStr HKLM "Software\NikonLink" "InstallDir" "$INSTDIR"

  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\NikonLink" \
    "DisplayName" "帧澈 ZENCHE"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\NikonLink" \
    "DisplayVersion" "${PRODUCT_VERSION}"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\NikonLink" \
    "Publisher" "帧澈 ZENCHE contributors"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\NikonLink" \
    "InstallLocation" "$INSTDIR"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\NikonLink" \
    "DisplayIcon" "$INSTDIR\ZENCHE.exe"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\NikonLink" \
    "UninstallString" '"$INSTDIR\Uninstall.exe"'
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\NikonLink" \
    "QuietUninstallString" '"$INSTDIR\Uninstall.exe" /S'
  WriteRegDWORD HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\NikonLink" \
    "NoModify" 1
  WriteRegDWORD HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\NikonLink" \
    "NoRepair" 1

  !insertmacro MUI_STARTMENU_WRITE_BEGIN Application
    CreateDirectory "$SMPROGRAMS\$StartMenuFolder"
    CreateShortcut "$SMPROGRAMS\$StartMenuFolder\帧澈 ZENCHE.lnk" \
      "$INSTDIR\ZENCHE.exe" "" "$INSTDIR\ZENCHE.exe"
    CreateShortcut "$SMPROGRAMS\$StartMenuFolder\卸载 帧澈 ZENCHE.lnk" \
      "$INSTDIR\Uninstall.exe"
  !insertmacro MUI_STARTMENU_WRITE_END

  CreateShortcut "$DESKTOP\帧澈 ZENCHE.lnk" \
    "$INSTDIR\ZENCHE.exe" "" "$INSTDIR\ZENCHE.exe"
SectionEnd

Section "Uninstall"
  SetShellVarContext all
  SetRegView 64

  !insertmacro MUI_STARTMENU_GETFOLDER Application $StartMenuFolder
  Delete "$SMPROGRAMS\$StartMenuFolder\帧澈 ZENCHE.lnk"
  Delete "$SMPROGRAMS\$StartMenuFolder\卸载 帧澈 ZENCHE.lnk"
  RMDir "$SMPROGRAMS\$StartMenuFolder"
  Delete "$DESKTOP\帧澈 ZENCHE.lnk"

  DeleteRegKey HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\NikonLink"
  DeleteRegKey HKLM "Software\NikonLink"

  RMDir /r /REBOOTOK "$INSTDIR"
SectionEnd
