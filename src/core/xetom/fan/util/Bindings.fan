//
// Copyright (c) 2024, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   6 Dec 2024  Brian Frank  Refactor from factory design
//

using concurrent
using util
using xeto
using haystack

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
  **   // use pod loader
  **   index = ["xeto.bindings": "libName"]
  **
  **   // use specific SpecBindingLoader class
  **   index = ["xeto.bindings": "libName ion::XetoBindingLoader"]
  **
  ** The loaderType is qname of SpecBindingLoader Fantom class
  ** or if is a pod name we load via PodBindingLoader
  private Void initLoaders()
  {
    Env.cur.indexByPodName("xeto.bindings").each |list, podName|
    {
      list.each |str|
      {
        try
        {
          toks := str.split
          libName := toks[0]
          if (toks.size == 1)
          {
            // lib -> podName
            loaders.set(libName, podName)
          }
          else
          {
            // lib -> fantom type
            loaders.set(libName, toks[1])
          }
        }
        catch (Err e) echo("ERR: Cannot init BindingLoader: $podName: $str\n  $e")
      }
    }
  }

  ** Setup the builtin bindings for sys, sys.comp, and ph
  private Void initBindings()
  {
    sys  := Pod.find("sys")
    xeto := Pod.find("xeto")
    hay  := Pod.find("haystack")

    // sys pod
    add(ObjBinding       ("sys::Obj", sys.type("Obj")))
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
    add(MarkerBinding             (xeto.type("Marker")))
    add(RefBinding                (xeto.type("Ref")))
    add(SpecDictBinding           (xeto.type("Spec")))
    add(UnitQuantityBinding       (xeto.type("UnitQuantity")))

    // haystack pod
    add(CoordBinding     (hay.type("Coord")))
    add(FilterBinding    (hay.type("Filter")))
    add(NoneBinding      (hay.type("Remove")))
    add(NABinding        (hay.type("NA")))
    add(NumberBinding    (hay.type("Number")))
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

  ** Map thunk for given spec or raise exception
  Thunk thunk(Spec spec)
  {
    loadLib(spec.lib).loadThunk(spec)
  }

  ** Add new spec binding
  SpecBinding add(SpecBinding b)
  {
    b = specMap.getOrAdd(b.spec, b)
    b = typeMap.getOrAdd(b.type.qname, b)
    return b
  }

  ** Return if we need to call load for given library name
  Bool needsLoad(Str libName, Version version)
  {
    loaders.containsKey(libName) && !loaded.containsKey(loadKey(libName, version))
  }

  ** Load bindings for given library
  SpecBindingLoader loadLib(Lib lib)
  {
    load(lib.name, lib.version)
  }

  ** Load bindings for given library
  SpecBindingLoader load(Str libName, Version version)
  {
    // check if we have a loader
    loaderType := loaders.get(libName) as Str
    if (loaderType == null) return SpecBindingLoader()

    // mark this lib/version so we don't load it again
    loadKey := loadKey(libName, version)
    loaded.set(loadKey, loadKey)

    // create loader from SpecLoader qname or pod name
    SpecBindingLoader? loader
    try
    {
      if (loaderType.contains("::"))
      {
        loader = Type.find(loaderType).make
      }
      else
      {
        loader = PodBindingLoader(Pod.find(loaderType))
      }
    }
    catch (Err e)
    {
      warn("SpecBindings cannot load xeto lib '$libName': $e")
      return SpecBindingLoader()
    }

    // load at the library level
    loader.loadLib(this, libName)

    // return loader to caller to load individual specs
    return loader
  }

  ** Load key to ensure we only load bindings per lib/version once
  private Str loadKey(Str libName, Version version)
  {
    "$libName $version"
  }

  ** Log warning
  private Void warn(Str msg)
  {
    Console.cur.warn(msg)
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
const class SpecBindingLoader
{
  ** Map Xeto to Fantom bindings for the given library
  virtual Void loadLib(SpecBindings acc, Str libName) {}

  ** Map Xeto to Fantom bindings for the spec if applicable
  virtual SpecBinding? loadSpec(SpecBindings acc, CSpec spec) { null }

  ** Default behavior for loading spec via pod reflection
  SpecBinding? loadSpecReflect(SpecBindings acc, Pod pod, CSpec spec)
  {
    // lookup Fantom type with same name
    type := pod.type(spec.name, false)
    if (type == null) return null

    // clone CompBindings with this spec/type
    compBase := spec.cbase.binding as CompBinding
    if (compBase != null) return acc.add(compBase.clone(spec.qname, type))

    // assume Dict mixins are MDictImpl
    if (type.fits(Dict#)) return acc.add(ImplDictBinding(spec.qname,type))

    // enums are scalars
    if (type.fits(Enum#)) return acc.add(ScalarBinding(spec.qname, type))

    // check for hx::Ext
    if (type.name.endsWith("Ext")) return acc.add(ObjBinding(spec.qname, type))

    // no joy
    return null
  }

  ** Resolve thunk for given spec
  virtual Thunk loadThunk(Spec spec) { throw UnsupportedErr("Thunks not supported") }
}

**************************************************************************
** PodBindingLoader
**************************************************************************

@Js
const class PodBindingLoader : SpecBindingLoader
{
  new make(Pod pod)
  {
    this.pod = pod
  }

  const Pod pod

  const Type? fantomFuncsType

  override SpecBinding? loadSpec(SpecBindings acc, CSpec spec)
  {
    loadSpecReflect(acc, pod, spec)
  }

  override Thunk loadThunk(Spec spec)
  {
    // check for fantom method thunk
    thunk := loadThunkFantom(spec)
    if (thunk != null) return thunk

    throw UnsupportedErr("No funcs registered for pod: $pod.name")
  }

  private Thunk? loadThunkFantom(Spec spec)
  {
    // resolve fantom type BaseFuncs where base is spec name
    // of the libExt otherwise the last name of the dotted lib name
    lib := spec.lib
    libExt := lib.meta["libExt"]?.toStr
    base := libExt != null ? XetoUtil.qnameToName(libExt) : XetoUtil.lastDottedName(lib.name).capitalize
    typeName := base + "Funcs"
    type := pod.type(typeName, false)
    // echo("~~> $spec.lib base=$base -> $typeName -> $type")
    if (type == null) return null

    // method name is same as func; special cases handled with _name
    funcName := spec.name
    method := type.method(funcName, false) ?: type.method("_" + funcName, false)
    if (method == null) return null

    // verify method has facet
    if (!method.hasFacet(Api#)) throw Err("Method missing @Api facet: $method.qname")
    return StaticMethodThunk(method)
  }
}

**************************************************************************
** Base and Special Bindings
**************************************************************************

@Js
internal const class ObjBinding : SpecBinding
{
  new make(Str spec, Type type) { this.spec = spec; this.type = type }
  const override Str spec
  const override Type type
  override Bool isScalar() { false }
  override Bool isDict() { false }
  override Dict decodeDict(Dict xeto) { throw UnsupportedErr("Obj") }
  override Obj? decodeScalar(Str xeto, Bool checked := true) { throw UnsupportedErr("Obj")  }
  override Str encodeScalar(Obj val) { throw UnsupportedErr("Obj") }
  override Bool isInheritable() { false }
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
  override Bool isInheritable() { true }
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
  override Bool isInheritable() { false }
}

@Js
const class CompBinding : DictBinding
{
  new make(Str spec, Type type) : super(spec, type) {}
  virtual This clone(Str spec, Type type) { make(spec, type) }
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

