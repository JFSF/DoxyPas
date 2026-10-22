unit DoxyPas.Model.Links;

{ Links between definitions: what a \ref, \link or an automatically linked word points to, and the identifiers
  (refid) used by the XML output. Shared by every generator. }

interface

uses
  System.Generics.Collections,
  System.RegularExpressions,
  DoxyPas.Model.Defs,
  DoxyPas.Model.Project;

type
  TLinkTarget = record
    Def: TDefinition;      // nil when the target is external or unresolved
    RefId: string;         // identifier used in the XML output
    IsMember: Boolean;     // member (refid has an anchor) or compound
    External: Boolean;     // defined in another project (tag file)
    Url: string;           // external: base url + file name + anchor
    TagName: string;       // external: the tag file it comes from
    Resolved: Boolean;
  end;

  TLinkText = reference to procedure(const AText: string);
  TLinkRef = reference to procedure(const AText: string; const ATarget: TLinkTarget);

  TLinkResolver = class
  strict private
    FProject: TProject;
    FSections: TDictionary<string, string>;  // \section / \anchor label -> refid
    FCache: TDictionary<string, TLinkTarget>;  // what Resolve answered: the same words come back all the time
    FWord: TRegEx;                             // compiled once (TRegEx.Match compiles at every call)
    procedure CollectSections;
    function ResolveUncached(const AText: string; AScope: TDefinition): TLinkTarget;
  public
    constructor Create(AProject: TProject);
    destructor Destroy; override;
    property Project: TProject read FProject;
    /// <summary>A definition that gets its own documentation or entry (visible and documented, or EXTRACT_ALL).</summary>
    function IsLinkable(ADef: TDefinition): Boolean;
    function RefIdOf(ADef: TDefinition): string;
    /// <summary>The target of a \ref / \link argument or of a word, seen from AScope.</summary>
    function Resolve(const AText: string; AScope: TDefinition): TLinkTarget;
    /// <summary>Splits AText into plain text and links to classes, units and "Name()" members (AUTOLINK_SUPPORT);
    /// AText is plain text (not markup). AScope is the definition the text belongs to. ATypeContext: the text is
    /// a type or a value (type of a variable, default value), so typedefs and enumerations are linked too.</summary>
    procedure LinkWords(const AText: string; AScope: TDefinition; const AOnText: TLinkText;
      const AOnRef: TLinkRef; ATypeContext: Boolean = False);
  end;

implementation

uses
  System.SysUtils,
  System.Character,
  DoxyPas.Doc.Nodes,
  DoxyPas.Doc.Parser;

constructor TLinkResolver.Create(AProject: TProject);
begin
  inherited Create;
  FProject := AProject;
  FSections := TDictionary<string, string>.Create;
  FCache := TDictionary<string, TLinkTarget>.Create;
  FWord := TRegEx.Create('[A-Za-z_][A-Za-z0-9_]*(?:\.[A-Za-z_][A-Za-z0-9_]*)*(?:\(\))?', [roCompiled]);
  CollectSections;
end;

destructor TLinkResolver.Destroy;
begin
  FCache.Free;
  FSections.Free;
  inherited;
end;

function TLinkResolver.IsLinkable(ADef: TDefinition): Boolean;
begin
  Result := FProject.IsVisible(ADef) and (FProject.Options.ExtractAll or ADef.IsDocumented or
    (ADef is TUnitDef) or (ADef is TGroupDef) or (ADef is TPageDef));
end;

function TLinkResolver.RefIdOf(ADef: TDefinition): string;
begin
  if ADef is TPageDef then
  begin
    if TPageDef(ADef).IsMainPage then
      Exit('indexpage');
    Exit(ADef.DiskName);
  end;
  if ADef is TMemberDef then
  begin
    if ADef.Scope <> nil then
      Result := ADef.Scope.DiskName + '_1' + ADef.DiskName
    else
      Result := ADef.DiskName;
    Exit;
  end;
  Result := ADef.DiskName;
end;

