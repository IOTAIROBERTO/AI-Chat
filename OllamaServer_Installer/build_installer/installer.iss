; VR Training AI Server - Inno Setup Script
; Version 4.1 - Bilingual Edition (Spanish/English)
; MINIMAL VERSION - Only essential code that compiles

#define MyAppName "TRAINING AI SERVER"
#define MyAppVersion "4.1"
#define MyAppPublisher "VR Training Solutions"
#define MyAppURL "https://www.example.com"
#define MyAppExeName "start_server.bat"

[Setup]
AppId={{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
AllowNoIcons=yes
OutputDir=installer_output
OutputBaseFilename=TRAINING_AI_SERVER_v{#MyAppVersion}_Bilingual_Setup
Compression=lzma
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=admin
DisableProgramGroupPage=yes
MinVersion=10.0.19041

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "spanish"; MessagesFile: "compiler:Languages\Spanish.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; Main Python files (UPDATED v4.1)
Source: "payload\server\offline_server.py"; DestDir: "{app}\server"; Flags: ignoreversion
Source: "payload\server\launcher.py"; DestDir: "{app}\server"; Flags: ignoreversion
Source: "payload\server\requirements.txt"; DestDir: "{app}\server"; Flags: ignoreversion

; Installer scripts (UPDATED v4.1)
Source: "payload\installer\smart_installer.bat"; DestDir: "{app}\installer"; Flags: ignoreversion
Source: "payload\installer\installer_lib.bat"; DestDir: "{app}\installer"; Flags: ignoreversion skipifsourcedoesntexist
Source: "payload\installer\uninstaller_cleanup.bat"; DestDir: "{app}\installer"; Flags: ignoreversion skipifsourcedoesntexist

; Firewall scripts
Source: "scripts\firewall_add.bat"; DestDir: "{app}\installer"; Flags: ignoreversion skipifsourcedoesntexist
Source: "scripts\firewall_remove.bat"; DestDir: "{app}\installer"; Flags: ignoreversion skipifsourcedoesntexist
Source: "payload\utils\firewall_config.bat"; DestDir: "{app}\installer"; Flags: ignoreversion skipifsourcedoesntexist
Source: "payload\installer\configure_security.bat"; DestDir: "{app}\installer"; Flags: ignoreversion skipifsourcedoesntexist
Source: "payload\utils\diagnose_connection.bat"; DestDir: "{app}\installer"; Flags: ignoreversion skipifsourcedoesntexist

; Launcher scripts
Source: "payload\start_server.bat"; DestDir: "{app}"; Flags: ignoreversion

; Documentation (UPDATED for v4.1)
Source: "README_BILINGUAL.md"; DestDir: "{app}"; DestName: "README.md"; Flags: ignoreversion skipifsourcedoesntexist
Source: "MIGRATION_FROM_LLAMA.md"; DestDir: "{app}"; Flags: ignoreversion skipifsourcedoesntexist
Source: "LICENSE.txt"; DestDir: "{app}"; Flags: ignoreversion skipifsourcedoesntexist

; Logo and icons
Source: "server\logo.png"; DestDir: "{app}\server"; Flags: ignoreversion skipifsourcedoesntexist
Source: "logo.ico"; DestDir: "{app}"; Flags: ignoreversion skipifsourcedoesntexist
Source: "logo.png"; DestDir: "{app}"; Flags: ignoreversion skipifsourcedoesntexist

[Dirs]
Name: "{app}\logs"; Permissions: users-modify
Name: "{app}\manuals"; Permissions: users-modify
Name: "{app}\temp"; Permissions: users-modify
Name: "{app}\server"; Permissions: users-modify
Name: "{localappdata}\{#MyAppName}"; Permissions: users-modify
Name: "{localappdata}\{#MyAppName}\chroma_db"; Permissions: users-modify

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Comment: "Launch VR Training AI Server"
Name: "{group}\README"; Filename: "{app}\README.md"; Comment: "User Guide (Bilingual)"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon; Comment: "Launch VR Training AI Server"

[Run]
Filename: "{app}\installer\smart_installer.bat"; Parameters: """{app}"" ""{app}\logs\setup.log"""; StatusMsg: "Instalando componentes (Python, Ollama, dependencias)..."; Flags: waituntilterminated

[UninstallRun]
Filename: "taskkill"; Parameters: "/F /IM python.exe /FI ""WINDOWTITLE eq *offline_server*"""; Flags: runhidden
Filename: "taskkill"; Parameters: "/F /IM python.exe /FI ""WINDOWTITLE eq *launcher*"""; Flags: runhidden
Filename: "taskkill"; Parameters: "/F /IM pythonw.exe"; Flags: runhidden
Filename: "taskkill"; Parameters: "/F /IM ollama.exe"; Flags: runhidden
Filename: "{app}\installer\firewall_remove.bat"; Flags: runhidden waituntilterminated
Filename: "{app}\installer\uninstaller_cleanup.bat"; Parameters: """{app}"""; Flags: runhidden waituntilterminated

[UninstallDelete]
Type: filesandordirs; Name: "{app}\logs"
Type: filesandordirs; Name: "{app}\temp"
Type: filesandordirs; Name: "{app}\__pycache__"
Type: filesandordirs; Name: "{app}\server\__pycache__"
Type: files; Name: "{app}\server\*.pyc"
Type: files; Name: "{app}\server\server_config.json"

[Code]
var
  InstallationSuccessful: Boolean;

procedure InitializeWizard;
begin
  InstallationSuccessful := False;
end;

function InitializeSetup(): Boolean;
begin
  Result := True;
  
  // Check for admin rights
  if not IsAdminLoggedOn then
  begin
    MsgBox('Este instalador requiere privilegios de administrador.' + #13#10 + 
           'Por favor, ejecute como administrador.', mbError, MB_OK);
    Result := False;
    exit;
  end;
  
  // Check Windows version
  if (GetWindowsVersion < $0A000000) then
  begin
    MsgBox('Este software requiere Windows 10 (build 19041) o superior.', mbError, MB_OK);
    Result := False;
  end;
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssPostInstall then
  begin
    InstallationSuccessful := True;
  end;
end;
