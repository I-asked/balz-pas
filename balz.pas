(*
  BALZ is based on the original work by Ilya Muravyov,
  placed in the Public Domain.

  Alternatively, you can use the 0BSD license for this
  implementation in Free Pascal.
*)
unit BALZ;

{$mode ObjFPC}{$H+}
{$modeswitch advancedrecords}

interface

uses
  Classes, SysUtils;

type
  TBALZCounter = class
  public
    P1, P2: Word;
  public
    constructor Create;

    procedure Update0; inline;
    procedure Update1; inline;

    function GetP: Longword; inline;
    property P: Longword read GetP;
  end;

  TBALZCodec = class
  private
    Buf : array[0..(1 shl 25)-1] of byte;
    Tab : array[0..(1 shl 16)-1, 0..(1 shl 7)-1] of Longword;
    Cnt : array[0..(1 shl 16)-1] of Longint;
    Counter1 : array[0..255, 0..511] of TBALZCounter;
    Counter2 : array[0..255, 0..(1 shl 7)-1] of TBALZCounter;
    Lo, Hi, Code : LongWord;
  private
    procedure E8E9Xform(N: Longint; Fwd: Boolean);
    function GetHash(P: Longint): Longword; inline;
    function GetPtsAt(P, N: Longint): Longint;
    procedure Flush(OStr: TStream); inline;
    procedure Encode(OStr: TStream; Bit: Boolean; Counter: TBALZCounter); inline; overload;
    procedure Encode(OStr: TStream; T, C1: Longint); inline; overload;
    procedure EncodeIdx(OStr: TStream; X, C2: Longint); inline;
    function Decode(IStr: TStream; Counter: TBALZCounter): Boolean; inline; overload;
    function Decode(IStr: TStream; C1: Longint): Longint; inline; overload;
    function DecodeIdx(IStr: TStream; C2: Longint): Longint; inline;
  public
    constructor Create;
    procedure Compress(Inp, Outp: TStream; Max: Boolean);
    procedure Decompress(Inp, Outp: TStream);
  end;

implementation

constructor TBALZCounter.Create;
begin
  P1 := 1 shl 15; P2 := 1 shl 15;
end;

procedure TBALZCounter.Update0;
begin
  Dec(P1, P1 shr 3);
  Dec(P2, P2 shr 6);
end;

procedure TBALZCounter.Update1;
begin
  Inc(P1, (P1 xor 65535) shr 3);
  Inc(P2, (P2 xor 65535) shr 6);
end;

function TBALZCounter.GetP: Longword;
begin
  GetP := P1 + P2;
end;

type
  TTab = array[0..(1 shl 16)-1, 0..(1 shl 7)-1] of Longword;

const
  BALZ_MAGIC = $BA;

  BUF_BITS = 25;
  BUF_SIZE = 1 shl BUF_BITS;
  BUF_MASK = BUF_SIZE - 1;

  TAB_BITS = 7;
  TAB_SIZE = 1 shl TAB_BITS;
  TAB_MASK = TAB_SIZE - 1;

  MIN_MATCH = 3;
  MAX_MATCH = 255 + MIN_MATCH;

constructor TBALZCodec.Create;
begin
end;

procedure TBALZCodec.E8E9Xform(N: Longint; Fwd: Boolean);
var
  EndI, P: Longint;
  Addr: PLongint;
begin
  EndI := N - 8;
  P := 0;

  repeat
    if PLongint(@Buf[P])^ = $4550 then
      Break;

    Inc(P);
  until P >= EndI;

  while P < EndI do
  begin
    Inc(P);
    if (Buf[P - 1] and 254) = $E8 then
    begin
      Addr := PLongint(@Buf[P]);
      if Fwd then
      begin
        if (Addr^ >= (-P)) and (Addr^ < (N - P)) then
          Inc(Addr^, P)
        else if (Addr^ > 0) and (Addr^ < N) then
          Dec(Addr^, N);
      end
      else
      begin
        if Addr^ < 0 then
        begin
          if (Addr^ + P) >= 0 then
            Inc(Addr^, N);
        end
        else if Addr^ < N then
          Dec(Addr^, P);
      end;
      Inc(P, 4);
    end;
  end;
end;

function TBALZCodec.GetHash(P: Longint): Longword;
begin
  GetHash := ((PLongword(@Buf[P])^ and $FFFFFF) * UInt64(2654435769)) and not(BUF_MASK);
end;

function GetPts(Len, X: Longint): Longint; inline;
begin
  if Len >= MIN_MATCH then
    GetPts := (Len shl TAB_BITS) - X
  else
    GetPts := ((MIN_MATCH - 1) shl TAB_BITS) - 8;
end;

function TBALZCodec.GetPtsAt(P, N: Longint): Longint;
var
  X, S, L, C2, Len, Idx, MaxMatch: Longint;
  D, Hash: Longword;
