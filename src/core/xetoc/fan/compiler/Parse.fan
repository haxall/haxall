//
// Copyright (c) 2022, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   18 Jul 2022  Brian Frank  Creation
//

using util
using xeto
using xetom
using haystack

**
** Base class for parsing steps
**
@Js
internal abstract class ParseStep : Step
{
  ** Convenience to parse file
  Void parseFile(File input, ADoc doc, BuildVars buildVars)
  {
    parse(FileLoc(input), input.readAllStr, doc, buildVars)
  }

  ** Choke point for parsing all compilation units
  Void parse(FileLoc loc, Str fileStr, ADoc doc, BuildVars buildVars)
  {
    try
    {
      Parser(this, loc, fileStr, doc, buildVars.vars).parse
    }
    catch (FileLocErr e)
    {
      err(e.msg, e.loc)
    }
    catch (Err e)
    {
      err(e.toStr, loc, e)
    }
  }
}

**************************************************************************
** ParseData
**************************************************************************

@Js
internal class ParseData : ParseStep
{
  override Void run()
  {
    // create ADataDoc for our root AST
    doc := ADataDoc(compiler, FileLoc(input))

    // parse input into doc
    parseFile(input, doc, BuildVars.empty)
    bombIfErr

    // update compiler state
    compiler.ast    = doc
    compiler.lib    = null
    compiler.data   = doc
    compiler.pragma = ADict(ast.loc, sys.lib) // we use ns for depends
  }
}

**************************************************************************
** ParseAst
**************************************************************************

@Js
internal class ParseLib : ParseStep
{
  override Void run()
  {
    // create ALib as our root AST
    lib := ALib(compiler, FileLoc(input), compiler.libName)

    // parse different lib modes
    files := MLibFiles.empty
    if (isCompanion && mode.isLib)
    {
      parseCompanionLib(lib)
    }
    else if (input.ext == "xetolib")
    {
      files = parseZip(input, lib)
    }
    else if (input.isDir)
    {
      files = parseDir(input, lib)
    }
    else
    {
      parseFile(input, lib, compiler.srcBuildVars)
    }
    bombIfErr

    // remove pragma object from lib slots
    pragma := validateLibPragma(lib)
    bombIfErr

    // update compiler state.  ProcessPragma re-assigns meta for the lib
    // modes, but ast mode never runs that branch and the tree walks
    // require meta to be non-null
    compiler.ast    = lib
    compiler.lib    = lib
    compiler.pragma = pragma
    lib.ast.files   = files
    if (files.hasChapters) lib.ast.flags = lib.flags.or(MLibFlags.hasChapters)
  }

  private ADict? validateLibPragma(ALib lib)
  {
    // use ns for depends
    if (mode.isAst) return lib.ast.meta = ADict(lib.loc, sys.lib)

    // remove object named "pragma" from root
    pragma := lib.tops.remove("pragma")

    // if not found
    if (pragma == null)
    {
      // libs must have pragma
      err("Lib '$compiler.libName' missing pragma", lib.loc)
      return null
    }

    // libs must type their pragma as Lib
    if (mode.isLibPragma)
    {
      if (pragma.typeRef == null || pragma.typeRef.name.name != "Lib") err("Pragma must have 'Lib' type", pragma.loc)
    }

    // must have meta, and no slots
    if (pragma.ast.meta == null) err("Pragma missing meta data", pragma.loc)
    if (pragma.declared != null) err("Pragma cannot have slots", pragma.loc)
    if (pragma.val != null) err("Pragma cannot scalar value", pragma.loc)

    return pragma.ast.meta
  }

//////////////////////////////////////////////////////////////////////////
// File Parsing
//////////////////////////////////////////////////////////////////////////


  private MLibFiles parseZip(File input, ALib lib)
  {
    scanner := ZipLibFilesScanner(input)
    files := scanner.scan
    buildVars := BuildVars.empty
// TODO: check the xeto-meta.props matches lib pragma?
    parseLibFiles(files, lib, buildVars, false)
    return files
  }

  private MLibFiles parseDir(File input, ALib lib)
  {
    // first parse lib.xeto so we can get build pragma
    metaFile := input.plus(`lib.xeto`)
    if (!metaFile.exists) throw err("Missing 'lib.xeto' file", FileLoc(input))
    buildVars := compiler.srcBuildVars
    parseFile(metaFile, lib, buildVars)

// TODO do some pre-pragma processing (need to reorder this)
pragma := (ADict)lib.tops.get("pragma").ast.meta
include := ProcessPragma.toFilePatterns(pragma, "include")
publish := ProcessPragma.toFilePatterns(pragma, "publish")

    scanner := DirLibFilesScanner(input, include, publish)
    if (mode.isAst) scanner.isSrcOnly = true
    files := scanner.scan |msg, f| { err(msg, FileLoc(f)) }

     parseLibFiles(files, lib, buildVars, true)
    return files
  }

  private Void parseLibFiles(MLibFiles files, ALib lib, BuildVars buildVars, Bool skipLibMeta)
  {
    files.published.each |f|
    {
      if (f.uri.ext != "xeto") return
      if (f.uri == `/lib.xeto` && skipLibMeta) return
      parse(f.loc, f.readAllStr, lib, buildVars)
    }
  }

//////////////////////////////////////////////////////////////////////////
// Companion
//////////////////////////////////////////////////////////////////////////

  private Void parseCompanionLib(ALib lib)
  {
    // syntheize the pragma
    lib.tops["pragma"] = synthetizeCompanionLibPragma(lib)

    // parse each record as its own compilation unit under the rec id so a
    // parse error in one rec is attributed to that rec and quarantined
    // independently; skip recs already marked in error so partial compilation
    // only compiles the still-ok subset (see CompanionCompiler).  Funcs are
    // each printed as their own '+Funcs' block which merge into one mixin
    // (see multi-file mixins).
    companionRecs := ns.companionRecs ?: throw Err("No companion recs")
    companionRecs.each |rec|
    {
      if (rec.status.isErr) return
      parseCompanionRec(lib, rec)
    }
  }

  private Void parseCompanionRec(ALib lib, CompanionRec rec)
  {
    // print the dict back to Xeto source code to parse; a func is wrapped in
    // its own '+Funcs' mixin block so all funcs merge into one Funcs spec
    s := StrBuf()
    if (rec.isFunc)
    {
      s.add("+Funcs {\n")
      XetoPrinter(ns, s.out, companionPrintOpts).ast(rec.rec)
      s.add("}\n")
    }
    else
    {
      XetoPrinter(ns, s.out, companionPrintOpts).ast(rec.rec)
    }
    parse(rec.loc, s.toStr, lib, compiler.srcBuildVars)
  }

  private ASpec? synthetizeCompanionLibPragma(ALib lib)
  {
    // generate stub pragma
    loc := FileLoc.synthetic
    pragma := ASpec(loc, lib, null, "pragma")
    pragma.typeRef = ASpecRef(loc, ASimpleName(null, "Lib"))
    meta := pragma.metaInit
    meta.set("version", AScalar(loc, null, "0.0.0"))
    return pragma
  }

  private once Dict companionPrintOpts()
  {
    Etc.dict2("noInferMeta", Marker.val, "qnameForce", Marker.val)
  }
}

