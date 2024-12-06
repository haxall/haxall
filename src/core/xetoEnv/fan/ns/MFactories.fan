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
using haystack::Filter
using haystack::Marker
using haystack::NA
using haystack::Number
using haystack::Remove
using haystack::Ref
using haystack::Span
using haystack::SpanMode

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
    loadersMap["sys"]      = SysFactoryLoader()
    loadersMap["sys.comp"] = SysCompFactoryLoader()
    loadersMap["ph"]       = PhFactoryLoader()
  }

  ** Lookup installed factory loader by libName
  SpecFactoryLoader? loader(Str libName) { loadersMap.get(libName) }
  private const ConcurrentMap loadersMap := ConcurrentMap()

  ** Check if we need to install new loader for given lib.
  Void install(Str libName, Dict libMeta)
  {
    // look for the lib meta key fantomPodName
    podName := libMeta["fantomPodName"] as Str
    if (podName == null || loadersMap[podName] != null) return

    // if the pod defines a custoj XetoFactoryLoader class we use
    // that, otherwise create an instance of StandardFactoryLoader
    SpecFactoryLoader? loader := null
    try
    {
      pod := Pod.find(podName)
      custom := pod.type("XetoFactoryLoader", false)
      if (custom != null)
        loader = custom.make
      else
        loader = StandardFactoryLoader(podName)
    }
    catch (Err e)
    {
      echo("ERROR: XetoSpecLaoder cannot be created: $libName\n $e")
      return
    }

    // add to our map
    loadersMap.set(libName, loader)
  }

  ** Default dict factory
  const SpecFactory dict := DictFactory()

  ** Map fantom type to its spec (called by specOf)
  Spec? typeToSpec(LibNamespace ns, Type type)
  {
    qname := typeToSpecMap.get(type.qname)
    if (qname == null) return null
    return ns.spec(qname, false)
  }

  ** Map spec to its fantom type (called by Spec.fantomType)
  Type? specToType(Str qname)
  {
    specToTypeMap.get(qname)
  }

  ** Map Fantom type to its spec qname
  Void map(Type type, Str qnameSpec)
  {
    qnameType := type.qname
    if (typeToSpecMap[qnameType] == null) typeToSpecMap.set(qnameType, qnameSpec)
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

  private const ConcurrentMap typeToSpecMap := ConcurrentMap() // qname:qname
  private const ConcurrentMap specToTypeMap := ConcurrentMap() // qname:Type
}

**************************************************************************
** Buildin FactoryLoaders
**************************************************************************

@Js
internal const class SysFactoryLoader : SpecFactoryLoader
{
  override Str:SpecFactory load(Str libName, Str[] specNames)
  {
    sys  := Pod.find("sys")
    xeto := Pod.find("xeto")
    hay  := Pod.find("haystack")
    str  := StrFactory()
    return [

      // sys pod
      "Obj":      ObjFactory(sys.type("Obj")),
      "Bool":     BoolFactory(sys.type("Bool")),
      "Buf":      BufFactory(sys.type("Buf")),
      "Float":    FloatFactory(sys.type("Float")),
      "Int":      IntFactory(sys.type("Int")),
      "Date":     DateFactory(sys.type("Date")),
      "DateTime": DateTimeFactory(sys.type("DateTime")),
      "Duration": DurationFactory(sys.type("Duration")),
      "Str":      str,
      "Time":     TimeFactory(sys.type("Time")),
      "TimeZone": TimeZoneFactory(sys.type("TimeZone")),
      "Unit":     UnitFactory(sys.type("Unit")),
      "Uri":      UriFactory(sys.type("Uri")),
      "Version":  ScalarSpecFactory(sys.type("Version")),

      // xeto pod
      "Func":              InterfaceSpecFactory(xeto.type("Function")),
      "LibDepend":         LibDependFactory(xeto.type("LibDepend")),
      "LibDependVersions": LibDependVersionsFactory(xeto.type("LibDependVersions")),
      "Spec":              DictFactory(xeto.type("Spec")),
      "UnitQuantity":      UnitQuantityFactory(xeto.type("UnitQuantity")),

      // haystack pod
      "Filter":   FilterFactory(hay.type("Filter")),
      "Marker":   SingletonFactory(hay.type("Marker"), Marker.val),
      "None":     SingletonFactory(hay.type("Remove"), Remove.val, "none"),
      "NA":       SingletonFactory(hay.type("NA"),     NA.val, "na"),
      "Number":   NumberFactory(hay.type("Number")),
      "Ref":      RefFactory(hay.type("Ref")),
      "Span":     SpanFactory(hay.type("Span")),
      "SpanMode": SpanModeFactory(hay.type("SpanMode")),
      "List":     ListFactory(),
      "Dict":     DictFactory(),
    ]
  }
}

