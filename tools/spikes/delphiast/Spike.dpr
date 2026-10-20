program Spike;

{$APPTYPE CONSOLE}

uses
  System.SysUtils, System.Classes, System.IOUtils, System.Diagnostics, System.Types,
  System.Generics.Collections,
  DelphiAST in '..\DelphiAST\Source\DelphiAST.pas',
  DelphiAST.Classes in '..\DelphiAST\Source\DelphiAST.Classes.pas',
  DelphiAST.Consts in '..\DelphiAST\Source\DelphiAST.Consts.pas',
  DelphiAST.SimpleParserEx in '..\DelphiAST\Source\DelphiAST.SimpleParserEx.pas',
  DelphiAST.Writer in '..\DelphiAST\Source\DelphiAST.Writer.pas',
  StringPool in '..\DelphiAST\Source\StringPool.pas',
  SimpleParser in '..\DelphiAST\Source\SimpleParser\SimpleParser.pas',
  SimpleParser.Lexer in '..\DelphiAST\Source\SimpleParser\SimpleParser.Lexer.pas',
  SimpleParser.Lexer.Types in '..\DelphiAST\Source\SimpleParser\SimpleParser.Lexer.Types.pas',
  SimpleParser.Types in '..\DelphiAST\Source\SimpleParser\SimpleParser.Types.pas';

type
  TIncl = class(TInterfacedObject, IIncludeHandler)
    Dir: string;
    constructor Create(const ADir: string);
    function GetIncludeFileContent(const ParentFileName, IncludeName: string;
      out Content: string; out FileName: string): Boolean;
  end;

constructor TIncl.Create(const ADir: string);
begin
  Dir := ADir;
end;

function TIncl.GetIncludeFileContent(const ParentFileName, IncludeName: string;
  out Content: string; out FileName: string): Boolean;
var
  F: string;
begin
  F := TPath.Combine(Dir, IncludeName);
  Result := TFile.Exists(F);
  if Result then
  begin
    FileName := F;
    Content := TFile.ReadAllText(F);
  end;
end;

procedure CountNodes(N: TSyntaxNode; var Count: Integer);
var
  C: TSyntaxNode;
begin
  Inc(Count);
  for C in N.ChildNodes do
    CountNodes(C, Count);
end;

var
  Files: TStringDynArray;
  F: string;
  Ok, Fail, Nodes, Cmts, N: Integer;
  SW: TStopwatch;
  Tree: TSyntaxNode;
  B: TPasSyntaxTreeBuilder;
  SS: TStringStream;
  IfaceOnly, Verbose: Boolean;
  Errs: TDictionary<string, Integer>;
  Msg: string;
  Pair: TPair<string, Integer>;
  Failed: TStringList;
  Bytes: Int64;
begin
  IfaceOnly := SameText(ParamStr(2), 'iface') or SameText(ParamStr(2), 'xml');
  Verbose := SameText(ParamStr(3), 'v');
  Files := TDirectory.GetFiles(ParamStr(1), '*.pas', TSearchOption.soAllDirectories);
  if SameText(ParamStr(4), 'fpc') then Files := TDirectory.GetFiles(ParamStr(1), '*.pp', TSearchOption.soAllDirectories) + Files;
  Errs := TDictionary<string, Integer>.Create;
  Failed := TStringList.Create;
  Ok := 0; Fail := 0; Nodes := 0; Cmts := 0; Bytes := 0;
  SW := TStopwatch.StartNew;
  for F in Files do
  begin
    Inc(Bytes, TFile.GetSize(F));
    B := TPasSyntaxTreeBuilder.Create;
    try
      B.InitDefinesDefinedByCompiler;
      if SameText(ParamStr(4), 'fpc') then begin B.AddDefine('FPC'); B.AddDefine('CPU64'); B.AddDefine('UNICODE'); end else B.AddDefine('MSWINDOWS');
      B.IncludeHandler := TIncl.Create(ExtractFilePath(F));
      B.InterfaceOnly := IfaceOnly;
      try
        SS := TStringStream.Create; SS.LoadFromFile(F); try Tree := B.Run(SS); finally SS.Free; end;
        try
          if SameText(ParamStr(2), 'xml') then Writeln(TSyntaxTreeWriter.ToXML(Tree, True));
          N := 0;
          CountNodes(Tree, N);
          Inc(Nodes, N);
          Inc(Cmts, B.Comments.Count);
        finally
          Tree.Free;
        end;
        Inc(Ok);
      except
        on E: Exception do
        begin
          Inc(Fail);
          Msg := E.ClassName + ': ' + Copy(E.Message, 1, 70);
          Failed.Add(F + ' -> ' + E.Message);
          if Errs.ContainsKey(Msg) then Errs[Msg] := Errs[Msg] + 1 else Errs.Add(Msg, 1);
        end;
      end;
    finally
      B.Free;
    end;
  end;
  SW.Stop;
  Writeln(Format('files=%d ok=%d fail=%d  nodes=%d comments=%d  %.1f MB in %d ms (%.1f MB/s)',
    [Length(Files), Ok, Fail, Nodes, Cmts, Bytes / 1048576, SW.ElapsedMilliseconds,
     (Bytes / 1048576) / (SW.ElapsedMilliseconds / 1000 + 0.0001)]));
  for Pair in Errs do
    Writeln(Format('  %4d x %s', [Pair.Value, Pair.Key]));
  if Verbose then
    Writeln(Failed.Text)
  else
    for N := 0 to Failed.Count - 1 do
      if N < 8 then Writeln('  ', Failed[N]);
end.
