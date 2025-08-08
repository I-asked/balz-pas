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
program balzcli;

uses BALZ, SysUtils, Classes, bufstream;

var
  InNam: string;

  Codec: TBALZCodec;

  IFs: TBufferedFileStream;
  OFs: TStream;
  TmpFs: TFileStream;
  TmpBuf: Array[0..65535] of Char;
  TmpNRd: Longint;

begin
  Codec := TBALZCodec.Create;

  if argc < 2 then
  begin
    WriteLn(StdErr,
      'BALZ - A ROLZ-based file compressor (Pascal port; licensed under 0BSD)' +
      sLineBreak + sLineBreak +
      'Usage:    ', argv[0],' command infile outfile' +
      sLineBreak + sLineBreak +
      'Commands:' + sLineBreak +
      '  c|cx  Compress (Normal|Maximum)' + sLineBreak +
      '  d     Decompress');

    Halt(1);
  end;

  if argc < 3 then
  begin
    InNam := GetTempFileName;

    TmpFs := TFileStream.Create(InNam, fmCreate);
    repeat
      TmpNRd := FileRead(StdInputHandle, TmpBuf, High(TmpBuf) + 1);
      if TmpNRd <= 0 then
        Break;
      TmpFs.Write(TmpBuf, TmpNRd);
    until false;
    TmpFs.Free;
  end
  else
    InNam := argv[2];

  IFs := TBufferedFileStream.Create(InNam, fmOpenRead);
  if argc < 4 then
    OFs := THandleStream.Create(StdOutputHandle)
  else
    OFs := TBufferedFileStream.Create(argv[3], fmCreate);

  case argv[1][0] of
  'c': begin
    WriteLn(StdErr, 'Compressing...');
    Codec.Compress(IFs, OFs, argv[1][1] = 'x');
  end;
  'd': begin
    WriteLn(StdErr, 'Decompressing...');
    Codec.Decompress(IFs, OFs);
  end
  else
    Halt(1);
  end;

  WriteLn(StdErr, IFs.Size, ' -> ', OFs.Position,
          ' (', Round(100 * (OFs.Position / IFs.Size)), '%)');

  IFs.Free;
  OFs.Free;

  if argc < 4 then
    FileFlush(StdOutputHandle);

  if argc < 3 then
    DeleteFile(InNam);
end.

