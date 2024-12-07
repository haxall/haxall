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
** Bindings initialization
**
@Js
class BindingsInit
{
  static Void init(SpecBindings acc)
  {
    sys  := Pod.find("sys")
    xeto := Pod.find("xeto")
    hay  := Pod.find("haystack")

    // sys pod
    add(acc, ObjBinding       (sys.type("Obj")))
    add(acc, BoolBinding      (sys.type("Bool")))
    add(acc, BufBinding       (sys.type("Buf")))
    add(acc, FloatBinding     (sys.type("Float")))
    add(acc, DateBinding      (sys.type("Date")))
    add(acc, DateTimeBinding  (sys.type("DateTime")))
    add(acc, DurationBinding  (sys.type("Duration")))
    add(acc, IntBinding       (sys.type("Int")))
    add(acc, StrBinding       (sys.type("Str")))
    add(acc, TimeBinding      (sys.type("Time")))
    add(acc, TimeZoneBinding  (sys.type("TimeZone")))
    add(acc, UnitBinding      (sys.type("Unit")))
    add(acc, UriBinding       (sys.type("Uri")))
    add(acc, VersionBinding   (sys.type("Version")))

    // xeto pod
    add(acc, CompLayoutBinding         (xeto.type("CompLayout")))
    add(acc, LibDependBinding          (xeto.type("LibDepend")))
    add(acc, LibDependVersionsBinding  (xeto.type("LibDependVersions")))
    add(acc, LinkBinding               (xeto.type("Link")))
    add(acc, LinksBinding              (xeto.type("Links")))
    add(acc, SpecDictBinding           (xeto.type("Spec")))
    add(acc, UnitQuantityBinding       (xeto.type("UnitQuantity")))

    // haystack pod
    add(acc, CoordBinding     (hay.type("Coord")))
    add(acc, FilterBinding    (hay.type("Filter")))
    add(acc, MarkerBinding    (hay.type("Marker")))
    add(acc, NoneBinding      (hay.type("Remove")))
    add(acc, NABinding        (hay.type("NA")))
    add(acc, NumberBinding    (hay.type("Number")))
    add(acc, RefBinding       (hay.type("Ref")))
    add(acc, SpanBinding      (hay.type("Span")))
    add(acc, SpanModeBinding  (hay.type("SpanMode")))
    add(acc, SymbolBinding    (hay.type("Symbol")))

    // dict fallback
    add(acc, DictBinding("sys::Dict", hay.type("Dict")))
  }

  static Void add(SpecBindings acc, SpecBinding b)
  {
    acc.add(b)
  }
}

**************************************************************************
** Special Bindings
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
  new make(Type type) : super("sys::LibDependVersion", type) {}
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
  new make(Type type) : super("sys::NA", type, NA.val) {}
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
  override Obj? decodeScalar(Str str, Bool checked := true) { str }
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

