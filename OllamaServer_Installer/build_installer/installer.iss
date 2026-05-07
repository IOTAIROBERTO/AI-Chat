; VR Training AI Server - Inno Setup Script
; Version 5.0 - Robust Distributable Edition
; Features: Pre-flight checks, GUI model selection, silent install, auto-launch

#define MyAppName "TRAINING AI SERVER"
#define MyAppVersion "5.0"
#define MyAppPublisher "VR Training Solutions"
#define MyAppURL "https://www.example.com"
#define MyAppExeName "launch_server.bat"

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
OutputBaseFilename=TRAINING_AI_SERVER_v{#MyAppVersion}_Setup
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
; Main Python files
Source: "payload\server\offline_server.py"; DestDir: "{app}\server"; Flags: ignoreversion
Source: "payload\server\launcher.py"; DestDir: "{app}\server"; Flags: ignoreversion
Source: "payload\server\requirements.txt"; DestDir: "{app}\server"; Flags: ignoreversion

; Installer scripts
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
Source: "payload\launch_server.bat"; DestDir: "{app}"; Flags: ignoreversion

; Documentation
Source: "README_BILINGUAL.md"; DestDir: "{app}"; DestName: "README.md"; Flags: ignoreversion skipifsourcedoesntexist
Source: "MIGRATION_FROM_LLAMA.md"; DestDir: "{app}"; Flags: ignoreversion skipifsourcedoesntexist
Source: "LICENSE.txt"; DestDir: "{app}"; Flags: ignoreversion skipifsourcedoesntexist

; Logo and icons
Source: "payload\server\logo.png"; DestDir: "{app}\server"; Flags: ignoreversion skipifsourcedoesntexist
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
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{app}\logo.ico"; Comment: "Launch VR Training AI Server"
Name: "{group}\README"; Filename: "{app}\README.md"; Comment: "User Guide (Bilingual)"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
; Desktop icon: always created (not optional)
Name: "{commondesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{app}\logo.ico"; Comment: "Launch VR Training AI Server"
; Per-user desktop fallback (Tasks: desktopicon checkbox still works for extra copies)
Name: "{autodesktop}\{#MyAppName} (user)"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{app}\logo.ico"; Tasks: desktopicon; Comment: "Launch VR Training AI Server"

[Run]
; Silent installation - no CMD window shown, all output goes to log file
Filename: "{app}\installer\smart_installer.bat"; \
  Parameters: """{app}"" ""{app}\logs\setup.log"""; \
  StatusMsg: "Installing AI components - this takes 15-30 min, please wait..."; \
  Flags: runhidden waituntilterminated

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
Type: filesandordirs; Name: "{app}"
Type: filesandordirs; Name: "{localappdata}\{#MyAppName}"

[Code]
// ============================================================================
// CONSTANTS & VARIABLES
// ============================================================================
const
  NL = #13#10;

var
  InstallationSuccessful: Boolean;

// ============================================================================
// SYSTEM CAPABILITY CHECK
// ============================================================================

function GetRAMGB: Integer;
var
  ResultCode: Integer;
  TempFile: String;
  RamStr: AnsiString;
begin
  Result := 0;
  TempFile := ExpandConstant('{tmp}\ramcheck.txt');
  // PowerShell outputs RAM in GB as a simple integer
  if Exec('powershell.exe',
    '-NoProfile -Command "[Math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory/1GB) | Out-File -FilePath ''' + TempFile + ''' -Encoding ASCII"',
    '', SW_HIDE, ewWaitUntilTerminated, ResultCode) then
  begin
    if LoadStringFromFile(TempFile, RamStr) then
      Result := StrToIntDef(Trim(String(RamStr)), 0);
  end;
end;

function CheckInternetConnectivity: Boolean;
var
  ResultCode: Integer;
begin
  Exec('cmd.exe', '/C ping -n 1 -w 3000 8.8.8.8 >nul 2>&1',
    '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
  Result := (ResultCode = 0);
end;

function CheckSystemRequirements: Boolean;
var
  FreeMB, TotalMB: Cardinal;
  RamGB: Integer;
  Msg: String;
  HasCritical, HasWarning: Boolean;
begin
  HasCritical := False;
  HasWarning := False;
  Msg := 'System Compatibility Check:' + NL + NL;

  // 64-bit architecture
  if IsWin64 then
    Msg := Msg + '[OK]   Architecture: 64-bit Windows' + NL
  else begin
    Msg := Msg + '[FAIL] Architecture: 32-bit detected  (64-bit required)' + NL;
    HasCritical := True;
  end;

  // Disk space (need at least 8 GB free for base install)
  GetSpaceOnDisk(ExpandConstant('{autopf}'), True, FreeMB, TotalMB);
  if FreeMB < 8192 then begin
    Msg := Msg + '[FAIL] Disk Space: ' + IntToStr(FreeMB div 1024) +
           ' GB free  (8 GB required)' + NL;
    HasCritical := True;
  end else if FreeMB < 12288 then begin
    Msg := Msg + '[WARN] Disk Space: ' + IntToStr(FreeMB div 1024) +
           ' GB free  (12 GB recommended for optional models)' + NL;
    HasWarning := True;
  end else
    Msg := Msg + '[OK]   Disk Space: ' + IntToStr(FreeMB div 1024) + ' GB free' + NL;

  // RAM check
  RamGB := GetRAMGB;
  if RamGB < 4 then begin
    Msg := Msg + '[FAIL] RAM: ' + IntToStr(RamGB) +
           ' GB detected  (4 GB required)' + NL;
    HasCritical := True;
  end else if RamGB < 6 then begin
    Msg := Msg + '[WARN] RAM: ' + IntToStr(RamGB) +
           ' GB  (6 GB recommended, may run slowly)' + NL;
    HasWarning := True;
  end else
    Msg := Msg + '[OK]   RAM: ' + IntToStr(RamGB) + ' GB' + NL;

  // Internet connectivity
  if CheckInternetConnectivity then
    Msg := Msg + '[OK]   Internet: Connected' + NL
  else begin
    Msg := Msg + '[FAIL] Internet: Not available  (required to download components)' + NL;
    HasCritical := True;
  end;

  if HasCritical then begin
    MsgBox('INSTALLATION CANNOT CONTINUE' + NL + NL + Msg + NL +
           'Please resolve the issues above and try again.',
           mbError, MB_OK);
    Result := False;
  end else if HasWarning then begin
    Result := MsgBox(Msg + NL +
                     'Some warnings detected. The server may run slowly.' + NL +
                     'Continue with installation?',
                     mbConfirmation, MB_YESNO) = IDYES;
  end else begin
    Result := True;
  end;
end;

// ============================================================================
// SERVER AUTO-LAUNCH
// ============================================================================

function FindPythonW: String;
var
  Paths: TArrayOfString;
  i: Integer;
begin
  Result := '';
  SetArrayLength(Paths, 10);
  Paths[0] := ExpandConstant('{localappdata}\Programs\Python\Python313\pythonw.exe');
  Paths[1] := ExpandConstant('{localappdata}\Programs\Python\Python312\pythonw.exe');
  Paths[2] := ExpandConstant('{localappdata}\Programs\Python\Python311\pythonw.exe');
  Paths[3] := 'C:\Python313\pythonw.exe';
  Paths[4] := 'C:\Python312\pythonw.exe';
  Paths[5] := 'C:\Python311\pythonw.exe';
  Paths[6] := ExpandConstant('{pf}\Python313\pythonw.exe');
  Paths[7] := ExpandConstant('{pf}\Python312\pythonw.exe');
  Paths[8] := ExpandConstant('{pf32}\Python313\pythonw.exe');
  Paths[9] := ExpandConstant('{pf32}\Python311\pythonw.exe');
  for i := 0 to High(Paths) do
    if FileExists(Paths[i]) then begin
      Result := Paths[i];
      Exit;
    end;
end;

procedure LaunchServer;
var
  PythonW, LauncherPath: String;
  ResultCode: Integer;
begin
  LauncherPath := ExpandConstant('{app}\server\launcher.py');
  if not FileExists(LauncherPath) then Exit;

  PythonW := FindPythonW;
  if PythonW = '' then
    PythonW := 'pythonw.exe'; // Rely on PATH as last resort

  Exec(PythonW,
    '"' + LauncherPath + '"',
    ExpandConstant('{app}\server'),
    SW_SHOW, ewNoWait, ResultCode);
end;

// ============================================================================
// INNO SETUP EVENT HANDLERS
// ============================================================================

function InitializeSetup: Boolean;
begin
  Result := True;

  if not IsAdminLoggedOn then begin
    MsgBox('Administrator privileges required.' + NL +
           'Please right-click the installer and select "Run as administrator".' + NL +
           NL + 'Se requieren privilegios de administrador.' + NL +
           'Haga clic derecho y seleccione "Ejecutar como administrador".',
           mbError, MB_OK);
    Result := False;
    Exit;
  end;

  // Run full capability check
  if not CheckSystemRequirements then begin
    Result := False;
    Exit;
  end;
end;

procedure InitializeWizard;
begin
  InstallationSuccessful := False;
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssPostInstall then
    InstallationSuccessful := True;

  // Auto-launch server when installation is fully done (Finish page is shown)
  if CurStep = ssDone then
    LaunchServer;
end;
