//
// Copyright (c) 2018, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   25 Jul 2018  Brian Frank  Creation
//    9 Jan 2019  Brian Frank  Redesign
//

**
** Index builds the indexing data structures for the namespace
**
internal class Index : DefCompilerStep
{
  new make(DefCompiler c) : super(c) {}

  override Void run()
  {
    libs := compiler.libs.vals.sort

    defs := CDef[,]
    defsMap := Str:CDef[:]
    eachLib |lib|
    {
      // strip fault defs from this lib
      lib.defs = lib.defs.findAll |def| { !def.fault }

      // process each def in the lib
      lib.defs.each |def|
      {
        symbol := def.symbol

        dup := defsMap[symbol.toStr]
        if (dup != null)
        {
          err2("Duplicate symbol: $symbol", dup.loc, def.loc)
          return
        }

        defsMap[symbol.toStr] = def
        defs.add(def)
      }

    }
    defs.sort

    compiler.index = CIndex
    {
      it.libs = libs
      it.defs = defs
      it.defsMap = defsMap
    }
  }

}