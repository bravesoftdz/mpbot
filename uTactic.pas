unit uTactic;

interface
uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  StrUtils,
  uDefs, uLogger, uGameItems;

type
  TMTactic = class
  private
    FWorld: TMWorld;
    FRoom: TMRoom;
  public
    constructor Create;
    destructor Destroy; override;

    procedure Clear; virtual;

    function CanExecuteContract(Field: TMField; Contract: TMGameItem; Exec: boolean = false): boolean; virtual;
    function ExecuteContract(Field: TMField; Contract: TMGameItem): boolean; virtual;
    function CanPickContract(Field: TMField; Contract: TMGameItem; Exec: boolean = false): boolean; virtual;
    function PickContract(Field: TMField; Contract: TMGameItem): boolean; virtual;
    function SelectContract(Field: TMField; ContractList: string): TMGameItem; virtual;
  end;

  TMRoom1Tactic = class (TMTactic)
  private
    function CheckResourcesCapacity(Contract: TMGameItem): boolean;
  public
    function CanExecuteContract(Field: TMField; Contract: TMGameItem; Exec: boolean = false): boolean; override;
    function CanPickContract(Field: TMField; Contract: TMGameItem; Exec: boolean = false): boolean; override;
  end;

  TMRoom2Tactic = class (TMTactic)
  private
    function GetFutureResourcesCount(ResName, ResMaxName: string; ToDT: TDateTime): integer;
  public
    function CanExecuteContract(Field: TMField; Contract: TMGameItem; Exec: boolean = false): boolean; override;
    function CanPickContract(Field: TMField; Contract: TMGameItem; Exec: boolean = false): boolean; override;
  end;

implementation
uses
  uFactories;

{ TMTactic }

function TMTactic.CanExecuteContract(Field: TMField; Contract: TMGameItem; Exec: boolean = false): boolean;
begin
  Result := true;
end;

function TMTactic.CanPickContract(Field: TMField; Contract: TMGameItem; Exec: boolean = false): boolean;
begin
  Result := true;
end;

procedure TMTactic.Clear;
begin

end;

constructor TMTactic.Create;
begin
  inherited;

  FWorld := nil;
  FRoom := nil;
  Clear;
end;

destructor TMTactic.Destroy;
begin

  inherited
end;

function TMTactic.ExecuteContract(Field: TMField;
  Contract: TMGameItem): boolean;
begin
  Result := CanExecuteContract(Field, Contract, true);
end;

function TMTactic.PickContract(Field: TMField; Contract: TMGameItem): boolean;
begin
  Result := CanPickContract(Field, Contract, true);
end;

function TMTactic.SelectContract(Field: TMField;
  ContractList: string): TMGameItem;
begin
  Result := nil;
  if ContractList = '' then exit;

  if Pos(',', ContractList) > 0 then
   Result := TItemsFactory.GetInstance.GetGameItem(Copy(ContractList, 1, Pos(',', ContractList) - 1))
  else
   Result := TItemsFactory.GetInstance.GetGameItem(ContractList);
end;

{ TMRoom1Tactic }

function TMRoom1Tactic.CanExecuteContract(Field: TMField; Contract: TMGameItem; Exec: boolean = false): boolean;
var
  FuelNeeded: integer;
begin
  Result := false;
  if Contract = nil then exit;

  FWorld := TMWorld.GetInstance;
  FRoom := FWorld.GetRoom(1);
  if (FRoom = nil) or (not FRoom.Avaliable) then exit;

  if not CheckResourcesCapacity(Contract) then exit;

  // ����� ������� ��� ���������
  FuelNeeded := Contract.GetAllStatesParamInt(
      'put',
      'fuel') * -1; // was < 0 !!!
  if FuelNeeded > StrToIntDef(FRoom.Header.GetRoomResource('fuel'), 0) then exit;

  if Exec then
  begin
    FRoom.Header.DecRoomResource('fuel', FuelNeeded);
  end;

  Result := true;
end;

function TMRoom1Tactic.CanPickContract(Field: TMField; Contract: TMGameItem; Exec: boolean = false): boolean;
var
  ProduceMaterial: string;
  IncResCnt: integer;
