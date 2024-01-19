//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   6 Apr 2023  Brian Frank  Creation
//

using xeto
using util

**
** CSpec is common API shared by both ASpec, RSpec, and XetoSpec
**
@Js
mixin CSpec : CNode
{
  ** Return if this an AST ASpec
  abstract Bool isAst()

  ** Assembled XetoSpec (stub only in AST until Assemble step)
  override abstract XetoSpec asm()

  ** Simple name
  abstract Str name()

  ** Qualified name
  abstract Str qname()

  ** Parent spec which contains this spec definition and scopes `name`.
  ** Returns null for top level specs in the library.
  abstract CSpec? cparent()

  ** Ref for qualified name
  abstract override haystack::Ref id()

  ** Factory for spec type
  abstract SpecFactory factory()

  ** Type of the spec or if this a type then return self
  abstract CSpec ctype()

  ** Base spec or null if this sys::Obj itself
  abstract CSpec? cbase()

  ** Effective meta
  abstract MNameDict cmeta()

  ** Is there one or more effective slots
  abstract Bool hasSlots()

  ** Lookup effective slot
  abstract CSpec? cslot(Str name, Bool checked := true)

  ** Iterate the effective slots as map
  abstract Void cslots(|CSpec, Str| f)

  ** Return list of component specs for a compound type
  abstract CSpec[]? cofs()

  ** Return if spec inherits from that from a nominal type perspective.
  ** This is the same behavior as Spec.isa, just using CSpec (XetoSpec or AST)
  abstract Bool cisa(CSpec that)

  ** MSpecFlags bitmask flags
  abstract Int flags()

  ** MSpecArgs
  abstract MSpecArgs args()

  ** Is this spec in the 'sys' library
  abstract Bool isSys()

  ** Is this a top-level type spec
  abstract Bool isType()

  ** Is this a top-level global slot spec
  abstract Bool isGlobal()

  ** Is this the sys::None spec
  abstract Bool isNone()

  ** Is this the sys::Self spec
  abstract Bool isSelf()

  ** Is the base 'sys::Enum'
  abstract Bool isEnum()

  ** Lookup enum item by its key - raise exception if not enum type
  abstract CSpec? cenum(Str key, Bool checked := true)

  ** Does this spec directly inherit from And where base is sys::And
  abstract Bool isBaseAnd()

  ** Does this spec directly inherit from Or where base is sys::Or
  abstract Bool isBaseOr()

  ** Does this spec directly inherits from And/Or and define 'ofs'
  Bool isCompound() { (isBaseAnd || isBaseOr) && cofs != null }

  ** Is maybe flag set
  abstract Bool isMaybe()

  ** Inherits from 'sys::Scalar' without considering And/Or
  abstract Bool isScalar()

  ** Inherits from 'sys::Marker' without considering And/Or
  abstract Bool isMarker()

  ** Inherits from 'sys::Choice' without considering And/Or
  abstract Bool isChoice()

  ** Inherits from 'sys::Dict' without considering And/Or
  abstract Bool isDict()

  ** Inherits from 'sys::List' without considering And/Or
  abstract Bool isList()

  ** Inherits from 'sys::Query' without considering And/Or
  abstract Bool isQuery()
}

**************************************************************************
** CNode
**************************************************************************

@Js
mixin CNode
{
  ** Required for covariant conflict so that signature matches ANode
  abstract Obj asm()

  ** Qualified name as Ref
  abstract haystack::Ref id()
}


