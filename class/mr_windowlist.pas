unit mr_windowlist;

{$mode objfpc}{$H+}
{$modeswitch AdvancedRecords}

interface

uses
  Classes, SysUtils, Forms, Windows, LazUTF8, fpjson, mr_misc;

const
  _HwndList_Branch_Count_ = 8;

type
  PHwndRec = ^THwndRec;
  THwndRec = record
    Handle  : HWND;
    NextRec : PHwndRec;
    Data    : Pointer;
  end;
  EHwndList_InvalidData  = Exception;
  EHwndList_RepeatedHwnd = Exception;
  PHwndListOverWriting   = procedure(Data_1, Data_2:Pointer);

  PHwndList = ^THwndList;
  THwndList = record
    Branchs : array[0 .. _HwndList_Branch_Count_ - 1] of PHwndRec;
  public
    function Get(Handle:HWND):Pointer;
    procedure Add(Handle:HWND;Data:Pointer;OverWritingProcess:PHwndListOverWriting=nil);
    procedure Clear;
  end;


  TMR_WindowStatus = (wsNew, wsPersist, wsDeleted);

  TMR_Window = class;
  TMR_WindowEnumerator = class
  private
    FWindow:    TMR_Window;
    FBranchIdx: Integer;
    FCurrent:   PHwndRec;
  public
    constructor Create(AWindow: TMR_Window);
    function GetCurrent: TMR_Window;
    function MoveNext: Boolean;
    property Current: TMR_Window read GetCurrent;
  end;
  TMR_Window = class(TObject)
  private
    FHandle:HWND;
    FName:string;
    FClassName:string;
    FWindowRect:TRect;
    FClientRect:TRect;
    FParent:TMR_Window;
    FChildren:THwndList;
    FStatus:TMR_WindowStatus;
  private
    class function GetWindowText(Handle:HWND):string;
    class function GetClassName(Handle:HWND):string;
    class function GetWindowInfo(Handle:HWND):TWindowInfo;

  public
    class function GetDesktop:TMR_Window;
    procedure UpdateAsDesktop;
    function UpdateChildren:Integer;
    function GetWindowByHWND(handle:HWND):TMR_Window;
    function GetEnumerator:TMR_WindowEnumerator;
    function GetJSON:TJSONData;
    constructor Create;
    destructor Destroy; override;
  public
    property Handle:HWND read FHandle;
    property Name:string read FName;
    property ClassName:string read FClassName;
    property WindowRect:TRect read FWindowRect;
    property ClientRect:TRect read FClientRect;
    property Status:TMR_WindowStatus read FStatus;

  end;

  TMR_Screen = record
    ScreenRect:TRect;
    dpi:integer;
    dpiScaling:double;//并不确定还有没有必要存这个了，如果需要兼容非dpi awareness
  end;
  TMR_VirtualScreenProportionalRect = record
    Left   :Double;
    Top    :Double;
    Width  :Double;
    Height :Double;
  end;

  TMR_ScreenList = class
  private
    FScreenList:array of TMR_Screen;
    FVirtualScreenRect:TRect;
  public
    procedure UpdateScreens;
    function VirtualScreenPosition(FormRect:TRect):TMR_VirtualScreenProportionalRect;
    constructor Create;
    destructor Destroy; override;
  protected
    function GetScreen(index:Integer):TMR_Screen;
    function GetScreenCount:Integer;
  public
    property VirtualScreenRect:TRect read FVirtualScreenRect;
    property Screens[index:Integer]:TMR_Screen read GetScreen;
    property ScreenCount:Integer read GetScreenCount;
  end;

  operator *(rect:TRect;pprect:TMR_VirtualScreenProportionalRect):TRect;
  operator *(pprect:TMR_VirtualScreenProportionalRect;rect:TRect):TRect;inline;

implementation

operator *(rect:TRect;pprect:TMR_VirtualScreenProportionalRect):TRect;
begin
  result.Top    := trunc(rect.Height * pprect.Top)  + rect.Top;
  result.Left   := trunc(rect.Width  * pprect.Left) + rect.Left;
  result.Width  := trunc(rect.Width  * pprect.Width);
  result.Height := trunc(rect.Height * pprect.Height);
