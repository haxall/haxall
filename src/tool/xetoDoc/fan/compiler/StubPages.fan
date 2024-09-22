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
      add(PageEntry(lib))

      // type ids
      lib.types.each |x|
      {
        add(PageEntry(x))
      }
/*

      // globals ids
      lib.globals.each |x|
      {
        acc.add(x.qname, globalId(lib, x))
      }

      // instance ids
      lib.instances.each |x|
      {
        qname := x._id.id
        name := XetoUtil.qnameToName(qname)
        acc.add(qname, instanceId(lib, name))
      }
*/
    }
    compiler.pages = acc
  }

}

