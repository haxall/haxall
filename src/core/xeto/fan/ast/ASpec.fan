//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   1 Mar 2023  Brian Frank  Creation
//

using util

**
** AST DataSpec
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

  ** Node type
  override ANodeType nodeType() { ANodeType.spec }

  ** Parent spec (null for lib)
  override ASpec? parent() { super.parent }

  ** Return true
  override Bool isSpec() { true }

  ** Return 'asm' XetoSpec as the assembled value.  This is the
  ** reference to the DataSpec - we backpatch the "m" field in Assemble step
  override XetoSpec asm() { asmRef }
  const XetoSpec asmRef

  ** Construct nested spec
  override AObj makeChild(FileLoc loc, Str name) { ASpec(loc, this, name) }

//////////////////////////////////////////////////////////////////////////
// ASpec
//////////////////////////////////////////////////////////////////////////

  ** Inheritance flags computed in Infer
  Int flags

  ** We use AObj.type to model the base supertype
  ARef? base
  {
    get { typeRef }
    set { typeRef = it }
  }

//////////////////////////////////////////////////////////////////////////
// CSpec
//////////////////////////////////////////////////////////////////////////

  ** Return true
  override Bool isAst() { true }

  ** Qualified name
  override Str qname() { parent.qname + "." + name }

  ** Resolved base
  override CSpec? cbase() { base?.creferent }

  ** Lookup effective slot
  override CSpec? cslot(Str name, Bool checked := true)
  {
    ast := slots?.get(name) as ASpec
    if (ast != null) return ast
    if (checked) throw UnknownSlotErr(name)
    return null
  }

  ** Iterate the effective slots
  override Str:CSpec cslots() { cslotsRef ?: throw Err("Inherit not run") }
  [Str:CSpec]? cslotsRef


}


