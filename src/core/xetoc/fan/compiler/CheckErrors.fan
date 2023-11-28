//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   21 Aug 2023  Brian Frank  Creation
//

using util
using xeto
using xetoEnv

**
** CheckErrors is run late in the pipeline to perform AST validation
**
internal class CheckErrors : Step
{
  override Void run()
  {
    if (isLib)
      checkLib(lib)
    else
      checkData(data.root)
    bombIfErr
  }

//////////////////////////////////////////////////////////////////////////
// Lib
//////////////////////////////////////////////////////////////////////////

  Void checkLib(ALib x)
  {
    checkLibMeta(lib)
    x.specs.each |type| { checkType(type) }
    x.instances.each |instance| { checkDict(instance) }
  }

  Void checkLibMeta(ALib x)
  {
    libMetaReservedTags.each |name|
    {
      if (x.meta.has(name)) err("Lib '$x.name' cannot use reserved meta tag '$name'", x.loc)
    }
  }

//////////////////////////////////////////////////////////////////////////
// Specs
//////////////////////////////////////////////////////////////////////////

  Void checkType(ASpec x)
  {
    checkSpec(x)
  }

  Void checkSpec(ASpec x)
  {
    checkMeta(x)
    checkSlots(x)
  }

  Void checkSlots(ASpec x)
  {
    if (x.slots == null) return
    x.slots.each |slot| { checkSlot(slot) }
  }

  Void checkSlot(ASpec x)
  {
    checkSpec(x)
  }

  Void checkMeta(ASpec x)
  {
    if (x.meta == null) return

    specMetaReservedTags.each |name|
    {
      if (x.meta.has(name)) err("Spec '$x.name' cannot use reserved meta tag '$name'", x.loc)
    }

    checkDict(x.meta)
  }

//////////////////////////////////////////////////////////////////////////
// Data
//////////////////////////////////////////////////////////////////////////

  Void checkData(AData x)
  {
    switch (x.nodeType)
    {
      case ANodeType.dict: checkDict(x)
      case ANodeType.scalar: checkScalar(x)
      case ANodeType.specRef: checkSpecRef(x)
      case ANodeType.dataRef: checkDataRef(x)
    }
  }

  Void checkDict(ADict x)
  {
  }

  Void checkScalar(AScalar x)
  {
  }

  Void checkSpecRef(ASpecRef x)
  {
  }

  Void checkDataRef(ADataRef x)
  {
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  const Str[] libMetaReservedTags := [
    // used right now
    "id", "spec", "loaded",
    // future proofing
    "data", "instances", "name", "lib", "loc", "slots", "specs", "types", "xeto"
  ]

  const Str[] specMetaReservedTags := [
    // used right now
    "id", "base", "type", "spec", "slots",
    // future proofing
    "class", "is", "lib", "loc", "name", "parent", "qname", "super", "supers", "version", "xeto"
  ]

}