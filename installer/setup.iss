; Installateur Windows — DentaGest (Inno Setup)
; Variables passées par la ligne de commande : /DAppVersion=1.0.0
#ifndef AppVersion
  #define AppVersion "1.0.0"
#endif

[Setup]
AppId={{B6E1D9A2-5C3F-4E0A-9D11-7A2C4F8E3B60}
AppName=DentaGest
AppVersion={#AppVersion}
AppPublisher=HAMITI Nassim
DefaultDirName={autopf}\DentaGest
DefaultGroupName=DentaGest
OutputDir=..\installer_output
OutputBaseFilename=DentaGest-Setup
Compression=lzma2
SolidCompression=yes
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=admin
WizardStyle=modern
DisableProgramGroupPage=yes
UninstallDisplayIcon={app}\dental_clinic.exe
SetupIconFile=..\assets\app_icon.ico

[Languages]
Name: "french"; MessagesFile: "compiler:Languages\French.isl"

[Tasks]
Name: "desktopicon"; Description: "Créer un raccourci sur le Bureau"; Flags: checkedonce

[Files]
; Application Flutter (dossier Release complet)
Source: "..\dist_windows\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs ignoreversion

[Icons]
Name: "{autoprograms}\DentaGest"; Filename: "{app}\dental_clinic.exe"; WorkingDir: "{app}"
Name: "{autodesktop}\DentaGest"; Filename: "{app}\dental_clinic.exe"; WorkingDir: "{app}"; Tasks: desktopicon

[Run]
; Autorise la base de données sur le réseau local (postes secondaires)
Filename: "{sys}\netsh.exe"; Parameters: "advfirewall firewall add rule name=""DentaGest - Base de donnees"" dir=in action=allow program=""{app}\dental_db.exe"" enable=yes profile=private,domain"; Flags: runhidden; StatusMsg: "Configuration du réseau…"
Filename: "{app}\dental_clinic.exe"; Description: "Lancer DentaGest"; WorkingDir: "{app}"; Flags: nowait postinstall skipifsilent

[UninstallRun]
Filename: "{sys}\taskkill.exe"; Parameters: "/F /IM dental_db.exe"; Flags: runhidden; RunOnceId: "KillDb"
Filename: "{sys}\netsh.exe"; Parameters: "advfirewall firewall delete rule name=""DentaGest - Base de donnees"""; Flags: runhidden; RunOnceId: "DelFw"
; Les données (AppData\Roaming\...\database) ne sont volontairement PAS supprimées.
