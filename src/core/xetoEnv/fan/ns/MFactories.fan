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
using haystack::Etc
using haystack::Marker
using haystack::NA
using haystack::Number
using haystack::Remove
using haystack::Ref

**
** MFactories is used to handle the lookup tables for SpecFactory
** to map between Xeto Spec and Fantom types
**
@Js
const class MFactories
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

    SpecFactoryLoader? loader := null
    try
    {
      loader = Type.find(qname).make
    }
    catch (Err e)
    {
      echo("ERROR: XetoSpecLaoder cannot be created: $qname")
      return
    }

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

  ** Map fantom type to its spec (called by MEnv.specOf)
  Spec? typeToSpec(Type type)
  {
    typeToSpecMap.get(type.qname)
  }

  ** Map spec to its fantom type (called by Spec.fantomType)
  Type? specToType(Str qname)
  {
    specToTypeMap.get(qname)
  }

  ** Map Fantom type to its spec (called during LoadFactories)
  Void map(Type type, Str qnameSpec, Spec spec)
  {
    qnameType := type.qname
    if (typeToSpecMap[qnameType] == null) typeToSpecMap.set(qnameType, spec)
    specToTypeMap.set(qnameSpec, type)
  }

  ** Debug dump
  Void dump(OutStream out := Env.cur.out)
  {
    out.printLine("=== MFactories [$typeToSpecMap.size, $specToTypeMap.size] ===")
    typeToSpecMap.each |v, k|
    {
      out.printLine("$v <=> $k")
    }
  }

  private const ConcurrentMap typeToSpecMap := ConcurrentMap()
  private const ConcurrentMap specToTypeMap := ConcurrentMap()
}

**************************************************************************
** CoreFactoryLoader
**************************************************************************

