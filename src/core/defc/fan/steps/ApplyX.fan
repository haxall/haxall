//
// Copyright (c) 2019, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   25 Jan 2019  Brian Frank  Creation
//

using haystack

**
** Apply all defx to their source definitions
**
internal class ApplyX : DefCompilerStep
{
  new make(DefCompiler c) : super(c) {}

  override Void run()
  {
    compiler.libs.each |lib| { applyLib(lib) }
  }

  private Void applyLib(CLib lib)
  {
    lib.defXs.each |defx| { applyDefX(defx) }
  }

  private Void applyDefX(CDefX defx)
  {
    symbol:= defx.symbol
    loc := defx.loc

    def := index.def(symbol.toStr, false)
    if (def == null) return err("Unresolved symbol for defx: $symbol", loc)

    defx.meta.each |pair|
    {
      name := pair.name
      tag  := pair.tag // may be null
      val  := pair.val

      // skip the defx tag itself
      if (name == "defx") return

      // verify tag not already defined
      curPair := def.meta[name]
      if (curPair != null)
      {
        if (!curPair.isAccumulate)
          return err("Tag $name.toCode already defined in defx: $symbol", loc)
        else
          pair = curPair.accumulate(pair)
      }

      // add it
      def.meta[name] = pair
    }
  }
}