begin
  Result := false;
  if Contract = nil then exit;

  FWorld := TMWorld.GetInstance;
  FRoom := FWorld.GetRoom(1);
  if (FRoom = nil) or (not FRoom.Avaliable) then exit;

  Result := CheckResourcesCapacity(Contract);

  if Exec then
  begin
    ProduceMaterial := Contract.GetAttr('produce_material').AsString;
    if ProduceMaterial <> '' then
    begin
      IncResCnt := Contract.GetAllStatesParamInt(
        'pick',
        ProduceMaterial);
      FWorld.IncBarnRes(FWorld.GetBarnGameItemID(ProduceMaterial), IncResCnt)
    end;
  end;
end;

function TMRoom1Tactic.CheckResourcesCapacity(Contract: TMGameItem): boolean;
var
  ResourcesCapacity,
  ResourcesCount,
  ResourcesNeeded: integer;
  StorageField: TMField;
begin
  Result := false;

  // ������ ������
  StorageField := FRoom.GetField('mining_storage');
  if (StorageField = nil) or
     (StorageField.GameItem = nil) or
     (not (StorageField is TMFieldMiningStorage)) then exit;

  ResourcesCapacity := (StorageField as TMFieldMiningStorage).Capacity;
  if ResourcesCapacity <= 0 then exit;

  // ���������� �������� �� ������
  ResourcesCount := (StorageField as TMFieldMiningStorage).ResourcesCount;

  // ���������� �������� �������� ����� ���������� ���������
  ResourcesNeeded := Contract.GetAllStatesParamInt(
      'pick',
      'mining_resources_capacity'); // was < 0 !!!
  if ResourcesCapacity - ResourcesCount + ResourcesNeeded < 0 then exit;

  Result := true;
end;

{ TMRoom2Tactic }

function TMRoom2Tactic.CanExecuteContract(Field: TMField; Contract: TMGameItem; Exec: boolean = false): boolean;
var
  To�rists,
  To�ristsVIP,
  To�ristsNeeded,
  To�ristsVIPNeeded: integer;
begin
  Result := false;
  if Contract = nil then exit;

  FWorld := TMWorld.GetInstance;
  FRoom := FWorld.GetRoom(2);
  if (FRoom = nil) or (not FRoom.Avaliable) then exit;

  // ��������� ����� �������
  if (Pos('aquapark_', Field.Name) = 1) or
     (Pos('ancient_fort_', Field.Name) = 1)then
  begin
    // ����� �������� ��� ���������
    To�ristsNeeded := Contract.GetAllStatesParamInt(
        'put',
        'tourists') * -1; // was < 0 !!!
    To�ristsVIPNeeded := Contract.GetAllStatesParamInt(
        'put',
        'vip_tourists') * -1; // was < 0 !!!

    if (To�ristsNeeded > StrToIntDef(FRoom.Header.GetRoomResource('tourists'), 0)) or
       (To�ristsVIPNeeded > StrToIntDef(FRoom.Header.GetRoomResource('vip_tourists'), 0))
    then exit;

    if Exec then
    begin
      FRoom.Header.DecRoomResource('tourists', To�ristsNeeded);
      FRoom.Header.DecRoomResource('vip_tourists', To�ristsVIPNeeded);
    end;
  end;

  // ��������� ����� �������
  if (Pos('marine_terminal_', Field.Name) = 1) or
     (Pos('island_airport_', Field.Name) = 1) then
  begin
    // ��������� ����� �� � ���� ������� ��� ���������� �������� ����� ���������� ������ ����
//    Field.GetIterationsCount;


    // �������� - �������� �� ������� ������
    To�rists := Contract.GetAllStatesParamInt(
        'pick',
        'tourists');
    To�ristsVIP := Contract.GetAllStatesParamInt(
        'pick',
        'vip_tourists');

    if (To�rists + StrToIntDef(FRoom.Header.GetRoomResource('tourists'), 0) >
            StrToIntDef(FRoom.Header.GetRoomResource('tourist_capacity'), 0) + 20) or
       (To�ristsVIP + StrToIntDef(FRoom.Header.GetRoomResource('vip_tourists'), 0) >
            StrToIntDef(FRoom.Header.GetRoomResource('vip_tourist_capacity'), 0) + 20)
    then exit;
  end;

  Result := true;
end;

function TMRoom2Tactic.CanPickContract(Field: TMField;
  Contract: TMGameItem; Exec: boolean = false): boolean;
