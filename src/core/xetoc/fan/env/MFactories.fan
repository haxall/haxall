//
// Copyright (c) 2022, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   8 Aug 2022  Brian Frank  Original factory handling
//   1 Jul 2023  Brian Frank  New design
//

using concurrent
using xeto

**
** MFactories is used to handle the lookup tables for SpecFactory
** to map between Xeto Spec and Fantom types
**
@Js
internal const class MFactories
{
  ** Constructor with and register core factory loader
  new make()
  {
    this.loadersRef = AtomicRef(SpecFactoryLoader[CoreFactoryLoader()].toImmutable)
  }

  ** Installed factory loaders
  SpecFactoryLoader[] loaders() { loadersRef.val }
  private const AtomicRef loadersRef

  ** Install new loader if not already created. We do this lazily via
  ** lib pragma factoryLoader so that we aren't loading a ton of Fantom
  ** classes until they are really required
  Void install(Str qname)
  {
    cur := loaders
    if (cur.any |loader| { loader.typeof.qname == qname })
      return

    loader := Type.find(qname).make
    while (true)
    {
      oldList := loaders
      newList := oldList.dup.add(loader).toImmutable
      if (loadersRef.compareAndSet(oldList, newList)) break
    }
  }

  ** Default scalar factory
  const SpecFactory scalar := StrFactory(Str#)

  ** Default dict factory
  const SpecFactory dict := DictFactory()

  ** Return registered factories for given library
  Str:SpecFactory load(Str libName, Str[] specNames)
  {
    loaders := this.loaders
    for (i := 0; i<loaders.size; ++i)
    {
      hit := loaders[i].load(libName, specNames)
      if (hit != null) return hit
    }
    return none
  }
  private const Str:SpecFactory none := [:]
}

**************************************************************************
** CoreFactoryLoader
**************************************************************************

@Js
internal const class CoreFactoryLoader : SpecFactoryLoader
{
  override [Str:SpecFactory]? load(Str libName, Str[] specNames)
  {
    if (libName == "sys") return loadSys
    //if (libName == "ph") return loadPh
    return null
  }

  private Str:SpecFactory loadSys()
  {
    sys := Pod.find("sys")
    hay := Pod.find("haystack")
    return [
      "Str":      StrFactory(sys.type("Str")),
      "Bool":     ScalarSpecFactory(sys.type("Bool")),
      "Int":      IntFactory(sys.type("Int")),
      "Float":    ScalarSpecFactory(sys.type("Float")),
      "Duration": ScalarSpecFactory(sys.type("Duration")),
      "Date":     ScalarSpecFactory(sys.type("Date")),
      "Time":     ScalarSpecFactory(sys.type("Time")),
      "DateTime": ScalarSpecFactory(sys.type("DateTime")),
      "Uri":      ScalarSpecFactory(sys.type("Uri")),
      "Version":  ScalarSpecFactory(sys.type("Version"))
    ]
  }
}

**************************************************************************
** Dict Scalars
**************************************************************************

@Js
internal const class DictFactory : SpecFactory
{
  new make() { this.type = Dict# }

  override const Type type

  override Obj? decodeScalar(Str xeto, Bool checked := true)
  {
    throw UnsupportedErr("Dict cannot decode to scalar")
  }

  override Obj? decodeDict(Dict xeto, Bool checked := true)
  {
    xeto
  }

  override Str encodeScalar(Obj val)
  {
    throw UnsupportedErr("Dict cannot encode to scalar")
  }

  override Dict encodeDict(Obj val)
  {
    val
  }
}

**************************************************************************
** Sys Scalars
**************************************************************************

@Js
internal const class StrFactory : ScalarSpecFactory
{
  new make(Type type) : super(type) {}
  override Obj? decodeScalar(Str str, Bool checked := true) { str }
}

@Js
internal const class IntFactory : ScalarSpecFactory
{
  new make(Type type) : super(type) {}
  override Obj? decodeScalar(Str str, Bool checked := true) { Int.fromStr(str, 10, checked) }
}