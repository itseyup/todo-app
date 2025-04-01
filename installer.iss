[Setup]
AppName=Rise To Do App
AppVersion=1.0
WizardStyle=modern
DefaultDirName={autopf}\Rise To Do App
DefaultGroupName=Rise To Do App
OutputBaseFilename=RiseToDoApp
Compression=lzma2
SolidCompression=yes
OutputDir=build\windows\installer

; Add VC++ Redistributable as a prerequisite
[Files]
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs
Source: "vc_redist.x64.exe"; DestDir: "{tmp}"; Flags: deleteafterinstall

[Icons]
Name: "{group}\Rise To Do App"; Filename: "{app}\todo_app.exe"
Name: "{autodesktop}\Rise To Do App"; Filename: "{app}\todo_app.exe"

[Run]
; Install VC++ Redistributable first
Filename: "{tmp}\vc_redist.x64.exe"; Parameters: "/install /quiet /norestart"; StatusMsg: "Installing VC++ Redistributable..."; Flags: waituntilterminated
Filename: "{app}\todo_app.exe"; Description: "Launch Rise To Do App"; Flags: postinstall nowait