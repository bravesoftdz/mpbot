unit uQueue;

interface
uses
  Classes, SysUtils, StrUtils, SyncObjs, DateUtils, Math,
  clHTTPRequest,
  uDefs;

type
  TActionQueueAttr = record
    Name,
    Value: string;
  end;

  TActionQueueElm = class
  private
  public
    ID: int64;
    LogName: string;
    RoomID: integer;
    AType: TFieldAction;
    ActionDT: TDateTime;
    DeltaXP: integer;

    Attrs: array of TActionQueueAttr;

    constructor Create;
    destructor Destroy; override;

    procedure Clear;
    procedure AddAttr(AName, AValue: string); overload;
    procedure AddAttr(AName: string; AValue: int64); overload;
  end;

  TActionQueue = class
   private
     class var FInstance: TActionQueue;
     class constructor Create;
   protected
     FQuElm: array of TActionQueueElm;
   public
     OwnerID,
     CurrentXP,
     RollCounter: int64;

     class function GetInstance: TActionQueue;
     constructor Create;
     destructor Destroy; override;

     procedure Clear;
     function Add(ARoomID: integer; AID: int64; ALogName: string; AType: TFieldAction; ADeltaXP: integer = 0): TActionQueueElm;
     procedure Trunc(cnt: integer);
     function Count: integer;
     procedure FillFormData(vHttpRequest: TclHttpRequest);

     function StrStat: string;
     function GetItemsLog: string;
  end;

implementation

{ TActionQueue }

function TActionQueue.Add(ARoomID: integer; AID: int64; ALogName: string; AType: TFieldAction; ADeltaXP: integer): TActionQueueElm;
begin
  Result := TActionQueueElm.Create;
  Result.Clear;
  Result.ID := AID;
  Result.LogName := ALogName;
  Result.RoomID := ARoomID;
  Result.AType := AType;
  Result.DeltaXP := ADeltaXP;

  SetLength(FQuElm, length(FQuElm) + 1);
  FQuElm[Length(FQuElm) - 1] := Result;
end;

procedure TActionQueue.Clear;
var
  i: Integer;
begin
  for i := 0 to length(FQuElm) - 1 do
  try
    FQuElm[i].Free;
  except
  end;

  CurrentXP := 0;
  SetLength(FQuElm, 0);
end;

function TActionQueue.Count: integer;
begin
  Result := length(FQuElm);
end;

class constructor TActionQueue.Create;
begin
  FInstance := nil;
end;

constructor TActionQueue.Create;
begin
  inherited;

  OwnerID := 0;
  Clear;
end;

destructor TActionQueue.Destroy;
begin

  inherited;
end;

procedure TActionQueue.FillFormData(vHttpRequest: TclHttpRequest);
var
  i,
  j,
  ago: Integer;

procedure AddCached(indx: integer; name, value: string);
begin
  vHttpRequest.AddFormField(
    'cached[' + IntToStr(indx) + '][' + name + ']',
    value);
end;

begin
  for i := 0 to length(FQuElm) - 1 do
  begin
    if FQuElm[i].ActionDT <> 0 then
      ago := abs(SecondsBetween(Now, FQuElm[i].ActionDT))
    else
      ago := (length(FQuElm) - i) * 2;

    AddCached(i, 'vsemogutor_hash', '0');
    if FQuElm[i].ID <> 0 then
      AddCached(i, 'item_id', IntToStr(FQuElm[i].ID));
    AddCached(i, 'user_id', IntToStr(OwnerID));
    AddCached(i, 'room_id', IntToStr(FQuElm[i].RoomID));
    AddCached(i, 'ago', IntToStr(ago));
    AddCached(i, 'command', FA_STR[FQuElm[i].AType]);
    AddCached(i, 'roll_counter', IntToStr(RollCounter));
    AddCached(i, 'exp', IntToStr(CurrentXP));
    CurrentXP := CurrentXP + FQuElm[i].DeltaXP;

    for j := 0 to length(FQuElm[i].Attrs) - 1 do
      AddCached(
        i,
        FQuElm[i].Attrs[j].Name,
        FQuElm[i].Attrs[j].Value);
  end;
end;

class function TActionQueue.GetInstance: TActionQueue;
begin
  if not Assigned(FInstance) then
    FInstance := TActionQueue.Create;
  Result := FInstance;
end;

function TActionQueue.GetItemsLog: string;
var
  sl: TStringList;
  indx,
  i: Integer;
begin
  Result := '';
  sl := TStringList.Create;
  try
    for i := 0 to length(FQuElm) - 1 do
    begin
      indx := sl.IndexOf(FQuElm[i].LogName);
      if indx < 0 then
        sl.AddObject(FQuElm[i].LogName, TObject(1))
      else
        sl.Objects[indx] := TObject(integer(sl.Objects[indx]) + 1);
    end;

    if sl.Count < 13 then
    begin
      for i := 0 to sl.Count - 1 do
        if integer(sl.Objects[i]) < 2 then
          Result := Result + sl[i] + ','
        else
          Result := Result + sl[i] + ':' + IntToStr(integer(sl.Objects[i])) + ',';
    end
    else
    begin
      Result := 'items types: ' + IntToStr(sl.Count);
    end;

    Result := Copy(Result, 1, length(Result) - 1);
  finally
    sl.Free;
  end;
end;

function TActionQueue.StrStat: string;
var
  i: Integer;
  a: TFieldAction;
  cnt: array [faNone..faLast] of integer;
begin
  Result := '';

  for a := faNone to faLast do
    cnt[a] := 0;

  for i := 0 to length(FQuElm) - 1 do
    cnt[FQuElm[i].AType] := cnt[FQuElm[i].AType] + 1;

  for a := faNone to faLast do
    if cnt[a] <> 0 then
      Result := Result +
        FA_STR_STAT[a] + ':' + IntToStr(cnt[a]) + ', ';

  if Result <> '' then
  begin
    Result := Copy(Result, 1, length(Result) - 2);
    Result := '[' + Result + ']'
  end;
end;

procedure TActionQueue.Trunc(cnt: integer);
var
  i: integer;
begin
  for i := cnt to length(FQuElm) - 1 do
  try
    FQuElm[i].Free;
  except
  end;
  SetLength(FQuElm, min(cnt, length(FQuElm)));
end;

{ TActionQueueElm }

procedure TActionQueueElm.AddAttr(AName, AValue: string);
begin
  SetLength(Attrs, length(Attrs) + 1);
  Attrs[Length(Attrs) - 1].Name := AName;
  Attrs[Length(Attrs) - 1].Value := AValue;
end;

procedure TActionQueueElm.AddAttr(AName: string; AValue: int64);
begin
  AddAttr(AName, IntToStr(AValue));
end;

procedure TActionQueueElm.Clear;
begin
  ID := 0;
  LogName := '';
  RoomID := 0;
  AType := faNone;
  ActionDT := 0;
  DeltaXP := 0;

  SetLength(Attrs, 0);
end;

constructor TActionQueueElm.Create;
begin
  inherited;
  Clear;
end;

destructor TActionQueueElm.Destroy;
begin

  inherited;
end;

end.
