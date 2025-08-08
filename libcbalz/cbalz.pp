(*
  Permission to use, copy, modify, and/or distribute this software for
  any purpose with or without fee is hereby granted.

  THE SOFTWARE IS PROVIDED “AS IS” AND THE AUTHOR DISCLAIMS ALL
  WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES
  OF MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE
  FOR ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY
  DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN
  AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT
  OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
*)
library cbalz;

{$mode ObjFPC}{$H+}
{$modeswitch advancedrecords}

uses BALZ, ctypes, SysUtils, Classes;

var
  Codec: TBALZCodec;

type
  TCBALZContext = record
    OutStr, InpStr: TCustomMemoryStream;
  end;
  PCBALZContext = ^TCBALZContext;

  TUserMemoryStream = class(TCustomMemoryStream)
  public
    constructor Create(P: Pointer; ASize: PtrUInt);
  end;

(*
function CBALZCompress(InBuf: pcuint8; NumIn: cuint64; Max: cbool; out OutBuf: pcuint8; out NumOut : cint64; out Error: pchar): PCBALZContext; cdecl; { public name 'balz_compress'; }

function CBALZDecompress(InBuf: pcuint8; NumIn: cuint64; out OutBuf: pcuint8; out NumOut : cint64; out Error: pchar): PCBALZContext; cdecl; { public name 'balz_decompress'; }

procedure CBALZFreeContext(Context: PCBALZContext); cdecl; { public name 'balz_free'; }
*)

constructor TUserMemoryStream.Create(P: Pointer; ASize: PtrUInt);
begin
  inherited Create;
  SetPointer(P, ASize);
end;

procedure CBALZFreeContext(Context: PCBALZContext); cdecl;
begin
  Context^.InpStr.Free;
  Context^.OutStr.Free;

  Dispose(Context);
end;

function CBALZCompress(InBuf: pcuint8; NumIn: cuint64; Max: cbool; out OutBuf: pcuint8; out NumOut: cint64; out Error: pchar): PCBALZContext; cdecl;
begin
  New(CBALZCompress);
  CBALZCompress^.InpStr := TUserMemoryStream.Create(InBuf, NumIn);
  CBALZCompress^.OutStr := TMemoryStream.Create;

  Error := nil;
  try
    Codec.Compress(CBALZCompress^.InpStr, CBALZCompress^.OutStr, Max);
  except
    on E: Exception do Error := pchar(E.Message);
  end;

  NumOut := CBALZCompress^.OutStr.Position;
  OutBuf := CBALZCompress^.OutStr.Memory;
end;

function CBALZDecompress(InBuf: pcuint8; NumIn: cuint64; out OutBuf: pcuint8; out NumOut: cint64; out Error: pchar): PCBALZContext; cdecl;
begin
  New(CBALZDecompress);
  CBALZDecompress^.InpStr := TUserMemoryStream.Create(InBuf, NumIn);
  CBALZDecompress^.OutStr := TMemoryStream.Create;

  Error := nil;
  try
    Codec.Decompress(CBALZDecompress^.InpStr, CBALZDecompress^.OutStr);
  except
    on E: Exception do Error := pchar(E.Message);
  end;
  NumOut := CBALZDecompress^.OutStr.Position;
  OutBuf := CBALZDecompress^.OutStr.Memory;
end;

exports
  CBALZCompress name 'balz_compress',
  CBALZDecompress name 'balz_decompress',
  CBALZFreeContext name 'balz_free';

begin
  Codec := TBALZCodec.Create;
end.

