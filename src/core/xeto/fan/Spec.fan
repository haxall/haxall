//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   16 Jan 2023  Brian Frank  Creation
//

using util

**
** Xeto data specification.
**
** Spec dict representation:
**   - id: Ref "lib:{qname}"
**   - spec: Ref "sys::Spec"
**   - base: Ref to base type (types only)
**   - type: Ref to slot type (slots only)
**   - effective meta
**
@Js
const mixin Spec : Dict
{

  ** Parent library for spec
  abstract Lib lib()

  ** Identifier for a spec is always its qualified name
  ** This is a temp shim until we move 'haystack::Dict' fully into Xeto.
  abstract override Ref _id()

  ** Parent spec which contains this spec definition and scopes `name`.
  ** Returns null for top level specs in the library.
  abstract Spec? parent()

  ** Return simple name scoped by `lib` or `parent`.
  abstract Str name()

  ** Return fully qualified name of this spec:
  **   - Type specs will return "foo.bar::Baz"
  **   - Global slots will return "foo.bar::baz"
  **   - Type slots will return "foo.bar::Baz.qux"
  **   - Derived specs will return "derived123::{name}"
  abstract Str qname()

  ** Type of this spec.  If this spec is a top level type then return self.
  abstract Spec type()

  ** Base spec from which this spec directly inherits its meta and slots.
  ** Returns null if this is 'sys::Obj' itself.
  abstract Spec? base()

  ** Get my effective meta; this does not include synthesized tags like 'spec'
  abstract Dict meta()

  ** Get my own declared meta-data
  abstract Dict metaOwn()

  ** Get the declared children slots
  abstract SpecSlots slotsOwn()

  ** Get the effective children slots including inherited
  abstract SpecSlots slots()

  ** Convenience for 'slots.get'
  abstract Spec? slot(Str name, Bool checked := true)

  ** Convenience for 'slotsOwn.get'
  abstract Spec? slotOwn(Str name, Bool checked := true)

  ** Return if 'this' spec inherits from 'that' from a nominal type perspective.
  ** Nonimal typing matches any of the following conditions:
  **   - if 'that' matches one of 'this' inherited specs via `base`
  **   - if 'this' is maybe and that is 'None'
  **   - if 'this' is 'And' and 'that' matches any 'this.ofs'
  **   - if 'this' is 'Or' and 'that' matches all 'this.ofs' (common base)
  **   - if 'that' is 'Or' and 'this' matches any of 'that.ofs'
  abstract Bool isa(Spec that)

  ** Does meta have maybe tag
  abstract Bool isMaybe()

  ** Is the base 'sys::Enum'
  abstract Bool isEnum()

  ** Return enum item meta.  Raise exception if `isEnum` is false.
  abstract SpecEnum enum()

//////////////////////////////////////////////////////////////////////////
// NoDoc
//////////////////////////////////////////////////////////////////////////

  ** Environment for spec
  @NoDoc abstract XetoEnv env()

  ** File location of definition or unknown
  @NoDoc abstract FileLoc loc()

  ** Mapping between this spec and its Fantom representation
  @NoDoc abstract SpecFactory factory()

  ** Is this a top level type spec
  @NoDoc abstract Bool isType()

  ** Is this a top level global slot spec
  @NoDoc abstract Bool isGlobal()

  ** Is this the 'sys::None' spec itself
  @NoDoc abstract Bool isNone()

  ** Is this the 'sys::Self' spec itself
  @NoDoc abstract Bool isSelf()

  ** Does this spec directly inherit from And where base is 'sys::And'
  @NoDoc abstract Bool isBaseAnd()

  ** Does this spec directly inherit from Or where base is 'sys::Or'
  @NoDoc abstract Bool isBaseOr()

  ** Does this spec directly inherits from And/Or and define 'ofs'
  @NoDoc abstract Bool isCompound()

  ** Return component spec for a collection/ref type
  @NoDoc abstract Spec? of(Bool checked := true)

  ** Return list of component specs for a compound type
  @NoDoc abstract Spec[]? ofs(Bool checked := true)

  ** Inherits from 'sys::Scalar' without considering And/Or
  @NoDoc abstract Bool isScalar()

  ** Inherits from 'sys::Marker' without considering And/Or
  @NoDoc abstract Bool isMarker()

  ** Inherits from 'sys::Choice' without considering And/Or
  @NoDoc abstract Bool isChoice()

  ** Inherits from 'sys::Dict' without considering And/Or
  @NoDoc abstract Bool isDict()

  ** Inherits from 'sys::List' without considering And/Or
  @NoDoc abstract Bool isList()

  ** Inherits from 'sys::Query' without considering And/Or
  @NoDoc abstract Bool isQuery()

  ** Inherits from 'sys::Func' without considering And/Or
  @NoDoc abstract Bool isFunc()

  ** Return the Fantom type used to represent this spec (scalar, Dict, or Item)
  @NoDoc abstract Type fantomType()

}

