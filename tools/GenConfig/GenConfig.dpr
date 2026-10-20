program GenConfig;

{ Generates src\Config\DoxyPas.Config.Options.pas from resources\config\config.xml (+ config_pascal.xml).
  Replaces Doxygen's configgen.py. Usage: GenConfig <output.pas> <config.xml> [more.xml ...] }

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  System.Generics.Collections,
  System.RegularExpressions,
  Xml.XMLIntf,
  Xml.XMLDoc,
  Xml.xmldom,
  Xml.omnixmldom;

var
  Messages: TDictionary<string, string>;

function Attr(const ANode: IXMLNode; const AName: string): string;
begin
  if ANode.HasAttribute(AName) then
    Result := ANode.Attributes[AName]
  else
    Result := '';
end;

function Fmt(const AMsg: string; const AArgs: array of string): string;
var
  I: Integer;
begin
  Result := AMsg;
  for I := 0 to High(AArgs) do
    Result := Result.Replace('{' + I.ToString + '}', AArgs[I]);
end;

function WrapLine(const ALine: string; AWidth: Integer): TArray<string>;
var
  Cur, W: string;
  Res: TList<string>;
begin
  Res := TList<string>.Create;
  try
    Cur := '';
    // shortcut: greedy wrap on spaces only (Python's textwrap also splits long words); affects comments only
    for W in ALine.Split([' '], TStringSplitOptions.ExcludeEmpty) do
      if Cur = '' then
        Cur := W
      else if Length(Cur) + 1 + Length(W) <= AWidth then
        Cur := Cur + ' ' + W
      else
      begin
        Res.Add(Cur);
        Cur := W;
      end;
    if Cur <> '' then
      Res.Add(Cur);
    Result := Res.ToArray;
  finally
    Res.Free;
  end;
end;

{ Port of transformDocs() from configgen.py: option text -> comment lines of a Doxyfile template. }
function TransformDocs(const ADoc: string): TArray<string>;
var
  Doc, Line, L: string;
  Res: TList<string>;
begin
  Doc := Trim(ADoc);
  Doc := Doc.Replace(#13, ' ').Replace(#10, ' ').Replace(#9, ' ');
  Doc := Doc.Replace('\&', '&').Replace('(\c ', '(').Replace('\c ', ' ').Replace('\b ', ' ')
    .Replace('\e ', ' ').Replace('\$', '$').Replace('\#include ', '#include ')
    .Replace('\#undef ', '#undef ').Replace('\# ', '# ').Replace('-# ', #10' - ')
    .Replace(' - ', #10' - ').Replace('\sa ', #10 + Messages['seealsotxt'] + ' ')
    .Replace('\par ', #10).Replace('@note ', #10 + Messages['notetxt'] + ' ')
    .Replace('\note ', #10 + Messages['notetxt'] + ' ').Replace('\verbatim', #10)
    .Replace('\endverbatim', #10).Replace('<b>', '').Replace('</b>', '').Replace('<code>', '')
    .Replace('</code>', '').Replace('`', '').Replace('\<', '<').Replace('\>', '>')
    .Replace('\@', '@').Replace('\\', '\').Replace('@@', '@');
  Doc := TRegEx.Replace(Doc, '\\ref +[^ ]* +"\\ref"', '\REF');
  Doc := TRegEx.Replace(Doc, '\\ref +[^ ]* +"([^"]*)"', '$1');
  Doc := TRegEx.Replace(Doc, '\\ref +doxygen_usage', '"Doxygen usage"');
  Doc := TRegEx.Replace(Doc, '\\ref +extsearch', '"External Indexing and Searching"');
  Doc := TRegEx.Replace(Doc, '\\ref +layout', '"Changing the layout of pages"');
  Doc := TRegEx.Replace(Doc, '\\ref +external', '"Linking to external documentation"');
  Doc := TRegEx.Replace(Doc, '\\ref +doxygen_finetune', '"Fine-tuning the output"');
  Doc := TRegEx.Replace(Doc, '\\ref +formulas', '"Including formulas"');
  Doc := TRegEx.Replace(Doc, '\\ref ', ' ');
  Doc := Doc.Replace('\REF', '\ref');
  Doc := TRegEx.Replace(Doc, '<a +href="([^"]*)" *>([^<]*)</a>', '$2 (see: '#10'$1)');
  Doc := Doc.Replace('\f$\mbox{\LaTeX}\f$', 'LaTeX')
    .Replace('\f$2^{(16+\mbox{LOOKUP\_CACHE\_SIZE})}\f$', '2^(16+LOOKUP_CACHE_SIZE)')
    .Replace('\f$2^{16} = 65536\f$', '2^16=65536');
  Doc := TRegEx.Replace(Doc, ' +', ' ');
  Doc := Doc.Replace('<br>', #10'<br>'#10).Replace('<br/>', #10'<br/>'#10);
  Res := TList<string>.Create;
  try
    for Line in Doc.Split([#10]) do
    begin
      if Trim(Line) = '' then
        Continue;
      for L in WrapLine(Line, 78) do
        if Trim(L) <> '<br/>' then
          Res.Add(Trim(L).Replace('<br>', ''));
    end;
    Result := Res.ToArray;
  finally
    Res.Free;
  end;
end;

function ParseDocs(const ANode: IXMLNode): string;
var
  I: Integer;
  N: IXMLNode;
begin
  Result := '';
  for I := 0 to ANode.ChildNodes.Count - 1 do
  begin
    N := ANode.ChildNodes[I];
    case N.NodeType of
      ntText: Result := Result + Trim(N.Text);
      ntCData: Result := Result + N.Text.TrimRight([#13, #10, ' ']).TrimLeft([#13, #10]);
    end;
  end;
end;

function CollectDocs(const ANode: IXMLNode): string;
var
  I: Integer;
  F: string;
begin
  Result := '';
  for I := 0 to ANode.ChildNodes.Count - 1 do
    if ANode.ChildNodes[I].NodeName = 'docs' then
    begin
      F := Attr(ANode.ChildNodes[I], 'filter');
      if (F = '') or F.Contains('doxyfile') then
        Result := Result + ParseDocs(ANode.ChildNodes[I]);
    end;
end;

function ValueNames(const ANode: IXMLNode; ADocText: Boolean): TArray<string>;
var
  I: Integer;
  N: IXMLNode;
  List: TList<string>;
  S: string;
begin
  List := TList<string>.Create;
  try
    for I := 0 to ANode.ChildNodes.Count - 1 do
    begin
      N := ANode.ChildNodes[I];
      if (N.NodeName <> 'value') or (Attr(N, 'name') = '') then
        Continue;
      if ADocText then
      begin
        if Attr(N, 'show_docu') = 'NO' then
          Continue;
        S := '<code>' + Attr(N, 'name') + '</code>';
        if Attr(N, 'desc') <> '' then
          S := S + ' ' + Attr(N, 'desc');
        List.Add(S);
      end
      else
        List.Add(Attr(N, 'name'));
    end;
    Result := List.ToArray;
  finally
    List.Free;
  end;
end;

function JoinValues(const AValues: TArray<string>): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to High(AValues) do
    if I = High(AValues) - 1 then
      Result := Result + AValues[I] + Messages['andtxt']
    else if I = High(AValues) then
      Result := Result + AValues[I] + '.'
    else
      Result := Result + AValues[I] + ', ';
end;

{ Port of prepCDocs(). }
function OptionDocs(const ANode: IXMLNode): TArray<string>;
var
  Typ, Fm, Def, Doc, Abs: string;
begin
  Typ := Attr(ANode, 'type');
  Fm := Attr(ANode, 'format');
  Def := Attr(ANode, 'defval');
  Abs := Attr(ANode, 'abspath');
  Doc := '';
  if Typ <> 'obsolete' then
  begin
    Doc := CollectDocs(ANode);
    if Typ = 'enum' then
    begin
      Doc := Doc + '<br/>' + Messages['possible'] + JoinValues(ValueNames(ANode, True));
      if Def <> '' then
        Doc := Doc + '<br/>' + Fmt(Messages['defvalcode'], [Def]);
    end
    else if Typ = 'int' then
      Doc := Doc + '<br/>' + Fmt(Messages['minmaxdefcode'], [Attr(ANode, 'minval'), Attr(ANode, 'maxval'), Def])
    else if Typ = 'bool' then
    begin
      if Def = '1' then
        Doc := Doc + '<br/>' + Fmt(Messages['defvalcode'], ['YES'])
      else
        Doc := Doc + '<br/>' + Fmt(Messages['defvalcode'], ['NO']);
    end
    else if (Typ = 'list') and (Fm = 'string') then
      Doc := Doc + JoinValues(ValueNames(ANode, True))
    else if Typ = 'string' then
    begin
      if Fm = 'dir' then
      begin
        if Def <> '' then
          Doc := Doc + '<br/>' + Fmt(Messages['defdir'], [Def]);
      end
      else if (Fm = 'file') or (Fm = 'image') then
      begin
        if Fm = 'file' then
        begin
          if (Def <> '') and (Abs <> '1') then
            Doc := Doc + '<br/>' + Fmt(Messages['deffile'], [Def])
          else if Def <> '' then
            Doc := Doc + '<br/>' + Fmt(Messages['deffileabs'], [Def])
          else if Abs = '1' then
            Doc := Doc + '<br/>' + Messages['deffilefull'];
        end
        else
        begin
          if (Def <> '') and (Abs <> '1') then
            Doc := Doc + '<br/>' + Fmt(Messages['defimg'], [Def])
          else if Def <> '' then
            Doc := Doc + '<br/>' + Fmt(Messages['defimgabs'], [Def])
          else if Abs = '1' then
            Doc := Doc + '<br/>' + Messages['defimgfull'];
        end;
      end
      else if Def <> '' then
        Doc := Doc + '<br/>' + Fmt(Messages['defvalcode'], [Def]);
    end;
    if ANode.HasAttribute('depends') then
      Doc := Doc + '<br/>' + Fmt(Messages['depstxtref'],
        [Attr(ANode, 'depends').ToLower, Attr(ANode, 'depends').ToUpper]);
  end;
  Result := TransformDocs(Doc);
end;

function Q(const S: string): string;
begin
  Result := '''' + S.Replace('''', '''''') + '''';
end;

function QLines(const ALines: TArray<string>): string;
var
  I: Integer;
begin
  if Length(ALines) = 0 then
    Exit('''''');
  Result := '';
  for I := 0 to High(ALines) do
  begin
    if I > 0 then
      Result := Result + ' + #10 +'#13#10'      ';
    Result := Result + Q(ALines[I]);
  end;
end;

function KindName(const AType: string): string;
begin
  if AType = 'bool' then Result := 'okBool'
  else if AType = 'int' then Result := 'okInt'
  else if AType = 'string' then Result := 'okString'
  else if AType = 'enum' then Result := 'okEnum'
  else if AType = 'list' then Result := 'okList'
  else if AType = 'obsolete' then Result := 'okObsolete'
  else raise Exception.CreateFmt('Unknown option type "%s"', [AType]);
end;

function IntAttr(const ANode: IXMLNode; const AName: string): string;
begin
  Result := Attr(ANode, AName);
  if Result = '' then
    Result := '0';
end;

procedure Generate(const AOutput: string; const AInputs: TArray<string>);
var
  Doc: IXMLDocument;
  Root, G, O, N: IXMLNode;
  Res, Groups, Opts: TStringBuilder;
  GroupIdx, OptCount, I, J, F: Integer;
  Org, HDoc: string;
begin
  Res := TStringBuilder.Create;
  Groups := TStringBuilder.Create;
  Opts := TStringBuilder.Create;
  try
    GroupIdx := -1;
    OptCount := 0;
    HDoc := '';
    for F := 0 to High(AInputs) do
    begin
      Doc := NewXMLDocument;
      Doc.LoadFromFile(AInputs[F]);
      Root := Doc.DocumentElement;
      for I := 0 to Root.ChildNodes.Count - 1 do
      begin
        G := Root.ChildNodes[I];
        if G.NodeName = 'generator' then
          for J := 0 to G.ChildNodes.Count - 1 do
          begin
            N := G.ChildNodes[J];
            if N.NodeName = 'message' then
              Messages.AddOrSetValue(Attr(N, 'name'), N.Text);
          end
        else if G.NodeName = 'header' then
          HDoc := CollectDocs(G);
      end;
      for I := 0 to Root.ChildNodes.Count - 1 do
      begin
        G := Root.ChildNodes[I];
        if G.NodeName <> 'group' then
          Continue;
        Inc(GroupIdx);
        if GroupIdx > 0 then
          Groups.AppendLine(',');
        Groups.Append('    (Name: ' + Q(Attr(G, 'name')) + '; Docs: ' + Q(Attr(G, 'docs')) + ')');
        for J := 0 to G.ChildNodes.Count - 1 do
        begin
          O := G.ChildNodes[J];
          if O.NodeName <> 'option' then
            Continue;
          if Length(Attr(O, 'id')) > 23 then
            raise Exception.CreateFmt('Option name %s too long', [Attr(O, 'id')]);
          if OptCount > 0 then
            Opts.AppendLine(',');
          Inc(OptCount);
          Org := Attr(O, 'orgtype');
          if Org = '' then
            Org := 'bool';
          Opts.AppendLine('    (Name: ' + Q(Attr(O, 'id')) + ';');
          Opts.AppendLine('     Kind: ' + KindName(Attr(O, 'type')) + '; OrgKind: ' + KindName(Org) +
            '; Group: ' + GroupIdx.ToString + ';');
          Opts.AppendLine('     Format: ' + Q(Attr(O, 'format')) + '; Depends: ' + Q(Attr(O, 'depends')) + ';');
          Opts.AppendLine('     Default: ' + Q(Attr(O, 'defval')) + '; MinVal: ' + IntAttr(O, 'minval') +
            '; MaxVal: ' + IntAttr(O, 'maxval') + ';');
          Opts.AppendLine('     Values: ' + Q(string.Join('|', ValueNames(O, False))) + ';');
          Opts.Append('     Doc: ' + QLines(OptionDocs(O)) + ')');
        end;
      end;
    end;
    Res.AppendLine('unit DoxyPas.Config.Options;');
    Res.AppendLine;
    Res.AppendLine('{ WARNING: generated by tools\GenConfig from resources\config\*.xml. Do not edit; edit the XML and regenerate. }');
    Res.AppendLine;
    Res.AppendLine('interface');
    Res.AppendLine;
    Res.AppendLine('type');
    Res.AppendLine('  TOptionKind = (okBool, okInt, okString, okEnum, okList, okObsolete);');
    Res.AppendLine;
    Res.AppendLine('  /// <summary>Static description of one configuration option (from config.xml).</summary>');
    Res.AppendLine('  TOptionInfo = record');
    Res.AppendLine('    Name: string;');
    Res.AppendLine('    Kind: TOptionKind;');
    Res.AppendLine('    OrgKind: TOptionKind; // original kind of an obsolete option');
    Res.AppendLine('    Group: Integer;       // index into ConfigGroups');
    Res.AppendLine('    Format: string;       // string, file, dir, filedir, image or empty');
    Res.AppendLine('    Depends: string;');
    Res.AppendLine('    Default: string;      // bool: 1/0');
    Res.AppendLine('    MinVal, MaxVal: Integer;');
    Res.AppendLine('    Values: string;       // ''|'' separated: allowed enum values, or default list items');
    Res.AppendLine('    Doc: string;          // comment text, lines separated by #10');
    Res.AppendLine('  end;');
    Res.AppendLine;
    Res.AppendLine('  TGroupInfo = record');
    Res.AppendLine('    Name, Docs: string;');
    Res.AppendLine('  end;');
    Res.AppendLine;
    Res.AppendLine('const');
    Res.AppendLine('  ConfigGroupCount = ' + (GroupIdx + 1).ToString + ';');
    Res.AppendLine('  ConfigOptionCount = ' + OptCount.ToString + ';');
    Res.AppendLine;
    Res.AppendLine('  ConfigHeader =');
    Res.AppendLine('      ' + QLines(TransformDocs(HDoc)) + ';');
    Res.AppendLine;
    Res.AppendLine('  ConfigGroups: array[0..ConfigGroupCount - 1] of TGroupInfo = (');
    Res.AppendLine(Groups.ToString);
    Res.AppendLine('  );');
    Res.AppendLine;
    Res.AppendLine('  ConfigOptions: array[0..ConfigOptionCount - 1] of TOptionInfo = (');
    Res.AppendLine(Opts.ToString);
    Res.AppendLine('  );');
    Res.AppendLine;
    Res.AppendLine('implementation');
    Res.AppendLine;
    Res.AppendLine('end.');
    TFile.WriteAllText(AOutput, Res.ToString, TUTF8Encoding.Create(True));
    Writeln(Format('%s: %d groups, %d options', [AOutput, GroupIdx + 1, OptCount]));
  finally
    Opts.Free;
    Groups.Free;
    Res.Free;
  end;
end;

var
  Inputs: TArray<string>;
  I: Integer;
begin
  Messages := TDictionary<string, string>.Create;
  try
    try
      if ParamCount < 2 then
      begin
        Writeln('Usage: GenConfig <output.pas> <config.xml> [more.xml ...]');
        ExitCode := 1;
      end
      else
      begin
        DefaultDOMVendor := sOmniXmlVendor;
        SetLength(Inputs, ParamCount - 1);
        for I := 2 to ParamCount do
          Inputs[I - 2] := ParamStr(I);
        Generate(ParamStr(1), Inputs);
      end;
    except
      on E: Exception do
      begin
        Writeln(ErrOutput, E.ClassName, ': ', E.Message);
        ExitCode := 2;
      end;
    end;
  finally
    Messages.Free;
  end;
end.
