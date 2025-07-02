//
// Copyright (c) 2018, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   13 Jun 2018  Brian Frank  Creation
//    9 Jan 2019  Brian Frank  Redesign
//

using xeto
using haystack
using def

**
** Base class for DefCompiler steps
**
abstract class DefCompilerStep
{
  new make(DefCompiler compiler) { this.compiler = compiler }

  DefCompiler compiler

  abstract Void run()

  CIndex index() { compiler.index }

  CIndexEtc etc() { compiler.index.etc }

  Namespace ns() { compiler.ns }

  DefDocEnv docEnv() { compiler.docEnv }

  Void eachLib(|CLib| f)
  {
    compiler.libs.each(f)
  }

  Void eachDef(|CDef| f)
  {
    compiler.index.defs.each(f)
  }

  CSymbol? parseSymbol(Str tagName, Obj? val, CLoc loc)
  {
    // missing value
    if (val == null)
    {
      err("Missing '$tagName' tag", loc)
      return null
    }

    // invalid type
    if (val isnot Symbol)
    {
      err("Expecting Symbol value for '$tagName' tag", loc)
      return null
    }

    // invalid symbol
    try
    {
      return compiler.symbols.parse(val.toStr)
    }
    catch (Err e)
    {
      err("Invalid symbol for '$tagName' tag: $val", loc)
      return null
    }
  }

  CDef? addDef(CLoc loc, CLib lib, CSymbol symbol, Dict dict)
  {
    dup := lib.defs[symbol]
    if (dup != null)
    {
      err2("Duplicate defs: $symbol", loc, dup.loc)
      return null
    }

    def := CDef(loc, lib, symbol, dict)
    lib.defs.add(symbol, def)
    return def
  }

  Void info(Str msg) { compiler.info(msg) }

  CompilerErr err(Str msg, CLoc loc, Err? err := null) { compiler.err(msg, loc, err) }

  CompilerErr err2(Str msg, CLoc loc1, CLoc loc2, Err? err := null) { compiler.err2(msg, loc1, loc2, err) }


}

