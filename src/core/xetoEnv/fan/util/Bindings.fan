//
// Copyright (c) 2024, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   6 Dec 2024  Brian Frank  Refactor from factory design
//

using concurrent
using xeto
using haystack::Coord
using haystack::Etc
using haystack::Filter
using haystack::Marker
using haystack::NA
using haystack::Number
using haystack::Remove
using haystack::Ref
using haystack::Span
using haystack::SpanMode
using haystack::Symbol

**
** Registry of mapping between Xeto specs and Fantom types for the VM
**
@Js
const class SpecBindings
{
  ** Current bindings for the VM
  static SpecBindings cur()
  {
    cur := curRef.val as SpecBindings
    if (cur != null) return cur
    curRef.compareAndSet(null, make)
    return curRef.val
  }
  private static const AtomicRef curRef := AtomicRef()

  ** Constructor
  new make()
  {
    initLoaders
    initBindings
  }

  ** Build registry of lib name to loader type:
  **
  **   index = ["xeto.bindings": "libName loaderType"]
  **
  ** Loader type is qname of SpecBindingLoader or we support
  ** the special key "ion" for IonBindingLoader
  private Void initLoaders()
  {
try
{
    Env.cur.index("xeto.bindings").each |str|
    {
      try
      {
        toks := str.split
        libName := toks[0]
        loaderType := toks[1]
        loaders.set(libName, loaderType)
      }
      catch (Err e) echo("ERR: Cannot init BindingLoader: $str\n  $e")
    }
}
catch (Err e)
{
  echo("WARN: Cannot read Env.cur.index: $e")
}
  }

  ** Setup the builtin bindings for sys, sys.comp, and ph
  private Void initBindings()
  {
    sys  := Pod.find("sys")
    xeto := Pod.find("xeto")
    hay  := Pod.find("haystack")

    // sys pod
    add(ObjBinding       (sys.type("Obj")))
    add(BoolBinding      (sys.type("Bool")))
    add(BufBinding       (sys.type("Buf")))
    add(FloatBinding     (sys.type("Float")))
    add(DateBinding      (sys.type("Date")))
    add(DateTimeBinding  (sys.type("DateTime")))
    add(DurationBinding  (sys.type("Duration")))
    add(IntBinding       (sys.type("Int")))
    add(StrBinding       (sys.type("Str")))
    add(TimeBinding      (sys.type("Time")))
    add(TimeZoneBinding  (sys.type("TimeZone")))
    add(UnitBinding      (sys.type("Unit")))
    add(UriBinding       (sys.type("Uri")))
    add(VersionBinding   (sys.type("Version")))

    // xeto pod
    add(CompLayoutBinding         (xeto.type("CompLayout")))
    add(LibDependBinding          (xeto.type("LibDepend")))
    add(LibDependVersionsBinding  (xeto.type("LibDependVersions")))
    add(LinkBinding               (xeto.type("Link")))
    add(LinksBinding              (xeto.type("Links")))
    add(SpecDictBinding           (xeto.type("Spec")))
    add(UnitQuantityBinding       (xeto.type("UnitQuantity")))

    // haystack pod
    add(CoordBinding     (hay.type("Coord")))
    add(FilterBinding    (hay.type("Filter")))
    add(MarkerBinding    (hay.type("Marker")))
    add(NoneBinding      (hay.type("Remove")))
    add(NABinding        (hay.type("NA")))
    add(NumberBinding    (hay.type("Number")))
    add(RefBinding       (hay.type("Ref")))
    add(SpanBinding      (hay.type("Span")))
    add(SpanModeBinding  (hay.type("SpanMode")))
    add(SymbolBinding    (hay.type("Symbol")))

    // fallbacks
    add(CompBinding("sys.comp::Comp", xeto.type("Comp")))
    add(dict)
  }

  ** Dict fallback
  const DictBinding dict := DictBinding("sys::Dict")

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

  ** Lookup a binding for a type and if found attempt to resolve to spec
  Spec? forTypeToSpec(LibNamespace ns, Type type)
  {
    binding := forType(type)
    if (binding == null) return null
    return ns.spec(binding.spec, false)
  }

  ** Add new spec binding
  Void add(SpecBinding b)
  {
    specMap.getOrAdd(b.spec, b)
    typeMap.getOrAdd(b.type.qname, b)
  }

  ** Return if we need to call load for given library name
  Bool needsLoad(Str libName, Version version)
  {
    loaders.containsKey(libName) && !loaded.containsKey(loadKey(libName, version))
  }

  ** Load bindings for given library
  Void load(Str libName, Version version, CSpec[] specs)
  {
    // check if we have a loader
    loaderType := loaders.get(libName)
    if (loaderType == null) return

    // mark this lib/version so we don't load it again
    loadKey := loadKey(libName, version)
    loaded.set(loadKey, loadKey)

    // instantiate it
    loader := (SpecBindingLoader)Type.find(loaderType).make

    // delegate to loader
    loader.load(this, libName, specs)
  }

  ** Load key to ensure we only load bindings per lib/version once
  private Str loadKey(Str libName, Version version)
  {
    "$libName $version"
  }

  private const ConcurrentMap loaders := ConcurrentMap() // libName -> loader qname
  private const ConcurrentMap loaded  := ConcurrentMap() // "$libName $version"
  private const ConcurrentMap specMap := ConcurrentMap() // qname -> qname
  private const ConcurrentMap typeMap := ConcurrentMap() // qname -> Type
}

