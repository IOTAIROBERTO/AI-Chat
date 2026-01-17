; VR Training AI Server - Inno Setup Script (MINIMAL VERSION)
; Version 4.0 - Only essential files required

#define MyAppName "TRAINING AI SERVER"
#define MyAppVersion "4.0"
#define MyAppPublisher "VR Training Solutions"
#define MyAppURL "https://www.example.com"

[Setup]
AppId={{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
AllowNoIcons=yes
OutputDir=installer_output
OutputBaseFilename=TRAINING_AI_SERVER_Setup
Compression=lzma
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=admin
DisableProgramGroupPage=yes

[Languages]
Name: "spanish"; MessagesFile: "compiler:Languages\Spanish.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; ============================================================================
; REQUIRED FILES - Must exist or compilation will fail
; ============================================================================

; Main Python files
Source: "payload\server\offline_server.py"; DestDir: "{app}\server"; Flags: ignoreversion
Source: "payload\server\launcher.py"; DestDir: "{app}\server"; Flags: ignoreversion
Source: "payload\server\requirements.txt"; DestDir: "{app}\server"; Flags: ignoreversion

; Installer scripts
Source: "payload\installer\smart_installer.bat"; DestDir: "{app}\installer"; Flags: ignoreversion
Source: "payload\installer\installer_lib.bat"; DestDir: "{app}\installer"; Flags: ignoreversion
Source: "payload\installer\uninstaller_cleanup.bat"; DestDir: "{app}\installer"; Flags: ignoreversion
Source: "scripts\firewall_add.bat"; DestDir: "{app}\installer"; Flags: ignoreversion
Source: "scripts\firewall_remove.bat"; DestDir: "{app}\installer"; Flags: ignoreversion
Source: "payload\utils\firewall_config.bat"; DestDir: "{app}\installer"; Flags: ignoreversion

; Launcher scripts
Source: "payload\start_server.bat"; DestDir: "{app}"; Flags: ignoreversion
Source: "scripts\post_install.bat"; DestDir: "{app}"; Flags: ignoreversion

; ============================================================================
; OPTIONAL FILES - Will be included if they exist
; ============================================================================

; Logo
Source: "server\logo.png"; DestDir: "{app}\server"; Flags: ignoreversion skipifsourcedoesntexist

; Documentation
Source: "README.md"; DestDir: "{app}"; Flags: ignoreversion skipifsourcedoesntexist
Source: "LICENSE.txt"; DestDir: "{app}"; Flags: ignoreversion skipifsourcedoesntexist

; Icons
Source: "logo.ico"; DestDir: "{app}"; Flags: ignoreversion skipifsourcedoesntexist
Source: "logo.png"; DestDir: "{app}"; Flags: ignoreversion skipifsourcedoesntexist

[Dirs]
Name: "{app}\logs"; Permissions: users-modify
Name: "{app}\manuals"; Permissions: users-modify
Name: "{app}\temp"; Permissions: users-modify
Name: "{localappdata}\{#MyAppName}"; Permissions: users-modify
Name: "{localappdata}\{#MyAppName}\chroma_db"; Permissions: users-modify

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\start_server.bat"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\start_server.bat"; Tasks: desktopicon

[Run]
; Run installation script
Filename: "{app}\installer\smart_installer.bat"; Parameters: """{app}"" ""{app}\logs\setup.log"""; StatusMsg: "Instalando componentes (Python, Ollama, dependencias)..."; Flags: runhidden waituntilterminated

[UninstallRun]
; Stop any running processes
Filename: "taskkill"; Parameters: "/F /IM python.exe /FI ""WINDOWTITLE eq *offline_server*"""; Flags: runhidden
Filename: "taskkill"; Parameters: "/F /IM python.exe /FI ""WINDOWTITLE eq *launcher*"""; Flags: runhidden

; Remove firewall rules
Filename: "{app}\installer\firewall_remove.bat"; Flags: runhidden waituntilterminated

; Cleanup
Filename: "{app}\installer\uninstaller_cleanup.bat"; Parameters: """{app}"""; Flags: runhidden waituntilterminated

[UninstallDelete]
Type: filesandordirs; Name: "{app}\logs"
Type: filesandordirs; Name: "{app}\temp"
Type: filesandordirs; Name: "{app}\__pycache__"
Type: filesandordirs; Name: "{app}\server\__pycache__"

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
