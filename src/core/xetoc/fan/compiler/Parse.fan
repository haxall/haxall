//
// Copyright (c) 2022, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   18 Jul 2022  Brian Frank  Creation
//

using util
using xetom

**
** Parse all source files into AST nodes
**
internal class Parse : Step
{
  override Void run()
  {
    // get input dir/file
    input := compiler.input
    if (input == null) throw err("Compiler input not configured", FileLoc.inputs)
    if (!input.exists) throw err("Input file not found: $input", FileLoc.inputs)

    // parse lib of types or data value
    if (isLib)
      parseLib(input)
    else
      parseData(input)
  }

  private Void parseLib(File input)
  {
    // create ALib as our root object
    lib := ALib(compiler, FileLoc(input), compiler.libName)

    // parse directory into root lib
    parseDir(input, lib)
    bombIfErr

    // remove pragma object from lib slots
    pragma := validateLibPragma(lib)
    bombIfErr

    compiler.ast    = lib
    compiler.lib    = lib
    compiler.pragma = pragma
  }

  private Void parseData(File input)
  {
    // create ADataDoc as our root object
    doc := ADataDoc(compiler, FileLoc(input))

    // parse into root
    parseFile(input, doc, Str:Str[:])
    bombIfErr

    // data does not support a pragma (at least not yet); so
    // set pragma to empty dict and use ns as depends
    pragma := ADict(doc.loc, sys.lib)

    compiler.ast = doc
    compiler.data = doc
    compiler.pragma = pragma
  }

  private ADict? validateLibPragma(ALib lib)
  {
    // remove object named "pragma" from root
    pragma := lib.tops.remove("pragma")

    // if not found
    if (pragma == null)
    {
      // libs must have pragma
      err("Lib '$compiler.libName' missing  pragma", lib.loc)
      return null
    }

    // libs must type their pragma as Lib
    if (isLib)
    {
      if (pragma.typeRef == null || pragma.typeRef.name.name != "Lib") err("Pragma must have 'Lib' type", pragma.loc)
    }

    // must have meta, and no slots
    if (pragma.meta == null) err("Pragma missing meta data", pragma.loc)
    if (pragma.slots != null) err("Pragma cannot have slots", pragma.loc)
    if (pragma.val != null) err("Pragma cannot scalar value", pragma.loc)

    pragma.meta.typeRef = sys.lib
    return pragma.meta
  }

  private Void parseDir(File input, ALib lib)
  {
    hasMarkdown := false
    MLibFiles? files := null

    if (input.ext == "xetolib")
    {
      zip := Zip.read(input.in)
      list := Uri[,]
      buildVars :=  Str:Str[:]
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

    lib.files = files
    if (hasMarkdown) lib.flags = lib.flags.or(MLibFlags.hasMarkdown)
  }

  private Void parseFile(File input, ADoc doc, Str:Str buildVars)
  {
    loc := FileLoc(input)
    try
    {
      Parser(this, loc, input.readAllStr, doc, buildVars).parseFile
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
}

