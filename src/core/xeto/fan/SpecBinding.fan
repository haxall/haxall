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
** Registry of mapping between Xeto specs and Fantom types for the VM
**
@NoDoc @Js
const class SpecBindings
{
  ** Current bindings for the VM
  static SpecBindings cur()
  {
    cur := curRef.val as SpecBindings
    if (cur != null) return cur
    curRef.compareAndSet(null, init)
    return curRef.val
  }
  private static const AtomicRef curRef := AtomicRef()

  ** Load the built-in bindings from xetoEnv using reflection
  private static SpecBindings init()
  {
    instance := make
    try
      Slot.findMethod("xetoEnv::BindingsInit.init").call(instance)
    catch (Err e)
      echo("ERR: SpecBindings.init:\n$e.traceToStr")
    return instance
  }

  ** List all bindings installed
  SpecBinding[] list()
  {
    specMap.vals(SpecBinding#)
  }

  ** Lookup a binding for a spec qname
  SpecBinding? forSpec(Str qname)
  {
    specMap.get(qname)
  }

  ** Lookup a binding for a type
  SpecBinding? forType(Type type)
  {
    typeMap.get(type.qname)
  }

  ** Add new spec binding
  Void add(SpecBinding b)
  {
    specMap.set(b.spec, b)
    typeMap.getOrAdd(b.type.qname, b)
  }

  private const ConcurrentMap specMap := ConcurrentMap() // qname:qname
  private const ConcurrentMap typeMap := ConcurrentMap() // qname:Type
}

**************************************************************************
** SpecBinding
**************************************************************************

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

**************************************************************************
** DictBinding
**************************************************************************

** Base class for binding fantom to dict classes
@NoDoc @Js
const class DictBinding : SpecBinding
{
  new make(Str spec, Type type) { this.spec = spec; this.type = type }

  const override Str spec

  const override Type type

  override Bool isScalar() { false }

  override Bool isDict() { true }

  override Dict decodeDict(Dict xeto) { xeto }

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
** ScalarBinding
**************************************************************************

** Base class for binding Fantom classes to scalar classes
@NoDoc @Js
const class ScalarBinding : SpecBinding
{
  new make(Str spec, Type type) { this.spec = spec; this.type = type }

  const override Str spec

  const override Type type

  override Bool isScalar() { true }

  override Bool isDict() { false }

  override final Dict decodeDict(Dict xeto)
  {
    throw UnsupportedErr("Scalar cannot decode to dict")
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
}