{ Labels of \section, \subsection... and \anchor, found in the documentation of every definition. }
procedure TLinkResolver.CollectSections;

  procedure Walk(ANode: TDocNode; const AOwnerRef: string);
  var
    C: TDocNode;
  begin
    if (ANode.Kind = dnSection) and (ANode.Id <> '') and (ANode.Name <> 'page') and (ANode.Name <> 'mainpage') then
      FSections.AddOrSetValue(LowerCase(ANode.Id), AOwnerRef + '_1' + ANode.Id)
    else if (ANode.Kind = dnAnchor) and (ANode.Text <> '') then
      FSections.AddOrSetValue(LowerCase(ANode.Text), AOwnerRef + '_1' + ANode.Text);
    for C in ANode.Children do
      Walk(C, AOwnerRef);
  end;

  procedure Scan(ADef: TDefinition);
  var
    Root: TDocNode;
  begin
    if (ADef.Brief = '') and (ADef.Detailed = '') then
      Exit;
    Root := ParseDoc(ADef.Brief + #10#10 + ADef.Detailed);
    try
      Walk(Root, RefIdOf(ADef));
    finally
      Root.Free;
    end;
  end;

var
  D: TDefinition;
begin
  for D in FProject.Pages do Scan(D);
  for D in FProject.Groups do Scan(D);
  for D in FProject.Units do Scan(D);
  for D in FProject.Classes do Scan(D);
  for D in FProject.Members do Scan(D);
end;

// The answers depend only on the project, which does not change while the outputs are made.
function TLinkResolver.Resolve(const AText: string; AScope: TDefinition): TLinkTarget;
var
  Key: string;
begin
  Key := IntToStr(NativeInt(AScope)) + '|' + AText;
  if not FCache.TryGetValue(Key, Result) then
  begin
    Result := ResolveUncached(AText, AScope);
    FCache.Add(Key, Result);
  end;
end;

function TLinkResolver.ResolveUncached(const AText: string; AScope: TDefinition): TLinkTarget;
var
  D: TDefinition;
  Ext: TExternalRef;
  Name, Ref: string;
  G: TGroupDef;
  P: TPageDef;
begin
  Result := Default(TLinkTarget);
  Name := Trim(AText);
  if Name = '' then
    Exit;
  D := FProject.Lookup(Name, AScope);
  if (D <> nil) and IsLinkable(D) then
  begin
    Result.Def := D;
    Result.RefId := RefIdOf(D);
    Result.IsMember := D is TMemberDef;
    Result.Resolved := True;
    Exit;
  end;
  G := FProject.FindGroup(Name);
  if G <> nil then
  begin
    Result.Def := G;
    Result.RefId := G.DiskName;
    Result.Resolved := True;
    Exit;
  end;
  for P in FProject.Pages do
    if SameText(P.Name, Name) or (P.IsMainPage and SameText(Name, 'mainpage')) then
    begin
      Result.Def := P;
      Result.RefId := RefIdOf(P);
      Result.Resolved := True;
      Exit;
    end;
  if FSections.TryGetValue(LowerCase(Name), Ref) then
  begin
    Result.RefId := Ref;
    Result.IsMember := True;
    Result.Resolved := True;
    Exit;
  end;
  if FProject.FindExternal(Name, Ext) then
  begin
    Result.External := True;
    Result.Resolved := True;
    Result.TagName := Ext.TagName;
    Result.Url := Ext.Url;
    if (Result.Url <> '') and not Result.Url.EndsWith('/') then
      Result.Url := Result.Url + '/';
    Result.Url := Result.Url + Ext.FileName;
    if Ext.Anchor <> '' then
      Result.Url := Result.Url + '#' + Ext.Anchor;
    Result.RefId := Ext.FileName;
    if Ext.Anchor <> '' then
      Result.RefId := Ext.FileName.Replace('.html', '') + '_1' + Ext.Anchor;
    Result.IsMember := Ext.Anchor <> '';
  end;
end;

procedure TLinkResolver.LinkWords(const AText: string; AScope: TDefinition; const AOnText: TLinkText;
  const AOnRef: TLinkRef; ATypeContext: Boolean);
var
  M: TMatch;
  Pos1: Integer;
  T: TLinkTarget;
  Word: string;
  Accept: Boolean;

  // AUTOLINK_IGNORE_WORDS: the words that start with one of them are not linked
  function StartsIgnored(const AWord: string): Boolean;
  var
    S: string;
  begin
    for S in FProject.Options.AutolinkIgnoreWords do
      if (S <> '') and AWord.StartsWith(S) then
        Exit(True);
    Result := False;
  end;

begin
  if not FProject.Options.AutolinkSupport then
  begin
    AOnText(AText);
    Exit;
  end;
  Pos1 := 1;
  M := FWord.Match(AText);
  while M.Success do
  begin
    Word := M.Value;
    // "%Word" suppresses the link; words glued to other characters (a_b-c) are not matched separately
    if (M.Index > 1) and (AText[M.Index - 1] = '%') then
      Accept := False
    else if StartsIgnored(Word) then
      Accept := False
    else
    begin
      T := Resolve(Word, AScope);
      Accept := T.Resolved and (T.External or (T.Def <> nil)) and (T.Def <> AScope) and not (T.Def is TPageDef) and
        not (T.Def is TGroupDef);
      // case-sensitive: "docs" is a word, "Docs" a unit
      if Accept and (T.Def <> nil) and
        not SameStr(Copy(Word.Replace('()', ''), LastDelimiter('.', Word.Replace('()', '')) + 1, MaxInt),
          Copy(T.Def.Name, LastDelimiter('.', T.Def.Name) + 1, MaxInt)) then
        Accept := False;
      if Accept and (T.Def is TMemberDef) and not (Word.EndsWith('()') or (Pos('.', Word) > 0)) then
        Accept := ATypeContext and (TMemberDef(T.Def).Kind in [memTypedef, memEnumeration]);
    end;
    if Accept then
    begin
      if M.Index > Pos1 then
        AOnText(Copy(AText, Pos1, M.Index - Pos1));
      AOnRef(Word, T);
      Pos1 := M.Index + M.Length;
    end;
    M := M.NextMatch;
  end;
  if Pos1 <= Length(AText) then
    AOnText(Copy(AText, Pos1, MaxInt));
end;

end.