begin
  C2 := PWord(@Buf[P - 2])^;
  Hash := GetHash(P);

  Len := MIN_MATCH - 1;
  Idx := TAB_SIZE;

  MaxMatch := N - P;
  if MaxMatch > MAX_MATCH then
    MaxMatch := MAX_MATCH;

  for X := 0 to TAB_SIZE - 1 do
  begin
    D := Tab[C2, (Cnt[C2] - X) and TAB_MASK];
    if D = 0 then
      Break;

    if (D and not(BUF_MASK)) <> Hash then
      Continue;

    S := D and BUF_MASK;
    if (Buf[S + Len] <> Buf[P + Len]) or (Buf[S] <> Buf[P]) then
      Continue;

    L := 1;
    while L < MaxMatch do
    begin
      if Buf[S + L] <> Buf[P + L] then
        Break;
      Inc(L);
    end;

    if L > Len then
    begin
      Idx := X;
      Len := L;
      if L = MaxMatch then
        Break;
    end;
  end;

  GetPtsAt := GetPts(Len, Idx);
end;

procedure TBALZCodec.Flush(OStr: TStream);
var
  I: Longint;
begin
  for I := 0 to 3 do
  begin
    OStr.WriteByte(Lo shr 24);
    Lo := Lo shl 8;
  end;
end;

procedure TBALZCodec.Encode(OStr: TStream; Bit: Boolean; Counter: TBALZCounter);
var
  Mid: Longword;
begin
  Mid := Lo + ((UInt64(Hi - Lo) * (Counter.P shl 15)) shr 32);

  if Bit then
  begin
    Hi := Mid;
    counter.Update1;
  end
  else
  begin
    Lo := Mid + 1;
    counter.Update0;
  end;

  while (Lo xor Hi) < (1 shl 24) do
  begin
    OStr.WriteByte(Lo shr 24);
    Lo := Lo shl 8;
    Hi := (Hi shl 8) or 255;
  end;
end;

procedure TBALZCodec.Encode(OStr: TStream; T, C1: Longint);
var
  Ctx: Longint;
  Bit: Boolean;
begin
  Ctx := 1;
  while Ctx < 512 do
  begin
    Bit := (T and 256) <> 0;
    Inc(T, T);
    Encode(OStr, Bit, Counter1[C1, Ctx]);
    Inc(Ctx, Ctx + Longint(Bit));
  end;
end;

procedure TBALZCodec.EncodeIdx(OStr: TStream; X, C2: Longint);
var
  Ctx: Longint;
  Bit: Boolean;
begin
  Ctx := 1;
  while Ctx < TAB_SIZE do
  begin
    Bit := (X and (TAB_SIZE shr 1)) <> 0;
    Inc(X, X);
    Encode(OStr, Bit, Counter2[C2, Ctx]);
    Inc(Ctx, Ctx + Longint(Bit));
  end;
end;

procedure TBALZCodec.Compress(Inp, Outp: TStream; Max: Boolean);
var
  BestIdx: array[0..MAX_MATCH] of Longint;
  FLen: Int64;
  I, J, N, P, C2, Len, Idx, MaxMatch, X, S, L, Sum, Tmp: Longint;
  Hash, D: Longword;
begin
  Code := 0;
  Lo := 0;
  Hi := $FFFFFFFF;

  Initialize(BestIdx);
  Initialize(Cnt);
  Initialize(Buf);
  Initialize(Tab);

  for I := Low(Counter1) to High(Counter1) do
    for J := Low(Counter1[I]) to High(Counter1[I]) do
      Counter1[I][J] := TBALZCounter.Create;

  for I := Low(Counter2) to High(Counter2) do
    for J := Low(Counter2[I]) to High(Counter2[I]) do
      Counter2[I][J] := TBALZCounter.Create;

  Outp.WriteByte(BALZ_MAGIC);

  FLen := Inp.Size;
  Outp.WriteQWord(NtoLE(Int64(FLen)));

  repeat
    N := Inp.Read(Buf, BUF_SIZE);
    if N <= 0 then
      Break;

    E8E9Xform(N, True);

    Tab := default(TTab);

    P := 0;

    while (P < 2) and (P < N) do
    begin
      Encode(Outp, Buf[P], 0);
      Inc(P);
    end;

    while P < N do
    begin
      C2 := PWord(@Buf[P - 2])^;
      Hash := GetHash(P);

      Len := MIN_MATCH - 1;
      Idx := TAB_SIZE;

      MaxMatch := N - P;
      if MaxMatch > MAX_MATCH then
        MaxMatch := MAX_MATCH;

      for X := 0 to TAB_SIZE - 1 do
      begin
        D := Tab[C2, (Cnt[C2] - X) and TAB_MASK];
        if D = 0 then
          Break;

        if (D and not(BUF_MASK)) <> Hash then
          Continue;

        S := D and BUF_MASK;
        if (Buf[S + Len] <> Buf[P + Len]) or (Buf[S] <> Buf[P]) then
          Continue;

        L := 1;
        while L < MaxMatch do
        begin
          if Buf[S + L] <> Buf[P + L] then
            Break;
          Inc(L);
        end;

        if L > Len then
        begin
          for J := L downto Len + 1 do
            BestIdx[J] := X;
          J := Len;

          Idx := X;
          Len := L;
          if L = MaxMatch then
            Break;
        end;
      end;

      if Max and (Len >= MIN_MATCH) then
      begin
        Sum := GetPts(Len, Idx) + GetPtsAt(P + Len, N);

        if Sum < GetPts(Len + MAX_MATCH, 0) then
        begin
          for J := 1 to Len - 1 do
          begin
            Tmp := GetPts(J, BestIdx[J]) + GetPtsAt(P + J, N);
            if Tmp > Sum then
            begin
              Sum := Tmp;
              Len := J;
            end;
          end;
          Idx := BestIdx[Len];
        end;
      end;

      Inc(Cnt[C2]);
      Tab[C2, Cnt[C2] and TAB_MASK] := Hash or P;

      if Len >= MIN_MATCH then
      begin
        Encode(Outp, (256 - MIN_MATCH) + Len, Buf[P - 1]);
        EncodeIdx(Outp, Idx, Buf[P - 2]);
        Inc(P, Len);
      end
      else
      begin
        Encode(Outp, Buf[P], Buf[P - 1]);
        Inc(P);
      end;
    end;
  until false;

  Flush(Outp);

  if Inp.Position <> FLen then
    raise Exception.Create('Size mismatch');
