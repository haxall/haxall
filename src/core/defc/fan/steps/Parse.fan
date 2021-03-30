//
// Copyright (c) 2018, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   23 Jul 2018  Brian Frank  Creation
//    9 Jan 2019  Brian Frank  Redesign
//

using haystack

**
** Parse parses the each CLib's source files into CDefs
**
internal class Parse : DefCompilerStep
{
  new make(DefCompiler c) : super(c) {}

  override Void run()
  {
    eachLib |lib|
    {
      parseLib(lib)
    }
  }

  private Void parseLib(CLib lib)
  {
    lib.input.scanFiles(compiler).each |file|
    {
      parseFile(lib, file)
    }

    lib.input.scanExtra(compiler).each |dict|
    {
      parseRec(lib, dict, lib.loc)
    }
  }

  private Void parseFile(CLib lib, File file)
  {
    try
    {
      CompilerInput.parseEachDict(compiler, file) |dict, loc|
      {
        parseRec(lib, dict, loc)
      }
    }
    catch (Err e) err("Cannot parse Trio file", CLoc(file), e)
  }

  private Void parseRec(CLib lib, Dict dict, CLoc loc)
  {
    // handle def and defx
    if (dict.has("def")) return parseDef(lib, dict, loc)
    if (dict.has("defx")) return parseDefX(lib, dict, loc)

    // given input chance to adapt to def
    a := lib.input.adapt(compiler, dict, loc)
    if (a == null) return
    return parseDef(lib, a, loc)

    err("Rec missing 'def' and 'defx'", loc)
  }

  private Void parseDef(CLib lib, Dict dict, CLoc loc)
  {
    symbol := parseSymbol("def", dict["def"], loc)
    if (symbol == null) return

    if (compiler.undefine(dict)) return

    addDef(loc, lib, symbol, dict)
  }

  private Void parseDefX(CLib lib, Dict dict, CLoc loc)
  {
    symbol := parseSymbol("defx", dict["defx"], loc)
    if (symbol == null) return

    defx := CDefX(loc, lib, symbol, dict)
    lib.defXs.add(defx)
  }
}

