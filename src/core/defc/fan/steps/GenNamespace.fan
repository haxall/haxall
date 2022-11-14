//
// Copyright (c) 2019, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   17 Jan 2019  Brian Frank  Creation
//

using haystack
using def

**
** Generate Namespace instance from index
**
internal class GenNamespace : DefCompilerStep
{
  new make(DefCompiler c) : super(c) {}

  override Void run()
  {
    db := DefBuilder()
    db.factory = compiler.factory
    eachDef |c| { db.addDef(genMeta(c), c.aux) }
    compiler.ns = db.build
    index.nsRef = compiler.ns
  }

  private Dict genMeta(CDef c)
  {
    acc := Str:Obj[:]
    c.meta.each |pair, n|
    {
      // normalize value
      v := genVal(pair.val)

      // strip doc tag if def marked nodoc
      if (n == "doc" && stripDoc(c)) return

      // add to accumulator
      acc[n] = v
    }
    return Etc.makeDict(acc)
  }

  private Bool stripDoc(CDef c)
  {
    if (c.meta["nodoc"] == null) return false
    if (c.isLib) return false
    return true
  }

  private Obj? genVal(Obj? c)
  {
    // TODO: not very efficient, just to get us going
    if (c is List) return ((List)c).map |v| { genVal(v) }
    if (c is CDef) return ((CDef)c).symbol.val
    return c
  }
}

