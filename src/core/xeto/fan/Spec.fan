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
  abstract override Ref id()

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

  ** Get my own declared meta-data
  abstract Dict metaOwn()

  ** Get my effective meta; this does not include synthesized tags like 'spec'
  abstract Dict meta()

  ** Get a map with all the declared slots and globals.
  abstract SpecMap membersOwn()

  ** Get a map with all the inherited slots and globals.
  abstract SpecMap members()

  ** Convenience for 'members.get'.
  abstract Spec? member(Str name, Bool checked := true)

  ** Get the declared children slots.
  abstract SpecMap slotsOwn()

  ** Get the effective inherited children slots.
  abstract SpecMap slots()

  ** Convenience for 'slots.get'.
  abstract Spec? slot(Str name, Bool checked := true)

  ** Convenience for 'slotsOwn.get'.
  abstract Spec? slotOwn(Str name, Bool checked := true)

  ** Globals declared by this spec.
  abstract SpecMap globalsOwn()

  ** Get all the effective globals including inherited.
  ** Note that some of the globals may be hidden by slots.
  abstract SpecMap globals()

  ** Return if 'this' spec inherits from 'that' from a nominal type perspective.
  ** Nonimal typing matches any of the following conditions:
  **   - if 'that' matches one of 'this' inherited specs via `base`
  **   - if 'this' is maybe and that is 'None'
  **   - if 'this' is 'And' and 'that' matches any 'this.ofs'
  **   - if 'this' is 'Or' and 'that' matches all 'this.ofs' (common base)
  **   - if 'that' is 'Or' and 'this' matches any of 'that.ofs'
  abstract Bool isa(Spec that)

  ** Does meta have maybe tag.  Maybe slots are optional
  abstract Bool isMaybe()

  ** Is the base 'sys::Enum'
  abstract Bool isEnum()

  ** Return enum item meta.  Raise exception if `isEnum` is false.
  abstract SpecEnum enum()

  ** Return if this is a spec that inherits from 'sys::Choice'.  If
  ** this spec inherits from a choice via a And/Or type then return
  ** false.  See `Namespace.choice` to access `SpecChoice` API.
  abstract Bool isChoice()

  ** Return if this a function spec
  abstract Bool isFunc()

  ** Return function specific APIs.  Raise exception if `isFunc` is false.
  abstract SpecFunc func()

  ** Call the given function on this spec and every spec that it
  ** inherits from up to 'sys::Obj'.  Any 'sys::And' compound types are
  ** iterated, but not 'sys::Or' types.  Note it is possible that the given
  ** function may be called on the same spec twice.
  abstract Void eachInherited(|Spec| f)

//////////////////////////////////////////////////////////////////////////
// Flavor
//////////////////////////////////////////////////////////////////////////

  ** Is this a top level type spec
  abstract Bool isType()

  ** Is this a top level mixin spec
  abstract Bool isMixin()

  ** Is this a slot or global under a parent
  abstract Bool isMember()

  ** Is this a slot under a parent
  abstract Bool isSlot()

  ** Is this a global slot under a parent
  abstract Bool isGlobal()

  ** Flavor: type, global, meta, or slot
  @NoDoc abstract SpecFlavor flavor()

//////////////////////////////////////////////////////////////////////////
// NoDoc
//////////////////////////////////////////////////////////////////////////

  ** File location of definition or unknown
  @NoDoc abstract FileLoc loc()

  ** Mapping between this spec and its Fantom representation
  @NoDoc abstract SpecBinding binding()

  ** Return the Fantom type used to represent this spec.
  ** Convenience for 'binding.type'.
  @NoDoc abstract Type fantomType()

  ** Is this the 'sys::None' spec itself
  @NoDoc abstract Bool isNone()

  ** Is this the 'sys::Self' spec itself
  @NoDoc abstract Bool isSelf()

  ** Return component spec for a collection/ref type
  @NoDoc abstract Spec? of(Bool checked := true)

  ** Return list of component specs for a compound type
  @NoDoc abstract Spec[]? ofs(Bool checked := true)

  ** Inherits from 'sys::Scalar' without considering And/Or
  @NoDoc abstract Bool isScalar()

  ** Inherits from 'sys::Marker' without considering And/Or
  @NoDoc abstract Bool isMarker()

  ** Inherits from 'sys::Ref' without considering And/Or
  @NoDoc abstract Bool isRef()

  ** Inherits from 'sys::MultiRef' without considering And/Or
  @NoDoc abstract Bool isMultiRef()

  ** Inherits from 'sys::Dict' without considering And/Or
  @NoDoc abstract Bool isDict()

  ** Inherits from 'sys::List' without considering And/Or
  @NoDoc abstract Bool isList()

  ** Inherits from 'sys::Query' without considering And/Or
  @NoDoc abstract Bool isQuery()

  ** Inherits from 'sys::Interface' without considering And/Or
  @NoDoc abstract Bool isInterface()

  ** Inherits from 'sys.comp::Comp' without considering And/Or
  @NoDoc abstract Bool isComp()

  ** Is base 'sys::And'
  @NoDoc abstract Bool isAnd()

  ** Is base 'sys::Or'
  @NoDoc abstract Bool isOr()

  ** Does this spec directly inherits from And/Or and define 'ofs'
  @NoDoc abstract Bool isCompound()

  ** Is this the 'transient' meta flag set
  @NoDoc abstract Bool isTransient()

  ** Is this a spec in the sys lib
  @NoDoc abstract Bool isSys()

  ** Is this a haystack data type that matches 'XetoFidelity.haystack'.
  ** This only returns true for types; it will always return false for
  ** slots/globals even though they might have have Haystack slot type.
  @NoDoc abstract Bool isHaystack()

  ** Return a 64-bit digest for this spec's flattened inheritance hieararchy.
  ** This method is only available on top-level types in Java VM.
  @NoDoc abstract Int inheritanceDigest()

  ** Bitmask flags
  @NoDoc abstract Int flags()

  ** Is this the AST version of a spec
  @NoDoc abstract Bool isAst()

  ** Get the assembled version of an AST spec
  @NoDoc abstract Spec asm()
}