@Js
internal const class SysCompFactoryLoader : SpecFactoryLoader
{
  override Str:SpecFactory load(Str libName, Str[] specNames)
  {
    pod := Pod.find("xeto")
    return [
      "Comp":       CompSpecFactory(Comp#),
      "CompLayout": CompLayoutFactory(pod.type("CompLayout")),
      "Link":       LinkFactory(pod.type("Link")),
      "Links":      LinksFactory(pod.type("Links")),
    ]
  }
}

@Js
internal const class PhFactoryLoader : SpecFactoryLoader
{
  override Str:SpecFactory load(Str libName, Str[] specNames)
  {
    pod := Pod.find("haystack")
    return [
      "Coord":    ScalarSpecFactory(pod.type("Coord")),
      "Symbol":   ScalarSpecFactory(pod.type("Symbol")),
    ]
  }
}

**************************************************************************
** StandardFactoryLoader
**************************************************************************

**
** Standard factory loader mapped by the fantomPodName lib meta
**
@Js
internal const class StandardFactoryLoader : SpecFactoryLoader
{
  new make(Str podName) { this.podName = podName }

  const Str podName

  override Str:SpecFactory load(Str libName, Str[] specNames)
  {
    acc := Str:SpecFactory[:]
    pod := Pod.find(podName)
    doLoad(acc, pod, specNames)
    return acc
  }

  Void doLoad(Str:SpecFactory acc, Pod pod, Str[] specNames)
  {
    specNames.each |name|
    {
      if (acc[name] != null) return
      type := pod.type(name, false)
      if (name.endsWith("View"))
      {
        acc[name] = Type.find("ion::ViewSpecFactory").make([type])
      }
      else if (type != null)
      {
        // have Fantom type for this spec
        if (type.fits(Comp#)) acc[name] = CompSpecFactory(type)
        else if (type.fits(Enum#)) acc[name] = ScalarSpecFactory(type)
        else if (type.fits(Dict#)) acc[name] = ImplDictFactory(type)
      }
    }
  }
}

**************************************************************************
** Special Factories
**************************************************************************

@Js
internal const class ObjFactory : SpecFactory
{
  new make(Type type) { this.type = type }
  const override Type type
  override Bool isScalar() { false }
  override Bool isDict() { false }
  override Bool isList() { false }
  override Bool isInterface() { false }
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
const class ImplDictFactory : DictSpecFactory
{
  new make(Type type) : super(type) { impl = type.pod.type("M" + type.name) }
  const Type impl
  override Dict decodeDict(Dict xeto, Bool checked := true) { impl.make([xeto]) }
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
const class GenericScalarFactory : ScalarSpecFactory
{
  new make(Str qname) : super(Scalar#) { this.qname = qname }
  const Str qname
  override Obj? decodeScalar(Str str, Bool checked := true) { Scalar(qname, str) }
}

@Js
internal const class StrFactory : ScalarSpecFactory
{
  new make() : super(Str#) {}
  override Obj? decodeScalar(Str str, Bool checked := true) { str }
}

**************************************************************************
** Scalar Factories
**************************************************************************

@Js
internal const class BoolFactory : ScalarSpecFactory
{
  new make(Type type) : super(type) {}
  override Obj? decodeScalar(Str str, Bool checked := true) { Bool.fromStr(str, checked) }
}

@Js
internal const class BufFactory : ScalarSpecFactory
{
  new make(Type type) : super(type) {}
  override Obj? decodeScalar(Str str, Bool checked := true) { Buf.fromBase64(str) }
  override Str encodeScalar(Obj v) { ((Buf)v).toBase64Uri }
}

@Js
internal const class CompLayoutFactory : ScalarSpecFactory
{
  new make(Type type) : super(type) {}
  override Obj? decodeScalar(Str str, Bool checked := true) { CompLayout.fromStr(str, checked) }
}

@Js
internal const class DateFactory : ScalarSpecFactory
{
  new make(Type type) : super(type) {}
  override Obj? decodeScalar(Str str, Bool checked := true) { Date.fromStr(str, checked) }
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
internal const class DurationFactory : ScalarSpecFactory
{
  new make(Type type) : super(type) {}
  override Obj? decodeScalar(Str str, Bool checked := true) { Duration.fromStr(str, checked) }
}
@Js
internal const class FilterFactory : ScalarSpecFactory
{
  new make(Type type) : super(type) {}
  override Obj? decodeScalar(Str str, Bool checked := true) { Filter.fromStr(str, checked) }
}

@Js
internal const class FloatFactory : ScalarSpecFactory
{
  new make(Type type) : super(type) {}
  override Obj? decodeScalar(Str str, Bool checked := true) { Float.fromStr(str, checked) }
}

@Js
internal const class IntFactory : ScalarSpecFactory
{
  new make(Type type) : super(type) {}
  override Obj? decodeScalar(Str str, Bool checked := true) { Int.fromStr(str, 10, checked) }
}

@Js
internal const class LibDependVersionsFactory : ScalarSpecFactory
{
  new make(Type type) : super(type) {}
  override Obj? decodeScalar(Str str, Bool checked := true) { LibDependVersions.fromStr(str, checked) }
}

@Js
internal const class NumberFactory : ScalarSpecFactory
{
  new make(Type type) : super(type) {}
  override Obj? decodeScalar(Str str, Bool checked := true) { Number.fromStrStrictUnit(str, checked) }
}

@Js
internal const class RefFactory : ScalarSpecFactory
{
  new make(Type type) : super(type) {}
  override Obj? decodeScalar(Str str, Bool checked := true) { Ref.fromStr(str, checked) }
}

@Js
internal const class SpanFactory : ScalarSpecFactory
{
  new make(Type type) : super(type) {}
  override Obj? decodeScalar(Str str, Bool checked := true) { Span.fromStr(str, TimeZone.cur, checked) }
}

@Js
internal const class SpanModeFactory : ScalarSpecFactory
{
  new make(Type type) : super(type) {}
  override Obj? decodeScalar(Str str, Bool checked := true) { SpanMode.fromStr(str, checked) }
}

@Js
internal const class TimeFactory : ScalarSpecFactory
{
  new make(Type type) : super(type) {}
  override Obj? decodeScalar(Str str, Bool checked := true) { Time.fromStr(str, checked) }
}

@Js
internal const class TimeZoneFactory : ScalarSpecFactory
{
  new make(Type type) : super(type) {}
  override Obj? decodeScalar(Str str, Bool checked := true) { TimeZone.fromStr(str, checked) }
}

@Js
internal const class UnitFactory : ScalarSpecFactory
{
  new make(Type type) : super(type) {}
  override Obj? decodeScalar(Str str, Bool checked := true)
  {
    // only the primary symbol is allowed
    unit := Unit.fromStr(str, false)
    if (unit != null && unit.symbol != str) unit = null
    if (unit != null) return unit
    if (checked) throw ParseErr("Invalid unit symbol: $str")
    return null
  }
}

@Js
internal const class UnitQuantityFactory : ScalarSpecFactory
{
  new make(Type type) : super(type) {}
  override Obj? decodeScalar(Str str, Bool checked := true) { UnitQuantity.fromStr(str, checked) }
}

@Js
internal const class UriFactory : ScalarSpecFactory
{
  new make(Type type) : super(type) {}
  override Obj? decodeScalar(Str str, Bool checked := true) { Uri.fromStr(str, checked) }
}

**************************************************************************
** Dict Factories
**************************************************************************

@Js
internal const class LibDependFactory : DictSpecFactory
{
  new make(Type type) : super(type) {}
  override Dict decodeDict(Dict xeto, Bool checked := true) { MLibDepend(xeto) }
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

