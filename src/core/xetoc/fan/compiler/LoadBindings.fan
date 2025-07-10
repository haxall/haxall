//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   1 Jul 2023  Brian Frank  Creation
//   7 Dec 2024  Brian Frank  Refactory from factory design
//

using util
using xeto
using haystack
using xetom

**
** Load and assign a SpecBinding to each type in the AST
**
internal class LoadBindings : Step
{
  override Void run()
  {
    loadBindings
    assignBindings
  }

  const SpecBindings bindings := SpecBindings.cur

  Void loadBindings()
  {
    if (bindings.needsLoad(lib.name, lib.version))
    {
      loader = bindings.load(lib.name, lib.version)
    }
  }

  private Void assignBindings()
  {
    // types in inheritance order
    lib.types.each |spec|
    {
      spec.bindingRef = resolveBinding(spec)
    }

    // rest of tops
    lib.tops.each |top|
    {
      if (top.bindingRef == null)
        top.bindingRef = top.ctype.binding
    }
  }

  private SpecBinding resolveBinding(ASpec spec)
  {
    // lookup custom registered factory
    b := bindings.forSpec(spec.qname)
    if (b != null) return b

    // if we have loader try to load for this spec
    if (loader != null)
    {
      b = loader.loadSpec(bindings, spec)
      if (b != null) return b
    }

    // use base;s binding if inheritable (we process in inheritance order)
    b = spec.base.binding
    if (b.isInheritable) return b

    // install default dict/scalar factory
    if (spec.isScalar) return GenericScalarBinding(spec.ctype.qname)
    return bindings.dict
  }

  private SpecBindingLoader? loader
}

