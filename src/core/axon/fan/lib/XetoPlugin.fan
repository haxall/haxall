//
// Copyright (c) 2025, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   13 Feb 2025  Brian Frank  Creation
//

using xeto

**
** XetoPlugin is used to plug-in Axon functionality into the Xeto environment
**
@Js @NoDoc
const class XetoPlugin : XetoAxonPlugin
{
  override Fn? parse(Spec spec)
  {
    meta := spec.meta
    src := meta["axon"] as Str
    if (src == null) return null

    // wrap src with parameterized list
    s := StrBuf(src.size + 256)
    s.addChar('(')
    spec.func.params.each |p, i|
    {
      if (i > 0) s.addChar(',')
      s.add(p.name)
    }
    s.add(")=>do\n")
    s.add(src)
    s.add("\nend")

    return Parser(Loc(spec.qname), s.toStr.in).parseTop(spec.name, meta)
  }
}