end;
operator *(pprect:TMR_VirtualScreenProportionalRect;rect:TRect):TRect;
begin
  result:=rect*pprect;
end;

{ THwndList }

function THwndList.Get(Handle:HWND):Pointer;
var branch_id:byte;
    tmp:PHwndRec;
begin
  result:=nil;
  branch_id:=Handle mod _HwndList_Branch_Count_;
  tmp:=Branchs[branch_id];
  while tmp<>nil do begin
    if tmp^.Handle = Handle then begin
      result:=tmp^.Data;
      exit;
    end;
    tmp:=tmp^.NextRec;
  end;
end;

procedure THwndList.Add(Handle:HWND;Data:Pointer;OverWritingProcess:PHwndListOverWriting=nil);
var branch_id:byte;
    tmp:PHwndRec;
begin
  if Data=nil then
    raise EHwndList_InvalidData.Create('THwndList.Add: Argument "Data" must not be nil. '
      +'(This is to make sure function "Get" only returns nil when no record matching.)');
  branch_id:=Handle mod _HwndList_Branch_Count_;
  tmp:=Branchs[branch_id];
  //取模分支为空时直接新建并退出
  if tmp=nil then begin
    Branchs[branch_id]:=GetMem(sizeof(THwndRec));
    Branchs[branch_id]^.Data:=Data;
    Branchs[branch_id]^.Handle:=Handle;
    Branchs[branch_id]^.NextRec:=nil;
    exit;
  end;
  while tmp^.NextRec<>nil do begin
    //取模分支内有相同Handle时执行自定义的覆盖操作并退出
    //使用缺省操作时抛出异常
    if tmp^.Handle=Handle then begin
      if OverWritingProcess=nil then
        raise EHwndList_RepeatedHwnd.Create('THwndList.Add: Argument "Handle" should not be repeated. '
          +'(Unless OverWritingProcess is not nil.)');
      OverWritingProcess(tmp^.Data,Data);
      exit;
    end;
    tmp:=tmp^.NextRec;
  end;
  //取模分支遍历后没找到相同Handle时追加
  tmp^.NextRec:=GetMem(sizeof(THwndRec));
  tmp^.NextRec^.Data:=Data;
  tmp^.NextRec^.Handle:=Handle;
  tmp^.NextRec^.NextRec:=nil;
end;

procedure THwndList.Clear;
var idx:byte;
    tmp:PHwndRec;
begin
  for idx:=0 to _HwndList_Branch_Count_ - 1 do begin
    while Branchs[idx]<>nil do begin
      tmp:=Branchs[idx];
      Branchs[idx]:=tmp^.NextRec;
      FreeMem(tmp,sizeof(THwndRec));
    end;
  end;
end;


{ TMR_WindowEnumerator }

constructor TMR_WindowEnumerator.Create(AWindow: TMR_Window);
begin
  FBranchIdx:=-1;
  FCurrent:=nil;
  FWindow:=AWindow;
end;

function TMR_WindowEnumerator.GetCurrent: TMR_Window;
begin
  result:=TMR_Window(FCurrent^.Data);
end;

function TMR_WindowEnumerator.MoveNext: Boolean;
var AtLeastOneMove:boolean;
begin
  AtLeastOneMove:=false;
  while FBranchIdx<_HwndList_Branch_Count_ do begin
    if FCurrent<>nil then begin
      if AtLeastOneMove then begin
        result:=true;
        exit;
      end else begin
        FCurrent:=FCurrent^.NextRec;
        AtLeastOneMove:=true;
      end;
    end else begin
      inc(FBranchIdx);
      FCurrent:=FWindow.FChildren.Branchs[FBranchIdx];
      AtLeastOneMove:=true;
    end;
  end;
  result:=false;
  //Free;
end;


{ TMR_Window }

class function TMR_Window.GetWindowText(Handle:HWND):string;
var res:array[0..255]of char;
begin
  result:='';
  if Windows.GetWindowText(Handle,@res[0],255)>0 then result:=WinCPtoUtf8(PChar(@res[0]));
end;

