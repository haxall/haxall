//
// Copyright (c) 2025, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   15 Feb 2025  Brian Frank  Creation
//

using concurrent
using xeto

**
** ApiBindings maps API functions to Fantom implementation methods
**
internal const class ApiBindings
{
  ** Current bindings for the VM
  static ApiBindings cur()
  {
    cur := curRef.val as ApiBindings
    if (cur != null) return cur
    curRef.compareAndSet(null, make)
    return curRef.val
  }
  private static const AtomicRef curRef := AtomicRef()

  ** Build registry of lib name to loader type:
  **   index = ["xeto.api": "libName fantomType"]
  new make()
  {
    // init Xeto lib => Fantom qname bindings
    bindings := Str:Str[:]
    Env.cur.index("xeto.api").each |str|
    {
      try
      {
        toks := str.split
        libName := toks[0]
        type := toks[1]
        bindings.set(libName, type)
      }
      catch (Err e) echo("ERR: Cannot init axon.binding: $str\n  $e")
    }
    this.bindings = bindings
    this.facet = Type.find("hx::HxApi")
  }

  ** Lookup implementation for given spec or return null
  Method? load(Spec spec)
  {
    // lookup fantom class
    clsName := bindings[spec.lib.name]
    if (clsName == null) return null
    cls := Type.find(clsName)

    // lookup method
    method := cls.method(spec.name, false)
    if (method == null) return null

    // ensure it has facet and is static
    if (!method.hasFacet(facet)) return null
    if (!method.isStatic) return null

    // bind it
    return method
  }

  const Str:Str bindings   // lib name to Fantom class
  const Type facet
}

