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
    else if (mode.isParseDicts)
      parseDicts(input)
    else
      parseData(input)
  }

  private Void parseLib(File input)
  {
    // create ALib as our root object
    lib := ALib(compiler, FileLoc(input), compiler.libName)

    // parse directory into lib
    if (isCompanion)
      parseCompanionLib(lib)
    else
      parseDir(input, lib)
    bombIfErr

    // remove pragma object from lib slots
    pragma := validateLibPragma(lib)
    bombIfErr

    compiler.ast    = lib
    compiler.lib    = lib
    compiler.pragma = pragma
  }

  private Void parseDicts(File input)
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
    parseFile(input, doc, Str:Str[:])
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

  private Void parseDir(File input, ALib lib)
  {
    hasMarkdown := false
    MLibFiles? files := null

    if (input.ext == "xetolib")
    {
      zip := Zip.read(input.in)
      list := Uri[,]
      buildVars := Str:Str[:]
      try
      {
        zip.readEach |f|
        {
          if (f.isDir) return
          if (f.ext == "xeto") parseFile(f, lib, buildVars)
          else if (f.name == "build.props") buildVars = f.readProps
          else if (f.name != "meta.props") list.add(f.uri)
          if (f.ext == "md") hasMarkdown = true
        }
      }
      finally zip.close
      files = ZipLibFiles(input, list)
    }
    else if (input.isDir)
    {
      dirList(input).each |sub|
      {
        if (sub.ext == "xeto") parseFile(sub, lib, compiler.srcBuildVars)
        if (sub.ext == "md") hasMarkdown = true
      }
      files = DirLibFiles(input)
    }
    else
    {
      parseFile(input, lib, compiler.srcBuildVars)
      files = EmptyLibFiles.val
    }

    lib.ast.files = files
    if (hasMarkdown) lib.ast.flags = lib.flags.or(MLibFlags.hasMarkdown)
  }

  private Void parseFile(File input, ADoc doc, Str:Str buildVars)
  {
    parse(FileLoc(input), input.readAllStr, doc, buildVars)
  }

  private Void parse(FileLoc loc, Str fileStr, ADoc doc, Str:Str buildVars)
  {
    try
    {
      Parser(this, loc, fileStr, doc, buildVars).parse
    }
    catch (FileLocErr e)
    {
      err(e.msg, e.loc)
      return null
    }
    catch (Err e)
    {
      err(e.toStr, loc, e)
      return null
    }
  }

//////////////////////////////////////////////////////////////////////////
// Companion
//////////////////////////////////////////////////////////////////////////

  private Void parseCompanionLib(ALib lib)
  {
    // syntheize the pragma
    lib.tops["pragma"] = synthetizeCompanionLibPragma(lib)

    // no resource files
    lib.ast.files = EmptyLibFiles.val

    // parse each record
    recs := ns.companionRecs?.recs ?: throw Err("No companion recs")
    funcs := Dict[,]
    recs.each |rec|
    {
      if (rec["rt"] == "func")
        funcs.add(rec)
      else
        parseCompanionRec(lib, rec)
    }

    // parse functions
    parseCompanionFuncs(lib, funcs)
  }

  private Void parseCompanionRec(ALib lib, Dict rec)
  {
    // this is not very efficient, but for now just print each
    // dict back to Xeto source code to parse
    name := rec["name"] as Str ?: throw Err("Rec missing name: $rec.id.toZinc")
    s := StrBuf()
    XetoPrinter(ns, s.out, Etc.dict1("noInferMeta", Marker.val)).ast(rec)
    parse(FileLoc(name), s.toStr, lib, compiler.srcBuildVars)
  }

  private Void parseCompanionFuncs(ALib lib, Dict[] recs)
  {
    if (recs.isEmpty) return
    s := StrBuf()
    out := XetoPrinter(ns, s.out, Etc.dict1("noInferMeta", Marker.val))
    out.w("+Funcs {").nl
    recs.each |rec| { out.ast(rec) }
    out.w("}")
    parse(FileLoc("Funcs"), s.toStr, lib, compiler.srcBuildVars)
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
}

