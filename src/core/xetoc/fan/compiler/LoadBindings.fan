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
using xetoEnv

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
      bindings.load(lib.name, lib.version, lib.types)
    }
  }

  private Void assignBindings()
  {
    lib.tops.each |spec|
    {
      assignBinding(spec)
    }
  }

  private Void assignBinding(ASpec spec)
  {
    // lookup custom registered factory
    spec.bindingRef = bindings.forSpec(spec.qname)

    // bind to type
    if (spec.bindingRef == null)
      spec.bindingRef = bindings.forSpec(spec.ctype.qname)

    // install default dict/scalar factory
    if (spec.bindingRef == null)
    {
      if (spec.isScalar)
        spec.bindingRef = GenericScalarBinding(spec.ctype.qname)
      else
        spec.bindingRef = bindings.dict
    }
  }

}

