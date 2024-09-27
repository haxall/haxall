//
// Copyright (c) 2024, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   22 Sep 2024  Brian Frank  Creation
//

using util
using xeto
using xetoEnv

**
** Generate initial PageEntry stub for every top-level page
**
internal class StubPages: Step
{
  override Void run()
  {
    acc := Str:PageEntry[:]
    add := |PageEntry entry| { acc.add(entry.key, entry) }

    compiler.libs.each |lib|
    {
      // lib id
      add(PageEntry.makeLib(lib))

      // type ids
      typesToDoc(lib).each |x|
      {
        add(PageEntry.makeSpec(x, DocPageType.type))
      }

      // globals
      lib.globals.each |x|
      {
        add(PageEntry.makeSpec(x, DocPageType.global))
      }

      // instances
      lib.instances.each |x|
      {
        add(PageEntry.makeInstance(x))
      }
    }
    compiler.pages = acc
  }

}

