//
// Copyright (c) 2026, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   17 Aug 2026  Brian Frank  Creation
//

using util
using xeto
using xetom

**
** AST typed view of the "pragma" object declared in lib.xeto: version,
** depends, and the include/publish file patterns.  This is constructed
** from the lib.xeto "pragma" instance during ParseLib step.
**
@Js
internal class APragma
{

//////////////////////////////////////////////////////////////////////////
// Extract
//////////////////////////////////////////////////////////////////////////

  ** Extract the pragma from the parsed lib.xeto and install it on the lib.
  ** Reports errors through the step; the lib is left with no pragma if the
  ** source declared none.
  static Void extract(Step step, ALib lib)
  {
    meta := extractMeta(step, lib)
    if (meta == null) return

    // the meta dict doubles as the lib's own meta node: it is
    // what the tree walks descend into and what Reify assembles
    lib.ast.meta = meta
    meta.metaParent = lib
    meta.typeRef = step.sys.lib

    lib.ast.pragma = make(step, meta)
  }

  ** Pull the "pragma" object out of the lib's top level and validate it
  private static ADict? extractMeta(Step step, ALib lib)
  {
    // ast mode reads back source which has no pragma of its own
    if (step.mode.isAst) return ADict(lib.loc, step.sys.lib)

    // remove object named "pragma" from root
    pragma := lib.tops.remove("pragma")
    if (pragma == null)
    {
      step.err("Lib '$step.compiler.libName' missing pragma", lib.loc)
      return null
    }

    // libs must type their pragma as Lib
    if (step.mode.isLibPragma)
    {
      if (pragma.typeRef == null || pragma.typeRef.name.name != "Lib")
        step.err("Pragma must have 'Lib' type", pragma.loc)
    }

    // must have meta, and no slots
    if (pragma.ast.meta == null) step.err("Pragma missing meta data", pragma.loc)
    if (pragma.declared != null) step.err("Pragma cannot have slots", pragma.loc)
    if (pragma.val != null) step.err("Pragma cannot scalar value", pragma.loc)

    return pragma.ast.meta
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  ** Everything the pragma declares is parsed up front so its errors are
  ** all reported at one point - ParseLib bombs before any of it is read.
  private new make(Step step, ADict dict)
  {
    this.step      = step
    this.dict      = dict
    this.version   = parseVersion
    this.depends   = parseDepends
    this.include   = parseFilePatterns("include")
    this.publish   = parseFilePatterns("publish")
    this.doc       = dict.getStr("doc") ?: ""
    this.hxSysOnly = dict.has("hxSysOnly")
    this.step      = null
  }

  ** The pragma meta as parsed from lib.xeto
  ADict dict { private set }

  ** Lib version declared by the pragma
  const Version version

  ** Lib doc string, or "" if not declared
  const Str doc

  ** Is this lib flagged as Haxall sys only
  const Bool hxSysOnly

  ** Depends declared by the pragma
  const MLibDepend[] depends

  ** Files packaged into the lib without a uri of their own
  ScannerPatternList include

  ** Files packaged into the lib and given a uri of their own
  ScannerPatternList publish

  // just used for constructor for error reporting
  private Step? step

//////////////////////////////////////////////////////////////////////////
// Parsing
//////////////////////////////////////////////////////////////////////////

  ** Lib version; reports an error and returns `Version.defVal` if missing
  ** or malformed.  Only a lib declares a version - ast mode is reading
  ** back source and has no pragma to declare one.
  private Version parseVersion()
  {
    if (!step.mode.isLibPragma) return Version.defVal

    obj := dict.get("version")
    if (obj == null)
    {
      err("Missing required version lib meta", dict.loc)
      return Version.defVal
    }

    scalar := obj as AScalar
    if (scalar == null)
    {
      err("Version must be scalar", obj.loc)
      return Version.defVal
    }

    ver := Version.fromStr(scalar.str, false)
    if (ver == null)
    {
      err("Invalid version: $scalar.str", obj.loc)
      return Version.defVal
    }

    if (ver.segments.size != 3)
    {
      err("Xeto version must be exactly three segments: $ver", obj.loc)
      return ver
    }

    scalar.asmRef = ver
    return ver
  }

  ** Depends declared by the pragma.  Every lib depends on sys, so an
  ** empty list falls back to it - except sys itself which depends on
  ** nothing.  Libs which resolve against the whole namespace (companion,
  ** temp) declare nothing, so the missing sys check does not apply.
  private MLibDepend[] parseDepends()
  {
    // sys is the root of the depend graph
    if (step.isSys) return MLibDepend#.emptyList

    list := parseDependsList(dict.get("depends"))
    if (list != null && !list.isEmpty) return list

    if (step.isLib && !step.compiler.useNsDepends) err("Must specify 'sys' in depends", dict.loc)
    return [MLibDepend("sys", LibDependVersions.wildcard, FileLoc.synthetic)]
  }

  private MLibDepend[]? parseDependsList(AData? val)
  {
    if (val == null) return null

    // depends list must be respresented in AST as ADict
    alist := val as ADict
    if (alist == null)
    {
      err("Depends must be a list", val.loc)
      return null
    }

    // map list items to MLibDepend objects
    acc := Str:MLibDepend[:]
    acc.ordered = true
    alist.each |obj| { parseDepend(acc, obj) }

    // make this list the assembled value
    depends := acc.vals.toImmutable
    alist.asmRef = depends

    return depends
  }

  private Void parseDepend(Str:MLibDepend acc, AData obj)
  {
    // get library name from depend formattd as "{lib:<qname>}"
    loc := obj.loc

    dict := obj as ADict
    if (dict == null) return err("Depend must be dict", loc)

    libName := dict.getStr("lib")
    if (libName == null) return err("Depend missing lib name", loc)

    // get versions
    LibDependVersions? versions := LibDependVersions.wildcard
    versionsObj := dict.get("versions")
    if (versionsObj != null)
    {
      versionsStr := (versionsObj as AScalar)?.str
      if (versionsStr == null) return err("Versions must be a scalar", versionsObj.loc)

      versions = LibDependVersions(versionsStr, false)
      if (versions == null) return err("Invalid versions syntax: $versionsStr", versionsObj.loc)
    }

    // register the library into our names table and our depends map
    if (acc[libName] != null) return err("Duplicate depend '$libName'", loc)
    acc[libName] = MLibDepend(libName, versions, loc)
  }

  ** Patterns for the given pragma tag, or empty if not declared
  private ScannerPatternList parseFilePatterns(Str name)
  {
    acc := LibFilePattern[,]

    val := dict.get(name)
    if (val == null) return ScannerPatternList(name, acc, dict.loc)

    // list must be respresented in AST as ADict
    alist := val as ADict
    if (alist == null)
    {
      err("Lib pragma $name must be a list", val.loc)
      return ScannerPatternList(name, acc, val.loc)
    }

    alist.each |obj|
    {
      scalar := obj as AScalar
      if (scalar == null) return err("LibFilePattern must be scalar", obj.loc)

      x := LibFilePattern.fromStr(scalar.str, false)
      if (x == null) return err("Invalid LibFilePattern: $scalar.str", obj.loc)

      acc.add(x)
    }
    return ScannerPatternList(name, acc, val.loc)
  }

  private Void err(Str msg, FileLoc loc) { step.err(msg, loc) }
}

