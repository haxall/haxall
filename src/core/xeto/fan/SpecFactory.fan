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
** SpecFactory is used to map between Xeto specs and Fantom types
**
@NoDoc @Js
abstract const class SpecFactory
{
  ** Fantom type used to represent instances of the spec
  abstract Type type()

  ** Decode a Xeto dict of name/value pairs to a Fantom instance
  abstract Obj? decodeDict(Dict xeto, Bool checked := true)

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
** be reified.  Factory loaders are lazily installed when a Xeto lib is
** loaded with the pragma key "factoryLoader" mapped to Fantom qname.
@NoDoc @Js
abstract const class SpecFactoryLoader
{
  ** Return if this loader handles the given library
  abstract Bool canLoad(Str libName)

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

  override Obj? decodeScalar(Str xeto, Bool checked := true)
  {
    throw UnsupportedErr("Dict cannot decode to scalar")
  }

  override Str encodeScalar(Obj val)
  {
    throw UnsupportedErr("Dict cannot encode to scalar")
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

  override Obj? decodeScalar(Str xeto, Bool checked := true)
  {
    fromStr := type.method("fromStr", false)
    return fromStr.call(xeto, checked)
  }

  override Str encodeScalar(Obj val)
  {
    val.toStr
  }

  override Obj? decodeDict(Dict xeto, Bool checked := true)
  {
    throw UnsupportedErr("Scalar cannot decode to dict")
  }

  override Str toStr() { "ScalarSpecFactory @ $type" }
}