class function TMR_Window.GetClassName(Handle:HWND):string;
var res:array[0..255]of char;
begin
  result:='';
  if Windows.GetClassName(Handle,@res[0],255)>0 then result:=WinCPtoUtf8(PChar(@res[0]));
end;

class function TMR_Window.GetWindowInfo(Handle:HWND):TWindowInfo;
begin
  Windows.GetWindowInfo(Handle,result);
end;

class function TMR_Window.GetDesktop:TMR_Window;
begin
  result:=TMR_Window.Create;
  with result do begin
    FHandle:=GetDesktopWindow();
    FStatus:=wsNew;
    FParent:=nil;
  end;
end;

procedure TMR_Window.UpdateAsDesktop;
begin
  FHandle:=GetDesktopWindow();
  FStatus:=wsPersist;
  FParent:=nil;
end;

function TMR_Window.UpdateChildren:Integer;
var branch_id:byte;
    child_ptr,last_ptr,temp_ptr:PHwndRec;
    child:TMR_Window;
    tmpHWND:HWND;
begin
  result:=0;

  //将已知窗体标注为Persist
  //将已删除窗体在本轮删除
  for branch_id:=0 to _HwndList_Branch_Count_ - 1 do begin
    child_ptr:=FChildren.Branchs[branch_id];
    last_ptr:=nil;
    while child_ptr<>nil do begin
      child:=TMR_Window(child_ptr^.Data);
      if child.FStatus=wsDeleted then begin
        //如果上一轮标记为已删除，这一轮结构上删除
        if child_ptr^.NextRec<>nil then begin
          //如果有后继，把后继抄过来，删除并释放后继
          child_ptr^.Data:=child_ptr^.NextRec^.Data;
          child_ptr^.Handle:=child_ptr^.NextRec^.Handle;
          temp_ptr:=child_ptr^.NextRec^.NextRec;
          FreeMem(child_ptr^.NextRec,sizeof(THwndRec));
          child_ptr^.NextRec:=temp_ptr;
        end else if last_ptr<>nil then begin
          //如果没有后继但是有前趋，前趋next改为nil
          last_ptr^.NextRec:=nil;
        end else begin
          //如果都没有就是该取模分支的唯一元素，分支改为nil
          FChildren.Branchs[branch_id]:=nil;
        end;
        child.Free;
      end else begin
        //如果不是上一轮已删除的情况，就暂时标记为已删除
        child.FStatus:=wsDeleted;
      end;
      last_ptr:=child_ptr;
      child_ptr:=child_ptr^.NextRec;
    end;
  end;

  //读取当前子窗体，并将结果合并
  tmpHWND:=GetWindow(Handle,GW_CHILD);
  while tmpHWND<>0 do begin
    child:=TMR_Window(FChildren.Get(tmpHWND));
    if child<>nil then begin
      child.FStatus:=wsPersist;
    end else begin
      child:=TMR_Window.Create;
      with child do begin
        FHandle:=tmpHWND;
        FParent:=Self;
        FStatus:=wsNew;
      end;
      FChildren.Add(tmpHWND,child);
    end;
    //child其他属性
    child.FName:=TMR_Window.GetWindowText(tmpHWND);
    child.FClassName:=TMR_Window.GetClassName(tmpHWND);
    with TMR_Window.GetWindowInfo(tmpHWND) do begin
      child.FWindowRect:=rcWindow;
      child.FClientRect:=rcClient;
    end;
    //递归子窗体
    result:=result+child.UpdateChildren;
    tmpHWND:=GetNextWindow(tmpHWND,GW_HWNDNEXT);
  end;
end;

function TMR_Window.GetWindowByHWND(handle:HWND):TMR_Window;
var tmpHwndRec:PHwndRec;
begin
  result:=Self;
  if FHandle=handle then exit;
  result:=nil;
  tmpHwndRec:=FChildren.Branchs[handle mod _HwndList_Branch_Count_];
  while tmpHwndRec<>nil do begin
    if tmpHwndRec^.Handle=handle then begin
      result:=TMR_Window(tmpHwndRec^.Data);
      exit;
    end;
    tmpHwndRec:=tmpHwndRec^.NextRec;
  end;
