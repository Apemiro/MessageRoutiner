unit mr_misc;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Windows;

const
  INPUT_MOUSE    = 0;
  INPUT_KEYBOARD = 1;
  INPUT_HARDWARE = 2;

type
  TLastInputInfo = record
    cbSize: UINT;
    dwTime: DWORD;
  end;

  // 以下这些未必会全部用到，只是根据SendInput的参数要求拓展抄了一些
  // 实际引入SendInput目前只是为了刷新空闲计时器
  TInputType = DWORD;
  TKeyboardInput = record
    wVk: WORD;
    wScan: WORD;
    dwFlags: DWORD;
    time: DWORD;
    dwExtraInfo: ULONG_PTR;
  end;
  TMouseInput = record
    dx: LongInt;
    dy: LongInt;
    mouseData: DWORD;
    dwFlags: DWORD;
    time: DWORD;
    dwExtraInfo: ULONG_PTR;
  end;
  THardwareInput = record
    uMsg: DWORD;
    wParamL: WORD;
    wParamH: WORD;
  end;
  TInput = record case itype:DWORD of
    INPUT_MOUSE:    (mi:TMouseInput);
    INPUT_KEYBOARD: (ki:TKeyboardInput);
    INPUT_HARDWARE: (hi:THardwareInput);
  end;
  PInput = ^TInput;
  // 以上这些未必会全部用到，只是根据SendInput的参数要求拓展抄了一些


function GetDPIScaling:double;
function GetDPI:integer;
function GetDPIRect(ARect:TRect):TRect;
function GetIdleTime:dword;
procedure RenewIdleTime;
procedure process_sleep(n:longint);

implementation

function GetDPIScaling:double;
var dc:HDC;
begin
  dc:=GetDC(0);
  result:=GetDeviceCaps(dc, DESKTOPHORZRES) / GetDeviceCaps(dc, HORZRES);
  ReleaseDC(0,dc);
end;

function GetDPI:integer;
var dtmp:double;
begin
  dtmp:=GetDPIScaling;
  result:=round(96*dtmp);
end;

function GetDPIRect(ARect:TRect):TRect;
var dpiScaling:double;
begin
  dpiScaling:=GetDPIScaling;
  result:=Classes.Rect(
    round(dpiScaling*ARect.Left),
    round(dpiScaling*ARect.Top),
    round(dpiScaling*ARect.Right),
    round(dpiScaling*ARect.Bottom)
  );
end;

// 从 User32.dll 导入函数
function GetLastInputInfo(var plii: TLastInputInfo): BOOL; stdcall;
  external 'User32.dll' name 'GetLastInputInfo';

// 获取空闲时间（毫秒）
function GetIdleTime:dword;
var lii: TLastInputInfo;
begin
  lii.cbSize := SizeOf(TLastInputInfo);
  if GetLastInputInfo(lii) then result := GetTickCount - lii.dwTime
  else result := 0;
end;

function SendInput(nInputs: UINT; pInputs: PInput; cbSize: Integer): UINT; stdcall;
  external 'user32.dll';

procedure RenewIdleTime;
var tagInput: TInput;
begin
  tagInput.itype := INPUT_KEYBOARD;
  tagInput.ki.wVk := 0; //VK_NONE
  tagInput.ki.wScan := 0;
  tagInput.ki.dwFlags := KEYEVENTF_KEYUP; // 或 KEYEVENTF_KEYDOWN 都可以尝试
  tagInput.ki.time := 0;
  tagInput.ki.dwExtraInfo := 0;
  // 发送输入事件
  SendInput(1, @tagInput, SizeOf(TInput));
end;

procedure process_sleep(n:longint);
var t0,t1,t2:TDateTime;
begin
  t0:=Now;
  t2:=t0+n/86400000;
  repeat
    t1:=Now;
    Application.ProcessMessages;
  until t1>=t2;
end;

end.

