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
    // special handling for companion
    if (isCompanion && mode.isLib) return parseCompanionLib

    // initialize the scanner
    scanner := Scanner.create(this)
    try
    {
      // run with the scanner
      doRun(scanner)
    }
    finally
    {
      // close scanner
      scanner.close // TODO: how to pin for XetoEnv lib
    }
  }

  private Void doRun(Scanner scanner)
  {
    // create ALib as our root AST
    lib := ALib(compiler, FileLoc(input), compiler.libName)

    // give zip scanner chance to use its own build vars
    buildVars := scanner.readBuildVars(compiler.srcBuildVars)

    // parse lib.xeto
    parseLibMeta(scanner, lib, buildVars)
    bombIfErr

    // remove and validate pragma object from lib slots
    pragma := validateLibPragma(lib)
    bombIfErr

    // scan files to build and check the LibFiles
    files := scanFiles(scanner, pragma)

    // parse rest of the source files besides lib.xeto
    files.published.each |f|
    {
      if (f.uri.ext != "xeto") return
      if (f.uri == `/lib.xeto`) return
      parse(f.loc, f.readAllStr, lib, buildVars)
    }
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

  private Void parseLibMeta(Scanner scanner, ALib lib, BuildVars buildVars)
  {
    // parse lib.xeto
    libXeto := scanner.libMeta
    if (libXeto == null || !libXeto.exists) throw err("Missing 'lib.xeto'", FileLoc(input))
    parseFile(libXeto, lib, buildVars)
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

  private MLibFiles scanFiles(Scanner scanner, ADict pragma)
  {
    if (mode.isParseLibMeta) return MLibFiles.empty

    include := ProcessPragma.toFilePatterns(this, pragma, "include")
    publish := ProcessPragma.toFilePatterns(this, pragma, "publish")

    return scanner.scan(include, publish)
  }

//////////////////////////////////////////////////////////////////////////
// Companion
//////////////////////////////////////////////////////////////////////////

  private Void parseCompanionLib()
  {
    // syntheize the pragma
    lib := ALib(compiler, FileLoc(input), compiler.libName)
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

    // update compiler state.  ProcessPragma re-assigns meta for the lib
    // modes, but ast mode never runs that branch and the tree walks
    // require meta to be non-null
    compiler.ast    = lib
    compiler.lib    = lib
    compiler.pragma = validateLibPragma(lib)
    lib.ast.files   = MLibFiles.empty
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

