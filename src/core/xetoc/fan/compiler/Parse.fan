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
** Parse all source files into AST nodes
**
@Js
internal class Parse : Step
{
  override Void run()
  {
    // get input dir/file
    input := compiler.input
    if (input == null) throw err("Compiler input not configured", FileLoc.inputs)
    if (!input.exists) throw err("Input file not found: $input", FileLoc.inputs)

    // parse lib of types or data value
    if (mode.isLibPragma)
      parseLib(input)
    else if (mode.isAst)
      parseAst(input)
    else
      parseData(input)
  }

  private Void parseLib(File input)
  {
    // create ALib as our root object
    lib := ALib(compiler, FileLoc(input), compiler.libName)

    // parse different lib modes
    files := MLibFiles.empty
    if (isCompanion)
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

    compiler.ast    = lib
    compiler.lib    = lib
    compiler.pragma = pragma
    lib.ast.files = files
    if (files.hasChapters) lib.ast.flags = lib.flags.or(MLibFlags.hasChapters)
  }

  private Void parseAst(File input)
  {
    // stub lib doc
    lib := ALib(compiler, FileLoc.synthetic, compiler.libName)

    // use same logic as parseDicts
    parseToDoc(lib, input)
  }

  private Void parseData(File input)
  {
    // create ADataDoc as our root object
    doc := ADataDoc(compiler, FileLoc(input))

    // use same logic as parseDicts
    parseToDoc(doc, input)
  }

  private Void parseToDoc(ADoc doc, File input)
  {
    // parse into root
    parseFile(input, doc, BuildVars.empty)
    bombIfErr

    // data does not support a pragma (at least not yet); so
    // set pragma to empty dict and use ns as depends
    pragma := ADict(doc.loc, sys.lib)

    compiler.ast    = doc
    compiler.lib    = doc as ALib
    compiler.data   = doc as ADataDoc
    compiler.pragma = pragma
    if (compiler.lib != null)
    {
      compiler.lib.ast.meta = pragma
      compiler.lib.ast.version = Version.defVal
    }
  }

  private ADict? validateLibPragma(ALib lib)
  {
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


//    else if (input.ext == "xetolib") files = parseZip(input, lib)
//    else if (input.isDir) files = parseDir(input, lib)
//    else parseFile(input, lib, compiler.srcBuildVars)

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

  private Void parseFile(File input, ADoc doc, BuildVars buildVars)
  {
    parse(FileLoc(input), input.readAllStr, doc, buildVars)
  }

  private Void parse(FileLoc loc, Str fileStr, ADoc doc, BuildVars buildVars)
  {
    try
    {
      // only user vars are substitutable; reserved names configure the build
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

