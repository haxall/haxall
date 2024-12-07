//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   1 Jul 2023  Brian Frank  Creation
//   6 Dec 2024  Brian Frank  Redesign from SpecFactory
//

using concurrent
using util

**
** SpecBinding is used to map between Xeto specs and Fantom types.
**
@NoDoc @Js
abstract const class SpecBinding
{
  ** Xeto spec qname
  abstract Str spec()

  ** Fantom type used to represent instances of the spec
  abstract Type type()

  ** Is this a scalar factory that handles decodeScalar and encodeScalar
  abstract Bool isScalar()

  ** Is this a dict (or component) factory that handles decodeDict
  abstract Bool isDict()

  ** Decode a Xeto dict of name/value pairs to a Fantom Dict instance
  abstract Dict decodeDict(Dict xeto)

  ** Decode a scalar Xeto string to a Fantom instance
  abstract Obj? decodeScalar(Str xeto, Bool checked := true)

  ** Encode a Fantom scalar instance to its Xeto string encoding
  abstract Str encodeScalar(Obj val)

  ** Debug string
  override Str toStr() { "$spec | $type" }
}