@Js
internal const class CoreFactoryLoader : SpecFactoryLoader
{
  override Bool canLoad(Str libName)
  {
    if (libName == "sys")      return true
    if (libName == "sys.comp") return true
    if (libName == "ph")       return true
    return false
  }

  override Str:SpecFactory load(Str libName, Str[] specNames)
  {
    if (libName == "sys")      return loadSys
    if (libName == "sys.comp") return loadSysComp
    if (libName == "ph")       return loadPh
    throw Err(libName)
  }

  private Str:SpecFactory loadSys()
  {
    sys := Pod.find("sys")
    hay := Pod.find("haystack")
    return [

      // sys pod
      "Obj":      ObjFactory(sys.type("Obj")),
      "Str":      StrFactory(sys.type("Str")),
      "Bool":     BoolFactory(sys.type("Bool")),
      "Int":      IntFactory(sys.type("Int")),
      "Float":    FloatFactory(sys.type("Float")),
      "Duration": DurationFactory(sys.type("Duration")),
      "Date":     DateFactory(sys.type("Date")),
      "Time":     TimeFactory(sys.type("Time")),
      "DateTime": DateTimeFactory(sys.type("DateTime")),
      "Uri":      UriFactory(sys.type("Uri")),
      "Version":  ScalarSpecFactory(sys.type("Version")),

      // xeto pod
      "Func":     InterfaceSpecFactory(CompFunc#),
      "Spec":     DictFactory(Spec#),

      // haystack pod
      "Marker":   SingletonFactory(hay.type("Marker"), Marker.val),
      "None":     SingletonFactory(hay.type("Remove"), Remove.val, "none"),
      "NA":       SingletonFactory(hay.type("NA"),     NA.val, "na"),
      "Number":   NumberFactory(hay.type("Number")),
      "Ref":      RefFactory(hay.type("Ref")),
      "List":     ListFactory(),
      "Dict":     DictFactory(),
    ]
  }

  private Str:SpecFactory loadSysComp()
  {
    xeto := Pod.find("xeto")
    return [
      "Comp":   CompSpecFactory(Comp#),
      "Link":   LinkFactory(xeto.type("Link")),
      "Links":  LinksFactory(xeto.type("Links")),
    ]
  }

  private Str:SpecFactory loadPh()
  {
    hay := Pod.find("haystack")
    return [
      "Coord":    ScalarSpecFactory(hay.type("Coord")),
      "Symbol":   ScalarSpecFactory(hay.type("Symbol")),
    ]
  }
}

**************************************************************************
** Factory Implemenntations
**************************************************************************

@Js
internal const class ObjFactory : SpecFactory
{
  new make(Type type) { this.type = type }
  const override Type type
  override Dict decodeDict(Dict xeto, Bool checked := true) { throw UnsupportedErr("Obj") }
  override Obj decodeList(Obj?[] xeto, Bool checked := true) { throw UnsupportedErr("Obj") }
  override Obj? decodeScalar(Str xeto, Bool checked := true) { throw UnsupportedErr("Obj")  }
  override Str encodeScalar(Obj val) { throw UnsupportedErr("Obj") }
}

@Js
internal const class DictFactory : DictSpecFactory
{
  new make() : super(Dict#) {}
  new makeWith(Type type) : super.make(type) {}
  override Dict decodeDict(Dict xeto, Bool checked := true) { xeto }
}

@Js
internal const class ListFactory : ListSpecFactory
{
  new make() : super(List#) {}
  new makeWith(Type type) : super.make(type) {}
  override Obj decodeList(Obj?[] xeto, Bool checked := true) { xeto }
}

@Js
internal const class SingletonFactory : ScalarSpecFactory
{
  new make(Type type, Obj val, Str? altStr := null) : super(type) { this.val = val; this.altStr = altStr }
  const Obj val
  const Str? altStr
  override Obj? decodeScalar(Str str, Bool checked := true)
  {
    if (str == val.toStr) return val
    if (str == altStr) return val
    if (checked) throw ParseErr(str)
    return null
  }
}

@Js
internal const class StrFactory : ScalarSpecFactory
{
  new make(Type type) : super(type) {}
  override Obj? decodeScalar(Str str, Bool checked := true) { str }
}

@Js
internal const class BoolFactory : ScalarSpecFactory
{
  new make(Type type) : super(type) {}
  override Obj? decodeScalar(Str str, Bool checked := true) { Bool.fromStr(str, checked) }
}

@Js
internal const class IntFactory : ScalarSpecFactory
{
  new make(Type type) : super(type) {}
  override Obj? decodeScalar(Str str, Bool checked := true) { Int.fromStr(str, 10, checked) }
}

@Js
internal const class FloatFactory : ScalarSpecFactory
{
  new make(Type type) : super(type) {}
  override Obj? decodeScalar(Str str, Bool checked := true) { Float.fromStr(str, checked) }
}

@Js
internal const class DurationFactory : ScalarSpecFactory
{
  new make(Type type) : super(type) {}
  override Obj? decodeScalar(Str str, Bool checked := true) { Duration.fromStr(str, checked) }
}

@Js
internal const class DateFactory : ScalarSpecFactory
{
  new make(Type type) : super(type) {}
  override Obj? decodeScalar(Str str, Bool checked := true) { Date.fromStr(str, checked) }
}

@Js
internal const class TimeFactory : ScalarSpecFactory
{
  new make(Type type) : super(type) {}
  override Obj? decodeScalar(Str str, Bool checked := true) { Time.fromStr(str, checked) }
}

@Js
internal const class DateTimeFactory : ScalarSpecFactory
{
  new make(Type type) : super(type) {}
  override Obj? decodeScalar(Str str, Bool checked := true)
  {
    // allow UTC timezone to be omitted if "Z" offset
    if (str.endsWith("Z")) str += " UTC"
    return DateTime.fromStr(str, checked)
  }
}

@Js
internal const class UriFactory : ScalarSpecFactory
{
  new make(Type type) : super(type) {}
  override Obj? decodeScalar(Str str, Bool checked := true) { Uri.fromStr(str, checked) }
}

@Js
internal const class NumberFactory : ScalarSpecFactory
{
  new make(Type type) : super(type) {}
  override Obj? decodeScalar(Str str, Bool checked := true) { Number.fromStr(str, checked) }
}

@Js
internal const class RefFactory : ScalarSpecFactory
{
  new make(Type type) : super(type) {}
  override Obj? decodeScalar(Str str, Bool checked := true) { Ref.fromStr(str, checked) }
}

@Js
internal const class LinkFactory : DictSpecFactory
{
  new make(Type type) : super(type) {}
  override Dict decodeDict(Dict xeto, Bool checked := true) { Etc.linkWrap(xeto) }
}

@Js
internal const class LinksFactory : DictSpecFactory
{
  new make(Type type) : super(type) {}
  override Dict decodeDict(Dict xeto, Bool checked := true) { Etc.links(xeto) }
}

