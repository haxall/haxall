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
      checkData(ast)
  }

//////////////////////////////////////////////////////////////////////////
// Lib
//////////////////////////////////////////////////////////////////////////

  Void checkLib(ALib lib)
  {
    lib.specs.each |type| { checkType(type) }
    lib.instances.each |instance| { checkDict(instance) }
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
}