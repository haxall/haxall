//
// Copyright (c) 2025, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   18 Nov 2025  Brian Frank  Creation
//

using util
using xeto
using haystack

**
** SpecMixer is used to merge meta/slots for inheritance and mixins
**
@Js
internal class SpecMixer
{
  ** Constructor
  new make(MNamespace ns, Spec spec)
  {
    this.ns = ns
    this.spec = spec
  }

  Dict meta()
  {
    acc := Etc.dictToMap(spec.meta)
    metaFor(acc, spec)
    return Etc.dictFromMap(acc)
  }

  private Void metaFor(Str:Obj acc, Spec x)
  {
    // merge in meta for this spec from all libs
    ns.libs.each |lib|
    {
      m := lib.mixinFor(x, false)
      if (m != null) metaMerge(acc, m.metaOwn)
    }

    // recurse inheritance
    if (x.isCompound && x.isAnd)
      x.ofs.each |of| { metaFor(acc, of) }
    else if (x.base != null)
      metaFor(acc, x.base)
  }

  private Void metaMerge(Str:Obj acc, Dict meta)
  {
    if (meta.isEmpty) return
    meta.each |v, n|
    {
      if (n == "mixin") return
      if (acc[n] == null) acc[n] = v
    }
  }

  const MNamespace ns
  const Spec spec
}

