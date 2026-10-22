unit DoxyPas.Output.TagFile;

{ Tag files (Doxygen's GENERATE_TAGFILE and TAGFILES): a list of the compounds and members of a project with the
  file and anchor that document them, so that other projects can link to it. }

interface

uses
  DoxyPas.Model.Project;

/// <summary>Writes the tag file of AProject (visible and documented classes, units, groups, pages).</summary>
procedure WriteTagFile(AProject: TProject; const AFileName: string);

/// <summary>Reads one tag file into AProject.Externals; ALocation is the url or directory of the documentation
/// it describes (may be empty). Returns the number of symbols found.</summary>
function ReadTagFile(AProject: TProject; const AFileName, ALocation: string): Integer;

/// <summary>Reads every "file[=location]" entry of the TAGFILES option.</summary>
procedure ReadTagFiles(AProject: TProject; const AEntries: TArray<string>);

implementation

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  System.Variants,
  System.Generics.Collections,
  Xml.XMLIntf,
  Xml.XMLDoc,
  Xml.xmldom,
  Xml.omnixmldom,
  DoxyPas.Core.Version,
  DoxyPas.Model.Entry,
  DoxyPas.Model.Defs,
  DoxyPas.Model.Links,
  DoxyPas.Output.XmlWriter;

function MemberKind(M: TMemberDef): string;
begin
  case M.Kind of
    memFunction: Result := 'function';
    memProperty: Result := 'property';
    memTypedef: Result := 'typedef';
    memEnumeration: Result := 'enumeration';
    memEnumValue: Result := 'enumvalue';
  else
    Result := 'variable';
  end;
end;

function ArgList(M: TMemberDef): string;
var
  A: TArgument;
begin
  Result := '';
  if M.Entry = nil then
    Exit;
  for A in M.Entry.Args do
  begin
    if Result <> '' then
      Result := Result + '; ';
    if A.Modifier <> '' then
      Result := Result + A.Modifier + ' ';
    Result := Result + A.Name;
    if A.TypeText <> '' then
      Result := Result + ': ' + A.TypeText;
  end;
  if Result <> '' then
    Result := '(' + Result + ')';
end;

procedure WriteMemberTag(W: TXmlWriter; M: TMemberDef; ALinks: TLinkResolver; const AFile: string);
var
  Attrs: TList<string>;
begin
  Attrs := TList<string>.Create;
  try
    Attrs.AddRange(['kind', MemberKind(M)]);
    if M.Protection in [prProtected, prStrictProtected] then
      Attrs.AddRange(['protection', 'protected'])
    else if M.Protection in [prPrivate, prStrictPrivate] then
      Attrs.AddRange(['protection', 'private']);
    if (M.Entry <> nil) and (M.Entry.Virtualness <> vtNormal) then
      if efAbstract in M.Entry.Flags then Attrs.AddRange(['virtualness', 'pure'])
      else Attrs.AddRange(['virtualness', 'virtual']);
    if (M.Entry <> nil) and ([efClassMember, efStatic] * M.Entry.Flags <> []) then
      Attrs.AddRange(['static', 'yes']);
    W.NewLine;
    W.Open('member', Attrs.ToArray);
  finally
    Attrs.Free;
  end;
  if (M.Entry <> nil) and (M.Entry.TypeText <> '') then
  begin
    W.NewLine;
    W.Leaf('type', M.Entry.TypeText, []);
  end;
  W.NewLine;
  W.Leaf('name', M.Name, []);
  W.NewLine;
  W.Leaf('anchorfile', AFile, []);
  W.NewLine;
  W.Leaf('anchor', M.DiskName, []);
  W.NewLine;
  W.Leaf('arglist', ArgList(M), []);
  W.NewLine;
  W.Close('member');
end;

procedure WriteTagFile(AProject: TProject; const AFileName: string);
var
  W: TXmlWriter;
  Links: TLinkResolver;
  C, N: TClassDef;
  U: TUnitDef;
  G: TGroupDef;
  P: TPageDef;
  M: TMemberDef;
  B: TBaseRef;
  T: TTypeParam;
  D: TDefinition;
  Dir: string;
begin
  W := TXmlWriter.Create;
  Links := TLinkResolver.Create(AProject);
  try
    W.Raw('<?xml version=''1.0'' encoding=''UTF-8'' standalone=''yes'' ?>'#10);
    W.Open('tagfile', ['doxygen_version', DoxyPasVersion, 'doxygen_gitid', '']);
    for C in AProject.Classes do
    begin
      if not Links.IsLinkable(C) then
        Continue;
      W.NewLine;
      if C.ClassKind in [ckRecord, ckRecordHelper] then
        W.Open('compound', ['kind', 'struct'])
      else if C.ClassKind in [ckInterface, ckDispInterface] then
        W.Open('compound', ['kind', 'interface'])
      else
        W.Open('compound', ['kind', 'class']);
      W.NewLine;
      W.Leaf('name', C.QualifiedName, []);
      W.NewLine;
      W.Leaf('filename', C.DiskName + '.html', []);
      for T in C.Entry.TypeParams do
      begin
        W.NewLine;
        W.Leaf('templarg', T.Name, []);
      end;
      for B in C.Bases do
        if (B.ClassDef <> nil) and Links.IsLinkable(B.ClassDef) then
        begin
          W.NewLine;
          W.Leaf('base', B.ClassDef.QualifiedName, []);
        end;
      for N in C.NestedClasses do
        if Links.IsLinkable(N) then
        begin
          W.NewLine;
          W.Leaf('class', N.QualifiedName, ['kind', 'class']);
        end;
      for M in C.Members do
        if Links.IsLinkable(M) then
          WriteMemberTag(W, M, Links, C.DiskName + '.html');
      W.NewLine;
      W.Close('compound');
    end;
    for U in AProject.Units do
    begin
      if not AProject.IsVisible(U) then
        Continue;
      W.NewLine;
      W.Open('compound', ['kind', 'namespace']);
      W.NewLine;
      W.Leaf('name', U.Name, []);
      W.NewLine;
      W.Leaf('filename', U.DiskName + '.html', []);
      for C in U.Classes do
        if Links.IsLinkable(C) then
        begin
          W.NewLine;
          W.Leaf('class', C.QualifiedName, ['kind', 'class']);
        end;
      for M in U.Members do
        if Links.IsLinkable(M) then
          WriteMemberTag(W, M, Links, U.DiskName + '.html');
      W.NewLine;
      W.Close('compound');
    end;
    for G in AProject.Groups do
    begin
      W.NewLine;
      W.Open('compound', ['kind', 'group']);
      W.NewLine;
      W.Leaf('name', G.Name, []);
      W.NewLine;
      W.Leaf('title', G.Title, []);
      W.NewLine;
      W.Leaf('filename', G.DiskName + '.html', []);
      for D in G.Members do
        if D is TClassDef then
        begin
          W.NewLine;
          W.Leaf('class', D.QualifiedName, ['kind', 'class']);
        end;
      for D in G.Members do
        if (D is TMemberDef) and Links.IsLinkable(D) then
          WriteMemberTag(W, TMemberDef(D), Links, D.Scope.DiskName + '.html');
      W.NewLine;
      W.Close('compound');
    end;
    for P in AProject.Pages do
    begin
      W.NewLine;
      W.Open('compound', ['kind', 'page']);
      W.NewLine;
      if P.IsMainPage then
        W.Leaf('name', 'index', [])
      else
        W.Leaf('name', P.Name, []);
      W.NewLine;
      W.Leaf('title', P.Title, []);
      W.NewLine;
      W.Leaf('filename', P.DiskName + '.html', []);
      W.NewLine;
      W.Close('compound');
    end;
    W.NewLine;
    W.Close('tagfile');
    W.NewLine;
    Dir := ExtractFilePath(ExpandFileName(AFileName));
    if Dir <> '' then
      TDirectory.CreateDirectory(Dir);
    TFile.WriteAllText(AFileName, W.ToString, TUTF8Encoding.Create(False));
  finally
    Links.Free;
    W.Free;
  end;
end;

{ ------------------------------------------------------------------ reading }

function ChildText(ANode: IXMLNode; const AName: string): string;
var
  C: IXMLNode;
begin
  C := ANode.ChildNodes.FindNode(AName);
  if C = nil then
    Result := ''
  else
    Result := C.Text;
end;

function WithHtml(const AFile: string): string;
begin
  Result := AFile;
  if (Result <> '') and (ExtractFileExt(Result) = '') then
    Result := Result + '.html';
end;

function ReadTagFile(AProject: TProject; const AFileName, ALocation: string): Integer;
var
  Doc: IXMLDocument;
  Root, C, M: IXMLNode;
  I, J: Integer;
  Tag: string;
  R: TExternalRef;
  CName, CFile, CKind, MKind: string;
begin
  Result := 0;
  if not TFile.Exists(AFileName) then
    raise Exception.CreateFmt('tag file ''%s'' not found', [AFileName]);
  DefaultDOMVendor := sOmniXmlVendor;
  Doc := NewXMLDocument;
  Doc.LoadFromFile(AFileName);
  Root := Doc.DocumentElement;
  Tag := TPath.GetFileNameWithoutExtension(AFileName);
  for I := 0 to Root.ChildNodes.Count - 1 do
  begin
    C := Root.ChildNodes[I];
    if C.NodeName <> 'compound' then
      Continue;
    CKind := VarToStr(C.Attributes['kind']);
    CName := ChildText(C, 'name');
    CFile := ChildText(C, 'filename');
    if CFile = '' then
      CFile := ChildText(C, 'path') + ChildText(C, 'name');
    R := Default(TExternalRef);
    R.Name := CName;
    R.Kind := CKind;
    R.Url := ALocation;
    R.FileName := WithHtml(CFile);
    R.TagName := Tag;
    R.Title := ChildText(C, 'title');
    if (CName <> '') and (CKind <> 'file') and (CKind <> 'dir') then
    begin
      AProject.AddExternal(R);
      Inc(Result);
    end;
    for J := 0 to C.ChildNodes.Count - 1 do
    begin
      M := C.ChildNodes[J];
      if M.NodeName = 'member' then
      begin
        MKind := VarToStr(M.Attributes['kind']);
        R.Kind := MKind;
        R.Title := '';
        R.FileName := WithHtml(ChildText(M, 'anchorfile'));
        R.Anchor := ChildText(M, 'anchor');
        if (CKind = 'class') or (CKind = 'struct') or (CKind = 'interface') or (CKind = 'namespace') then
          R.Name := CName + '.' + ChildText(M, 'name')
        else
          R.Name := ChildText(M, 'name');
        AProject.AddExternal(R);
        Inc(Result);
      end
      else if M.NodeName = 'docanchor' then
      begin
        R.Kind := 'anchor';
        R.FileName := WithHtml(VarToStr(M.Attributes['file']));
        R.Anchor := M.Text;
        R.Name := M.Text;
        AProject.AddExternal(R);
        Inc(Result);
      end;
    end;
  end;
end;

procedure ReadTagFiles(AProject: TProject; const AEntries: TArray<string>);
var
  E, F, Loc: string;
  P: Integer;
begin
  for E in AEntries do
  begin
    P := Pos('=', E);
    if P > 0 then
    begin
      F := Trim(Copy(E, 1, P - 1));
      Loc := Trim(Copy(E, P + 1, MaxInt));
    end
    else
    begin
      F := Trim(E);
      Loc := '';
    end;
    if F <> '' then
      ReadTagFile(AProject, F, Loc);
  end;
end;

end.
