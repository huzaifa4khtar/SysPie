; SysPie Inno Setup installer script.
; Compile with: ISCC.exe syspie.iss
; Produces: SysPie-Setup.exe (in setup/)

#define MyAppName "SysPie"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "Huzaifa Akhtar"
#define MyAppExeName "SysPie.exe"
#define MyAppId "{{8E13B9C4-2F0A-4C7B-9A31-3F6D1E8B0A27}"

[Setup]
AppId={#MyAppId}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppVerName={#MyAppName} {#MyAppVersion}
UninstallDisplayName={#MyAppName} {#MyAppVersion}
VersionInfoCompany={#MyAppPublisher}
VersionInfoProductName={#MyAppName}
VersionInfoProductVersion={#MyAppVersion}
VersionInfoCopyright=Copyright (C) 2026 {#MyAppPublisher}
DefaultDirName={autopf}\SysPie
DefaultGroupName={#MyAppName}
OutputDir=.
OutputBaseFilename=SysPie-Setup
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
SetupIconFile=..\app\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#MyAppExeName}
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
; Per-user install: no admin or UAC required.
PrivilegesRequired=lowest
; Match the auto-update flags used by update_service.dart.
CloseApplications=yes
RestartApplications=no
DisableProgramGroupPage=yes
; Allow reinstalling over existing directory without warning.
DirExistsWarning=no

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; Copy the entire Flutter release bundle, excluding the MSIX artifact.
Source: "..\app\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs; Excludes: "*.msix"

[Icons]
; Start Menu shortcut, always created.
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{app}\{#MyAppExeName}"
; Optional desktop icon (off by default).
Name: "{userdesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
; Offer to launch after install (skipped silently).
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
; Clean up any subdirectories and files not tracked by Inno Setup.
Type: filesandordirs; Name: "{app}\data"

[Code]
// Kill any running SysPie process before install/upgrade.
procedure CurStepChanged(CurStep: TSetupStep);
var
  ResultCode: Integer;
begin
  if CurStep = ssInstall then
  begin
    // Forcefully terminate any running SysPie instance so files are not locked.
    Exec('taskkill', '/F /IM SysPie.exe', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
  end;
end;
