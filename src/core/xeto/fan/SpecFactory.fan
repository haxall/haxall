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

  ** Decode a scalar Xeto string to a Fantom instance
  abstract Obj? decodeScalar(Str xeto, Bool checked := true)

  ** Decode a Xeto dict of name/value pairs to a Fantom instance
  abstract Obj? decodeDict(Dict xeto, Bool checked := true)

  ** Encode a Fantom scalar instance to its Xeto string encoding
  abstract Str encodeScalar(Obj val)

  ** Encode a Fantom dict instance to its name/value pairs to encode in Xeto
  abstract Dict encodeDict(Obj val)
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
  ** Map a library name and its top-level type names to map of
  ** factory instances keyed by simple spec name.  Return null
  ** is this loader does not process the given Xeto library.
  abstract [Str:SpecFactory]? load(Str libName, Str[] specNames)
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

  override Dict encodeDict(Obj val)
  {
    throw UnsupportedErr("Scalar cannot encode to dict")
  }

  override Str toStr() { "ScalarSpecFactory @ $type" }
}

