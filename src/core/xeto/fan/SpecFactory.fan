//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   1 Jul 2023  Brian Frank  Creation
//

using concurrent
using util

**
** SpecFactory is used to map between Xeto specs and Fantom types.
** A given spec maps to a Fantom class one of two ways:
**  - Scalar: maps specs to const scalar class
**  - Dict: maps specs to const Dict subclass
**
@NoDoc @Js
abstract const class SpecFactory
{
  ** Fantom type used to represent instances of the spec
  abstract Type type()

  ** Is this a scalar factory that handles decodeScalar and encodeScalar
  abstract Bool isScalar()

  ** Is this a spec that encodes and decodes using Scalar wrapper
  abstract Bool isGenericScalar()

  ** Is this a dict (or component) factory that handles decodeDict
  abstract Bool isDict()

  ** Is this a list factory that handles decodeList
  abstract Bool isList()

  ** Is this an interface factory that is only for its type (no decoding)
  abstract Bool isInterface()

  ** Decode a Xeto dict of name/value pairs to a Fantom Dict instance
  abstract Dict decodeDict(Dict xeto, Bool checked := true)

  ** Decode a Xeto list of objects to a Fantom wrapper instance
  abstract Obj decodeList(Obj?[] xeto, Bool checked := true)

  ** Decode a scalar Xeto string to a Fantom instance
  abstract Obj? decodeScalar(Str xeto, Bool checked := true)

  ** Encode a Fantom scalar instance to its Xeto string encoding
  abstract Str encodeScalar(Obj val)
}

**************************************************************************
** SpecFactoryLoader
**************************************************************************

** SpecFactoryLoader are used to map Xeto spec names to SpecFactory
** instances.  They are used early in the compile pipeline before the
** specs themselves have been created so that scalar default values can
** be reified.
@NoDoc @Js
abstract const class SpecFactoryLoader
{
  ** Map library name and its top-level type names to map of
  ** factory instances keyed by simple spec name.
  abstract Str:SpecFactory load(Str libName, Str[] specNames)
}

**************************************************************************
** DictSpecFactory
**************************************************************************

** Base class for handle dicts
@NoDoc @Js
abstract const class DictSpecFactory : SpecFactory
{
  new make(Type type) { this.type = type }

  const override Type type

  override Bool isScalar() { false }

  override Bool isGenericScalar() { false }

  override Bool isDict() { true }

  override Bool isList() { false }

  override Bool isInterface() { false }

  override final Obj decodeList(Obj?[] xeto, Bool checked := true)
  {
    throw UnsupportedErr("Dict cannot decode to list")
  }

  override final Obj? decodeScalar(Str xeto, Bool checked := true)
  {
    throw UnsupportedErr("Dict cannot decode to scalar")
  }

  override final Str encodeScalar(Obj val)
  {
    throw UnsupportedErr("Dict cannot encode to scalar")
  }
}

**************************************************************************
** CompSpecFactory
**************************************************************************

** Comp specs are modeled as generic dicts
@NoDoc @Js
const class CompSpecFactory : DictSpecFactory
{
  new make(Type type) : super(type) {}
  override Dict decodeDict(Dict xeto, Bool checked := true) { xeto }
  override Str toStr() { "$typeof.name @ $type" }
}

**************************************************************************
** ListSpecFactory
**************************************************************************

** Base class for creating Fantom wrappers for list types
@NoDoc @Js
abstract const class ListSpecFactory : SpecFactory
{
  new make(Type type) { this.type = type }

  const override Type type

  override Bool isScalar() { false }

  override Bool isGenericScalar() { false }

  override Bool isDict() { false }

  override Bool isList() { true }

  override Bool isInterface() { false }

  override final Dict decodeDict(Dict xeto, Bool checked := true)
  {
    throw UnsupportedErr("List cannot decode to dict")
  }

  override final Obj? decodeScalar(Str xeto, Bool checked := true)
  {
    throw UnsupportedErr("List cannot decode to scalar")
  }

  override final Str encodeScalar(Obj val)
  {
    throw UnsupportedErr("List cannot encode to scalar")
  }
}


**************************************************************************
** ScalarSpecFactory
**************************************************************************

** Default implementation for handling Scalars
@NoDoc @Js
const class ScalarSpecFactory : SpecFactory
{
  new make(Type type) { this.type = type }

  const override Type type

  override Bool isScalar() { true }

  override Bool isGenericScalar() { false }

  override Bool isDict() { false }

  override Bool isList() { false }

  override Bool isInterface() { false }

  override final Dict decodeDict(Dict xeto, Bool checked := true)
  {
    throw UnsupportedErr("Scalar cannot decode to dict")
  }

  override final Obj decodeList(Obj?[] xeto, Bool checked := true)
  {
    throw UnsupportedErr("Scalar cannot decode to list")
  }

  override Obj? decodeScalar(Str xeto, Bool checked := true)
  {
    fromStr := type.method("fromStr", false)
    return fromStr.call(xeto, checked)
  }

  override Str encodeScalar(Obj val)
  {
    val.toStr
  }

  override Str toStr() { "$typeof.name @ $type" }
}

**************************************************************************
** InterfaceSpecFactory
**************************************************************************

** Factory for interfaces that don't decode from dict nor string
@NoDoc @Js
const class InterfaceSpecFactory : SpecFactory
{
  new make(Type type) { this.type = type }

  const override Type type

  override Bool isScalar() { false }

  override Bool isGenericScalar() { false }

  override Bool isDict() { false }

  override Bool isList() { false }

  override Bool isInterface() { true }

  override Dict decodeDict(Dict xeto, Bool checked := true)
  {
    throw UnsupportedErr("Interface cannot decode to dict")
  }

  override final Obj decodeList(Obj?[] xeto, Bool checked := true)
  {
    throw UnsupportedErr("Interface cannot decode to list")
  }

  override Obj? decodeScalar(Str xeto, Bool checked := true)
  {
    throw UnsupportedErr("Interface cannot decode to scalar")
  }

  override Str encodeScalar(Obj val)
  {
    throw UnsupportedErr("Interface cannot encode to scalar")
  }

  override Str toStr() { "$typeof.name @ $type" }
}

