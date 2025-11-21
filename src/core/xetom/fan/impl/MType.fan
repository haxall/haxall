//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   23 Feb 2023  Brian Frank  Creation
//

using crypto
using util
using xeto

**
** Implementation of top-level type spec
**
@Js
const final class MType : MSpec
{
  new make(MSpecInit init) : super(init)
  {
    this.lib        = init.lib
    this.qname      = init.qname
    this.id         = Ref(qname, null)
    this.globalsOwn = init.globalsOwn
    this.binding    = init.binding
  }

  const override XetoLib lib

  const override Str qname

  const override Ref id

  override SpecFlavor flavor() { SpecFlavor.type }

  override const SpecMap globalsOwn

  override const SpecBinding binding

  override MEnum enum()
  {
    if (enumRef != null) return enumRef
    if (!hasFlag(MSpecFlags.enum)) return super.enum
    MType#enumRef->setConst(this, MEnum.init(this))
    return enumRef
  }
  private const MEnum? enumRef

  override Str toStr() { qname }

  override Int inheritanceDigest(Spec self)
  {
    if (inheritanceDigestRef == 0)
    {
      d := ((MEnv)XetoEnv.cur).computeInheritanceDigest(self)
      if (d == 0) d = 1
      MType#inheritanceDigestRef->setConst(this, d)
    }
    return inheritanceDigestRef
  }
  private const Int inheritanceDigestRef

}

