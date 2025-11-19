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
    spec.eachInherited |x|
    {
      metaFor(acc, x)
    }
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

