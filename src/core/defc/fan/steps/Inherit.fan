//
// Copyright (c) 2018, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//    9 Jan 2019  Brian Frank  Creation
//

using haystack

**
** Inherit def tags from base types
**
internal class Inherit : DefCompilerStep
{
  new make(DefCompiler c) : super(c) {}

  override Void run()
  {
    eachDef |def| { inherit(def) }
  }

  private Void inherit(CDef def)
  {
    if (def.isInherited) return

    def.inheritance.each |base|
    {
      // skip myself
      if (base == def) return

      // recurse to ensure base type has inheritance computed
      inherit(base)

      // inherit tags from base def
      base.meta.each |pair|
      {
        // if this tag is not inherited skip it
        if (!pair.isInherited) return

        // if tag not present in def, inherit it
        cur := def.meta[pair.name]
        if (cur == null)
        {
          def.meta[pair.name] = pair
          return
        }

        // check if we inherit through accumulation
        if (cur.isAccumulate)
        {
          def.meta[pair.name] = cur.accumulate(pair)
        }
      }
    }
  }
}


