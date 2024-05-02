//
// Copyright (c) 2024, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   2 May 2024  Brian Frank  My uber day
//

using concurrent
using xeto

**
** Interface support for LibNamespace
**
@Js
internal const class MInterfaces
{
  new make(MNamespace ns) { this.ns = ns }

  Method? method(Spec spec, Str name)
  {
    // must be interface type
    if (!spec.isInterface) return null

    // must have slot in interface for security purposes
    slot := spec.slot(name, false)
    if (slot == null) return null

    // expect Fantom method of same name
    return spec.fantomType.method(name)
  }

  Method? methodOn(Obj target, Str name)
  {
    // because mapping target class to interface spec is expensive
    // and used extensively in Axon evaluations we map the type+name
    // tuple once and cache the result
    type := target.typeof
    im := cache.get(InterfaceMethod(type, name, null)) as InterfaceMethod
    if (im == null)
    {
      method := resolveMethod(type, name)
      im = InterfaceMethod(type, name, method)
      cache.set(im, im)
    }
    return im.method
  }

  private Method? resolveMethod(Type type, Str name)
  {
    // map type to spec
    spec := ns.specOf(type, false)
    if (spec == null) return null

    // map to interface method; eventually we will want to beef
    // this up to map multiple interfaces to data specs
    return method(spec, name)
  }

  const MNamespace ns
  private const ConcurrentMap cache := ConcurrentMap() // InterfaceKey:Method
}

**************************************************************************
** InterfaceMethod
**************************************************************************

@Js
internal const class InterfaceMethod
{
  new make(Type type, Str name, Method? method)
  {
    this.type   = type
    this.name   = name
    this.method = method
  }

  const Type type

  const Str name

  const Method? method

  override Int hash()
  {
    type.qname.hash.xor(name.hash)
  }

  override Bool equals(Obj? that)
  {
    x := (InterfaceMethod)that
    return this.type === x.type && this.name == x.name
  }
}

