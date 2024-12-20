unit mr_wndview;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, ExtCtrls, Graphics, mr_windowlist;

const
  _WndViewColor_Screen_       = clLtGray;
  _WndViewColor_ScreenBorder_ = clNone;
  _WndViewColor_Window_       = clGray;
  _WndViewColor_WindowBorder_ = clBlack;
  _WndViewColor_Prompt_       = clBlack;


type
  TMR_WndView = class(TPanel)
  private
    PScreenList : TMR_ScreenList;
    PWindow     : TMR_Window;
  protected
    procedure Paint; override;
    procedure SetWindow(value:TMR_Window);
  public
    constructor Create(TheOwner:TComponent;TheScreenList:TMR_ScreenList);
    destructor Destroy;override;
    property Window:TMR_Window write SetWindow;
  end;

implementation

{ TMR_WndView }

procedure TMR_WndView.Paint;
var idx:integer;
    VsRect,WndRect,Intersection:TRect;
    PPRect:TMR_VirtualScreenProportionalRect;
    prompt:string;
begin
  if PWindow=nil then exit;
  Canvas.Brush.Color:=clDefault;
  Canvas.Brush.Style:=bsSolid;
  Canvas.Clear;

  Canvas.Pen.Color   := _WndViewColor_ScreenBorder_;
  Canvas.Brush.Color := _WndViewColor_Screen_;
  for idx:=PScreenList.ScreenCount-1 downto 0 do begin
    PPRect:=PScreenList.VirtualScreenPosition(PScreenList.Screens[idx].ScreenRect);
    Canvas.Rectangle(BoundsRect * PPRect);
  end;

  VsRect:=PScreenList.VirtualScreenRect;
  WndRect:=PWindow.WindowRect;
  Intersection:=VsRect * WndRect;
  PPRect:=PScreenList.VirtualScreenPosition(WndRect);
  if PPRect.Width*PPRect.Height=0 then begin
    prompt:='窗体过小';
  end else if Intersection.Width*Intersection.Height=0 then begin
    prompt:='在屏幕外';
    //应该不会有在屏幕外但是在虚拟屏幕内的吧
  end else prompt:='';
  Canvas.Brush.Color:=clDefault;
  if prompt='' then begin
    Canvas.Pen.Color   := _WndViewColor_WindowBorder_;
    Canvas.Brush.Color := _WndViewColor_Window_;
    Canvas.Rectangle(BoundsRect*PPRect);
  end else begin
    Canvas.Font.Color  := _WndViewColor_Prompt_;
    Canvas.Font.Bold   := true;
    Canvas.TextOut(Width div 2 - Canvas.TextWidth(prompt) div 2, Height div 2 - Canvas.TextHeight(prompt) div 2, prompt);
  end;

end;

procedure TMR_WndView.SetWindow(value:TMR_Window);
begin
  if PWindow = value then exit;
  PWindow:=value;
  Paint;
end;

constructor TMR_WndView.Create(TheOwner: TComponent;TheScreenList:TMR_ScreenList);
begin
  inherited Create(TheOwner);
  PScreenList:=TheScreenList;
  PWindow:=nil;
end;

destructor TMR_WndView.Destroy;
begin
  inherited Destroy;
end;


end.