end;

function TBALZCodec.Decode(IStr: TStream; Counter: TBALZCounter): Boolean;
var
  Mid: Longword;
begin
  Mid := Lo + ((Uint64(Hi - Lo) * (Counter.P shl 15)) shr 32);
  Result := Code <= Mid;
  if Result then
  begin
    Hi := Mid;
    Counter.Update1;
  end
  else
  begin
    Lo := Mid + 1;
    Counter.Update0;
  end;

  while (Lo xor Hi) < (1 shl 24) do
  begin
    Code := (Code shl 8) or IStr.ReadByte;
    Lo := Lo shl 8;
    Hi := (Hi shl 8) or 255;
  end;
end;

function TBALZCodec.Decode(IStr: TStream; C1: Longint): Longint;
begin
  Result := 1;
  while Result < 512 do
    Inc(Result, Result + Longint(Decode(IStr, Counter1[C1, Result])));

  Dec(Result, 512);
end;

function TBALZCodec.DecodeIdx(IStr: TStream; C2: Longint): Longint;
begin
  Result := 1;
  while Result < TAB_SIZE do
    Inc(Result, Result + Longint(Decode(IStr, Counter2[C2, Result])));

  Dec(Result, TAB_SIZE);
end;

procedure TBALZCodec.Decompress(Inp, Outp: TStream);
var
  I, J, P, T, N, Tmp, C2, Len, S: Longint;
  FLen: Int64;
  FLenAry: array[0..7] of byte absolute FLen;
begin
  FLen := -1;
  Code := 0;
  Lo := 0;
  Hi := $FFFFFFFF;
  Initialize(Tab);
  Initialize(Cnt);
  Initialize(Counter1);
  Initialize(Counter2);

  for I := Low(Counter1) to High(Counter1) do
    for J := Low(Counter1[I]) to High(Counter1[I]) do
      Counter1[I][J] := TBALZCounter.Create;

  for I := Low(Counter2) to High(Counter2) do
    for J := Low(Counter2[I]) to High(Counter2[I]) do
      Counter2[I][J] := TBALZCounter.Create;

  if Inp.ReadByte <> BALZ_MAGIC then
    raise Exception.Create('Not a BALZ compressed file');

  N := Inp.Read(FLenAry, 8);
  FLen := LEtoN(FLen);
  if (N <> 8) or (FLen < 0) then
    raise Exception.Create('File corrupt');

  for I := 0 to 3 do
    Code := (Code shl 8) or Inp.ReadByte;

  while FLen > 0 do
  begin
    P := 0;

    while (P < 2) and (P < FLen) do
    begin
      T := Decode(Inp, 0);
      if T >= 256 then
        raise Exception.Create('File corrupt');
      Buf[P] := T;
      Inc(P);
    end;

    while (P < BUF_SIZE) and (P < FLen) do
    begin
      Tmp := P;
      C2 := PWord(@Buf[P - 2])^;

      T := Decode(Inp, Buf[P - 1]);
      if T >= 256 then
      begin
        Len := T - 256;
        S := Tab[C2, (Cnt[C2] - DecodeIdx(Inp, Buf[P - 2])) and TAB_MASK];

        Buf[P] := Buf[S];
        Inc(P); Inc(S);
        Buf[P] := Buf[S];
        Inc(P); Inc(S);
        Buf[P] := Buf[S];
        Inc(P); Inc(S);

        while Len <> 0 do
        begin
          Dec(Len);
          Buf[P] := Buf[S];
          Inc(P); Inc(S);
        end;
      end
      else
      begin
        Buf[P] := T;
        Inc(P);
      end;

      Inc(Cnt[C2]);
      Tab[C2, Cnt[C2] and TAB_MASK] := Tmp;
    end;

    E8E9Xform(P, False);

    Outp.Write(Buf, P);

    Dec(FLen, P);
  end;
end;

end.

