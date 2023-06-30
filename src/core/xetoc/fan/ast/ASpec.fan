//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   1 Mar 2023  Brian Frank  Creation
//

using util
using xeto

**
** AST Spec
**
@Js
internal class ASpec : AObj, CSpec
{
  ** Constructor
  new make(FileLoc loc, ASpec? parent, Str name, XetoSpec asm := XetoSpec())
    : super(loc, parent, name)
  {
    this.asmRef = asm
  }

//////////////////////////////////////////////////////////////////////////
// AObj
//////////////////////////////////////////////////////////////////////////

  ** Parent spec (null for lib)
  override ASpec? parent() { super.parent }

  ** Return true
  override Bool isSpec() { true }

  ** Return 'asm' XetoSpec as the assembled value.  This is the
  ** reference to the Spec - we backpatch the "m" field in Assemble step
  override XetoSpec asm() { asmRef }
  const XetoSpec asmRef

  ** Construct nested spec
  override AObj makeChild(FileLoc loc, Str name) { ASpec(loc, this, name) }

//////////////////////////////////////////////////////////////////////////
// ASpec
//////////////////////////////////////////////////////////////////////////

  ** We refine type and base in InheritSlots step
  CSpec? base

//////////////////////////////////////////////////////////////////////////
// CSpec
//////////////////////////////////////////////////////////////////////////

  ** Return true
  override Bool isAst() { true }

  ** Qualified name
  override Str qname() { parent.qname + "." + name }

  ** Resolved type
  override CSpec? ctype() { type }

  ** Resolved base
  override CSpec? cbase() { base }

  ** Lookup effective slot
  override CSpec? cslot(Str name, Bool checked := true)
  {
    ast := slots?.get(name) as ASpec
    if (ast != null) return ast
    if (checked) throw UnknownSlotErr(name)
    return null
  }

  ** Declared meta (set in Reify)
  Dict metaOwn() { metaOwnRef ?: throw Err("Reify not run") }
  Dict? metaOwnRef

  ** Effective meta (set in InheritMeta)
  override Dict cmeta() { cmetaRef ?: throw Err("InheritMeta not run") }
  Dict? cmetaRef

  ** Iterate the effective slots
  override Str:CSpec cslots() { cslotsRef ?: throw Err("InheritSlots not run") }
  [Str:CSpec]? cslotsRef

  ** Extract 'ofs' list of type refs from AST model
  override once CSpec[]? cofs()
  {
    if (meta == null) return null
    list := meta.slots.get("ofs")
    if (list == null || list.slots == null) return null
    acc := CSpec[,]
    list.slots.each |x| { acc.add(x.type) }
    return acc.ro
  }

  ** Inheritance flags computed in InheritSlots
  override Int flags

  override Bool isMaybe() { hasFlag(MSpecFlags.maybe) }
  override Bool isQuery() { hasFlag(MSpecFlags.query) }

  Bool hasFlag(Int flag) { flags.and(flag) != 0 }
}


