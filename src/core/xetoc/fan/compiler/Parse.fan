//
// Copyright (c) 2022, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   18 Jul 2022  Brian Frank  Creation
//

using util

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
    if (isLib)
      parseLib(input)
    else
      parseData(input)
  }

  private Void parseLib(File input)
  {
    // create ALib as our root object
    lib := ALib(FileLoc(input), qname)
    lib.typeRef = sys.lib
    lib.initSlots

    // parse directory into root lib
    parseDir(input, lib)
    bombIfErr

    // remove pragma object from lib slots
    pragma := validatePragma(lib)
    bombIfErr

    // make pragma the lib meta
    if (lib.meta != null) throw err("Lib meta not null", lib.loc)
    lib.metaInit(sys)
    pragma.meta.slots.each |obj| { lib.meta.slots.add(obj) }

    compiler.lib    = lib
    compiler.ast    = lib
    compiler.pragma = pragma
  }

  private Void parseData(File input)
  {
    // create dict as root object
    root := AVal(FileLoc(input), null, "root")
    root.typeRef = sys.dict
    root.initSlots

    // parse into root
    parseFile(input, root)
    bombIfErr

    // remove pragma from root
    pragma := validatePragma(root)
    bombIfErr

    // if we parsed a single, unnamed value as {_0:x} make it the root
    if (root.slots.size == 1 && root.slot("_0") != null)
      root = root.slot("_0")

    compiler.ast = root
    compiler.pragma = pragma
  }

  private AObj? validatePragma(AObj root)
  {
    // remove object named "pragma" from root
    pragma := root.slots?.remove("pragma")

    // if not found
    if (pragma == null)
    {
      // libs must have pragma
      if (isLib) err("Lib '$compiler.qname' missing  pragma", root.loc)
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
    return pragma
  }

  private Void parseDir(File input, AObj root)
  {
    if (input.ext == "xetolib")
    {
      zip := Zip.read(input.in)
      try
      {
        zip.readEach |f|
        {
          if (f.ext == "xeto") parseFile(f, root)
        }
      }
      finally zip.close
    }
    else if (input.isDir)
    {
      input.list.each |sub|
      {
        if (sub.ext == "xeto") parseFile(sub, root)
      }
    }
    else
    {
      parseFile(input, root)
    }
  }

  private Void parseFile(File input, AObj root)
  {
    loc := FileLoc(input)
    try
    {
      OldParser(this, loc, input.in).parse(root)
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