end;

function TMR_Window.GetEnumerator:TMR_WindowEnumerator;
begin
  result:=TMR_WindowEnumerator.Create(Self);
end;

function WindowStatusToString(ws:TMR_WindowStatus):string;
begin
  case ws of
    wsNew:     result := 'new';
    wsDeleted: result := 'deleted';
    wsPersist: result := 'persist';
    else       result := 'unknown';
  end;
end;

function TMR_Window.GetJSON:TJSONData;
var tmpWindow:TMR_Window;
    tmpJSONArray:TJSONArray;
begin
  result:=TJSONObject.Create;
  TJSONObject(result).Strings['status']:=WindowStatusToString(FStatus);
  TJSONObject(result).Int64s['hwnd']:=FHandle;
  TJSONObject(result).Strings['name']:=FName;
  TJSONObject(result).Strings['class']:=FClassName;
  TJSONObject(result).Arrays['rect_window']:=TJSONArray.Create([FWindowRect.Left,FWindowRect.Top,FWindowRect.Right,FWindowRect.Bottom]);
  TJSONObject(result).Arrays['rect_client']:=TJSONArray.Create([FClientRect.Left,FClientRect.Top,FClientRect.Right,FClientRect.Bottom]);
  tmpJSONArray:=TJSONArray.Create;
  for tmpWindow in Self do tmpJSONArray.Add(tmpWindow.GetJSON);
  TJSONObject(result).Arrays['children']:=tmpJSONArray;
end;

constructor TMR_Window.Create;
var idx:integer;
begin
  inherited Create;
  for idx:=0 to _HwndList_Branch_Count_ - 1 do FChildren.Branchs[idx]:=nil;
end;

destructor TMR_Window.Destroy;
var idx:integer;
    tmp:PHwndRec;
begin
  for idx:=0 to _HwndList_Branch_Count_ - 1 do begin
    while FChildren.Branchs[idx]<>nil do begin
      tmp:=FChildren.Branchs[idx];
      FChildren.Branchs[idx]:=tmp^.NextRec;
      TMR_Window(tmp^.Data).Free;
      FreeMem(tmp,sizeof(THwndRec));
    end;
  end;
  inherited Destroy;
end;


{ TMR_ScreenList }

procedure TMR_ScreenList.UpdateScreens;
var idx:integer;
begin
  FVirtualScreenRect:=Classes.Rect(0,0,0,0);
  SetLength(FScreenList,0);
  SetLength(FScreenList,Screen.MonitorCount);
  for idx:=0 to Screen.MonitorCount-1 do begin
    //需要打开LCL Scaling和Per Monitor DPI awareness
    FScreenList[idx].ScreenRect:=Screen.Monitors[idx].BoundsRect;
    FScreenList[idx].dpi:=Screen.Monitors[idx].PixelsPerInch;
    FScreenList[idx].dpiScaling:=FScreenList[idx].dpi/96;
    FVirtualScreenRect:=FVirtualScreenRect+FScreenList[idx].ScreenRect;
  end;
end;

function TMR_ScreenList.VirtualScreenPosition(FormRect:TRect):TMR_VirtualScreenProportionalRect;
begin
  result.Top    := (FormRect.Top    - FVirtualScreenRect.Top)   / FVirtualScreenRect.Height;
  result.Left   := (FormRect.Left   - FVirtualScreenRect.Left)  / FVirtualScreenRect.Width;
  result.Width  :=  FormRect.Width  / FVirtualScreenRect.Width;
  result.Height :=  FormRect.Height / FVirtualScreenRect.Height;
end;

constructor TMR_ScreenList.Create;
begin
  inherited Create;
  FVirtualScreenRect:=Classes.Rect(0,0,0,0);
end;

destructor TMR_ScreenList.Destroy;
begin
  SetLength(FScreenList,0);
  inherited Destroy;
end;

function TMR_ScreenList.GetScreen(index:Integer):TMR_Screen;
begin
  result:=FScreenList[index];
end;

function TMR_ScreenList.GetScreenCount:Integer;
begin
  result:=Length(FScreenList);
end;



end.