var
  To�rists,
  To�ristsVIP,
  exp: integer;
begin
  Result := false;
  if Contract = nil then exit;

  FWorld := TMWorld.GetInstance;
  FRoom := FWorld.GetRoom(2);
  if (FRoom = nil) or (not FRoom.Avaliable) then exit;

  // ��������� ����� �������
  if (Pos('marine_terminal_', Field.Name) = 1) or
     (Pos('island_airport_', Field.Name) = 1) then
  begin
    // �������� ������� ��������
    To�rists := Contract.GetAllStatesParamInt(
        'pick',
        'tourists');
    To�ristsVIP := Contract.GetAllStatesParamInt(
        'pick',
        'vip_tourists');

    if (To�rists + StrToIntDef(FRoom.Header.GetRoomResource('tourists'), 0) >
            StrToIntDef(FRoom.Header.GetRoomResource('tourist_capacity'), 0) + 20) or
       (To�ristsVIP + StrToIntDef(FRoom.Header.GetRoomResource('vip_tourists'), 0) >
            StrToIntDef(FRoom.Header.GetRoomResource('vip_tourist_capacity'), 0) + 20)
    then exit;

    if Exec then
    begin
      FRoom.Header.IncRoomResource('tourists', To�rists);
      FRoom.Header.IncRoomResource('vip_tourists', To�ristsVIP);

      exp := Contract.GetAllStatesParamInt(
          'pick',
          'exp');
      if exp > 1 then Contract.SetAttr('exp', exp);
    end;
  end;

  Result := true;
end;

function TMRoom2Tactic.GetFutureResourcesCount(ResName, ResMaxName: string;
  ToDT: TDateTime): integer;
var
  field: TMField;
  ResCount,
  ResMax,
  ResSub,
  ResAdd: integer;
begin
  ResCount := StrToIntDef(FRoom.Header.GetRoomResource(ResName), 0);
  ResMax := StrToIntDef(FRoom.Header.GetRoomResource(ResMaxName), 0);

  Result := ResCount;
  // ��������� ����� �������
  field := FRoom.GetField('aquapark_');
  if (field is TMFieldFactory) and
     ((field as TMFieldFactory).PutGameItem <> nil)  // ����� ��� �������� contractoutput?
  then
  begin
    ResSub := (field as TMFieldFactory).PutGameItem.GetAllStatesParamInt(
        'put',
        ResName);   // <0
    ResAdd := (field as TMFieldFactory).PutGameItem.GetAllStatesParamInt(
        'pick',
        ResName);

    Result := Result + field.GetIterationsCount(ToDT, 60) * (ResSub + ResAdd);
  end;

  if (ResMax > 0) and (Result > ResMax) then Result := ResMax;


end;
       {

  if (Pos('aquapark_', Field.Name) = 1) or
     (Pos('ancient_fort_', Field.Name) = 1)then
  begin
    ResSub := Contract.GetAllStatesParamInt(
        'put',
        ResName) * -1;
    ResAdd := Contract.GetAllStatesParamInt(
        'pick',
        ResName);

    then exit;

    if Exec then
    begin
      FRoom.Header.DecRoomResource('tourists', To�ristsNeeded);
      FRoom.Header.DecRoomResource('vip_tourists', To�ristsVIPNeeded);
    end;
  end;

  // ��������� ����� �������
  if (Pos('marine_terminal_', Field.Name) = 1) or
     (Pos('island_airport_', Field.Name) = 1) then
  begin
    // ��������� ����� �� � ���� ������� ��� ���������� �������� ����� ���������� ������ ����
//    Field.GetIterationsCount;


    // �������� - �������� �� ������� ������
    To�rists := Contract.GetAllStatesParamInt(
        'pick',
        'tourists');
    To�ristsVIP := Contract.GetAllStatesParamInt(
        'pick',
        'vip_tourists');

    if (To�rists + StrToIntDef(FRoom.Header.GetRoomResource('tourists'), 0) >
            StrToIntDef(FRoom.Header.GetRoomResource('tourist_capacity'), 0) + 20) or
       (To�ristsVIP + StrToIntDef(FRoom.Header.GetRoomResource('vip_tourists'), 0) >
            StrToIntDef(FRoom.Header.GetRoomResource('vip_tourist_capacity'), 0) + 20)

end;      }

end.