**************************************************************************
** SpecBindingLoader
**************************************************************************

@Js
abstract const class SpecBindingLoader
{
  ** Add Xeto to Fantom bindings for the given library
  abstract Void load(SpecBindings acc, Str libName, CSpec[] specs)
}

**************************************************************************
** Base and Special Bindings
**************************************************************************

@Js
internal const class ObjBinding : SpecBinding
{
  new make(Type type) { this.spec = type.qname; this.type = type }
  const override Str spec
  const override Type type
  override Bool isScalar() { false }
  override Bool isDict() { false }
  override Dict decodeDict(Dict xeto) { throw UnsupportedErr("Obj") }
  override Obj? decodeScalar(Str xeto, Bool checked := true) { throw UnsupportedErr("Obj")  }
  override Str encodeScalar(Obj val) { throw UnsupportedErr("Obj") }
}

@Js
const class DictBinding : SpecBinding
{
  new make(Str spec, Type type := Dict#) { this.spec = spec; this.type = type }
  const override Str spec
  const override Type type
  override Bool isScalar() { false }
  override Bool isDict() { true }
  override Dict decodeDict(Dict xeto) { xeto }
  override final Obj? decodeScalar(Str xeto, Bool checked := true) { throw UnsupportedErr(spec) }
  override final Str encodeScalar(Obj val) { throw UnsupportedErr(spec) }
}

@Js
const class ScalarBinding : SpecBinding
{
  new make(Str spec, Type type) { this.spec = spec; this.type = type }
  const override Str spec
  const override Type type
  override Bool isScalar() { true }
  override Bool isDict() { false }
  override final Dict decodeDict(Dict xeto)  { throw UnsupportedErr(spec) }
  override Obj? decodeScalar(Str xeto, Bool checked := true)
  {
    type.method("fromStr", checked)?.call(xeto, checked)
  }
  override Str encodeScalar(Obj val) { val.toStr }
}

@Js
const class CompBinding : DictBinding
{
  new make(Str spec, Type type) : super(spec, type) {}
}

@Js
const class ImplDictBinding : DictBinding
{
  new make(Str spec, Type type) : super(spec, type) { impl = type.pod.type("M" + type.name) }
  const Type impl
  override Dict decodeDict(Dict xeto) { impl.make([xeto]) }
}

@Js
internal const class SingletonBinding : ScalarBinding
{
  new make(Str spec, Type type, Obj val, Str? altStr := null) : super(spec, type)
  {
    this.val = val
    this.altStr = altStr
  }
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
const class GenericScalarBinding : ScalarBinding
{
  new make(Str spec) : super(spec, Scalar#) {}
  override Obj? decodeScalar(Str str, Bool checked := true) { Scalar(spec, str) }
}

**************************************************************************
** Scalar Bindings
**************************************************************************

@Js
internal const class BoolBinding : ScalarBinding
{
  new make(Type type) : super(type.qname, type) {}
  override Obj? decodeScalar(Str str, Bool checked := true) { Bool.fromStr(str, checked) }
}

@Js
internal const class BufBinding : ScalarBinding
{
  new make(Type type) : super(type.qname, type) {}
  override Obj? decodeScalar(Str str, Bool checked := true) { Buf.fromBase64(str) }
  override Str encodeScalar(Obj v) { ((Buf)v).toBase64Uri }
}

@Js
internal const class CompLayoutBinding : ScalarBinding
{
  new make(Type type) : super("sys.comp::CompLayout", type) {}
  override Obj? decodeScalar(Str str, Bool checked := true) { CompLayout.fromStr(str, checked) }
}

@Js
internal const class CoordBinding : ScalarBinding
{
  new make(Type type) : super("ph::Coord", type) {}
  override Obj? decodeScalar(Str str, Bool checked := true) { Coord.fromStr(str, checked) }
}

@Js
internal const class DateBinding : ScalarBinding
{
  new make(Type type) : super(type.qname, type) {}
  override Obj? decodeScalar(Str str, Bool checked := true) { Date.fromStr(str, checked) }
}

@Js
internal const class DateTimeBinding : ScalarBinding
{
  new make(Type type) : super(type.qname, type) {}
  override Obj? decodeScalar(Str str, Bool checked := true)
  {
    // allow UTC timezone to be omitted if "Z" offset
    if (str.endsWith("Z")) str += " UTC"
    return DateTime.fromStr(str, checked)
  }
}

@Js
internal const class DurationBinding : ScalarBinding
{
  new make(Type type) : super(type.qname, type) {}
  override Obj? decodeScalar(Str str, Bool checked := true) { Duration.fromStr(str, checked) }
}

@Js
internal const class FilterBinding : ScalarBinding
{
  new make(Type type) : super("sys::Filter", type) {}
  override Obj? decodeScalar(Str str, Bool checked := true) { Filter.fromStr(str, checked) }
}

@Js
internal const class FloatBinding : ScalarBinding
{
  new make(Type type) : super(type.qname, type) {}
  override Obj? decodeScalar(Str str, Bool checked := true) { Float.fromStr(str, checked) }
}

@Js
internal const class IntBinding : ScalarBinding
{
  new make(Type type) : super(type.qname, type) {}
  override Obj? decodeScalar(Str str, Bool checked := true) { Int.fromStr(str, 10, checked) }
}

@Js
internal const class LibDependVersionsBinding : ScalarBinding
{
  new make(Type type) : super("sys::LibDependVersions", type) {}
  override Obj? decodeScalar(Str str, Bool checked := true) { LibDependVersions.fromStr(str, checked) }
}

@Js
internal const class MarkerBinding : SingletonBinding
{
  new make(Type type) : super("sys::Marker", type, Marker.val) {}
}

@Js
internal const class NABinding : SingletonBinding
{
  new make(Type type) : super("sys::NA", type, NA.val, "na") {}
}

@Js
internal const class NoneBinding : SingletonBinding
{
  new make(Type type) : super("sys::None", type, Remove.val, "none") {}
}

@Js
internal const class NumberBinding : ScalarBinding
{
  new make(Type type) : super("sys::Number", type) {}
  override Obj? decodeScalar(Str str, Bool checked := true) { Number.fromStrStrictUnit(str, checked) }
}

@Js
internal const class RefBinding : ScalarBinding
{
  new make(Type type) : super("sys::Ref", type) {}
  override Obj? decodeScalar(Str str, Bool checked := true) { Ref.fromStr(str, checked) }
}

@Js
internal const class SpanBinding : ScalarBinding
{
  new make(Type type) : super("sys::Span", type) {}
  override Obj? decodeScalar(Str str, Bool checked := true) { Span.fromStr(str, TimeZone.cur, checked) }
}

@Js
internal const class SpanModeBinding : ScalarBinding
{
  new make(Type type) : super("sys::SpanMode", type) {}
  override Obj? decodeScalar(Str str, Bool checked := true) { SpanMode.fromStr(str, checked) }
}

@Js
internal const class StrBinding : ScalarBinding
{
  new make(Type type) : super(type.qname, type) {}
  override Obj? decodeScalar(Str str, Bool checked := true) { str }
}

@Js
internal const class SymbolBinding : ScalarBinding
{
  new make(Type type) : super("ph::Symbol", type) {}
  override Obj? decodeScalar(Str str, Bool checked := true) { Symbol.fromStr(str) }
}

@Js
internal const class TimeBinding : ScalarBinding
{
  new make(Type type) : super(type.qname, type) {}
  override Obj? decodeScalar(Str str, Bool checked := true) { Time.fromStr(str, checked) }
}

@Js
internal const class TimeZoneBinding : ScalarBinding
{
  new make(Type type) : super(type.qname, type) {}
  override Obj? decodeScalar(Str str, Bool checked := true) { TimeZone.fromStr(str, checked) }
}

@Js
internal const class UnitBinding : ScalarBinding
{
  new make(Type type) : super(type.qname, type) {}
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
internal const class UnitQuantityBinding : ScalarBinding
{
  new make(Type type) : super("sys::UnitQuantity", type) {}
  override Obj? decodeScalar(Str str, Bool checked := true) { UnitQuantity.fromStr(str, checked) }
}

@Js
internal const class UriBinding : ScalarBinding
{
  new make(Type type) : super(type.qname, type) {}
  override Obj? decodeScalar(Str str, Bool checked := true) { Uri.fromStr(str, checked) }
}

@Js
internal const class VersionBinding : ScalarBinding
{
  new make(Type type) : super(type.qname, type) {}
  override Obj? decodeScalar(Str str, Bool checked := true) { Version.fromStr(str, checked) }
}

**************************************************************************
** Dict Bindings
**************************************************************************

@Js
internal const class LibDependBinding : DictBinding
{
  new make(Type type) : super("sys::LibDepend", type) {}
  override Dict decodeDict(Dict xeto) { MLibDepend(xeto) }
}

@Js
internal const class LinkBinding : DictBinding
{
  new make(Type type) : super("sys.comp::Link", type) {}
  override Dict decodeDict(Dict xeto) { Etc.linkWrap(xeto) }
}

@Js
internal const class LinksBinding : DictBinding
{
  new make(Type type) : super("sys.comp::Links", type) {}
  override Dict decodeDict(Dict xeto) { Etc.links(xeto) }
}

@Js
internal const class SpecDictBinding : DictBinding
{
  new make(Type type) : super("sys::Spec", type) {}
  override Dict decodeDict(Dict xeto) { xeto }
}

