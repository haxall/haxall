//
// Copyright (c) 2018, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   23 Jul 2018  Brian Frank  Creation
//    9 Jan 2019  Brian Frank  Redesign
//

using haystack
using compilerDoc

**
** Scan scans the input pods to init libs and their source files
**
internal class Scan : DefCompilerStep
{
  new make(DefCompiler c) : super(c) {}

  override Void run()
  {
    inputs := compiler.inputs
    //info("Scanning [$inputs.size pods]")
    inputs.each |input| { scanInput(input) }
    if (compiler.libs.isEmpty) err("No libs found", CLoc.none)
  }

  private Void scanInput(CompilerInput input)
  {
    switch (input.inputType)
    {
      case CompilerInputType.lib:    return scanLibInput(input)
      case CompilerInputType.manual: return scanManualInput(input)
      default: throw Err(input.inputType.toStr)
    }
  }

//////////////////////////////////////////////////////////////////////////
// Libs
//////////////////////////////////////////////////////////////////////////

  private Void scanLibInput(LibInput input)
  {
    loc := input.loc

    // scan meta from input
    dict := input.scanMeta(compiler) as Dict
    if (dict == null) return

    // scan trio files from input
    files := input.scanFiles(compiler)

    // sanity check symbol
    symbol := parseLibSymbol("def", dict["def"], loc)
    if (symbol == null) return

    // santiy check includes
    if (dict.missing("depends") && symbol.name != "ph") return err("Lib missing 'depends' tag", loc)
    depends := parseDepends(dict["depends"], loc)

    // check for dup
    dup := compiler.libs[symbol]
    if (dup != null) return err2("Duplicate libs: $symbol", dup.loc, loc)

    // add to overall compiler list
    lib := CLib(loc, symbol, dict, input, depends)
    compiler.libs.add(symbol, lib)
  }

  private CSymbol[] parseDepends(Obj? val, CLoc loc)
  {
    // if missing then no includes
    if (val == null) return CSymbol#.emptyList

    // verify its a list
    if (val isnot List)
    {
      err("Expecting lib 'depends' tag be list", loc)
      return CSymbol#.emptyList
    }

    // check each item in list
    acc := Str:CSymbol[:] { ordered = true }
    ((List)val).each |x|
    {
      symbol := parseLibSymbol("depends", x, loc)
      if (symbol == null) return
      if (acc[symbol.val.toStr] != null)
      {
        err("Duplicate depends: $symbol", loc)
        return
      }
      acc[symbol.val.toStr] = symbol
    }
    return acc.vals
  }

  private CSymbol? parseLibSymbol(Str tagName, Obj? val, CLoc loc)
  {
    // basic parse checking
    symbol := parseSymbol(tagName, val, loc)
    if (symbol == null) return null

    // must be lib:name key symbol
    if (!symbol.type.isKey || symbol.parts[0].toStr != "lib")
    {
      err("Lib symbol must be 'lib:name': $symbol", loc)
      return null
    }

    return symbol
  }

//////////////////////////////////////////////////////////////////////////
// Manuals
//////////////////////////////////////////////////////////////////////////

  private Void scanManualInput(ManualInput input)
  {
    // skip this step if we aren't generating docs
    if (!compiler.genDocEnv) return

    pod := input.pod
    name := input.pod.name
    loc := CLoc(name)

    // load compilerDoc version
    docPod := DocPod.load(null, pod->loadFile)

    // read index.fog
    index := readManualIndex(pod)
    if (index == null) return

    // check for dup
    dup := compiler.manuals[name]
    if (dup != null) return err("Duplicate manuals: $name", loc)

    // add to overall compiler list
    compiler.manuals.add(name, docPod)
  }

  private Obj[]? readManualIndex(Pod pod)
  {
    uri := `/doc/index.fog`
    try
    {
      return pod.file(uri).readObj
    }
    catch (Err e)
    {
      err("Cannot read manual index", CLoc("$pod.name::$uri"), e)
      return null
    }
  }
}