//
// Copyright (c) 2024, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   4 Apr 2024  Brian Frank  Creation
//

using concurrent
using util
using xeto
using haystack::Etc
using haystack::Grid
using haystack::UnknownLibErr
using haystack::UnknownSpecErr

**
** LibNamespace implementation base class
**
@Js
abstract const class MNamespace : LibNamespace, CNamespace
{
  new make(MNamespace? base, NameTable names, LibVersion[] versions, |This->XetoLib|? loadSys)
  {
    this.base = base
    this.factories = base?.factories ?: MFactories()
    if (base != null)
    {
      // must reuse same name table
      if (base.names !== names) throw Err("base.names != names")

      // build unified list of versions and check overlay doesn't dup one
      acc := Str:LibVersion[:]
      base.versions.each |v| { acc[v.name] = v }
      versions.each |v|
      {
        if (acc[v.name] != null) throw Err("Base already defines $v")
        acc[v.name] = v
      }
      versions = acc.vals
      base.loadAllSync // force all to be loaded
    }

    // order versions by depends - also checks all internal constraints
    versions = LibVersion.orderByDepends(versions)

    // build list and map of entries
    list := MLibEntry[,]
    list.capacity = versions.size
    map := Str:MLibEntry[:]
    versions.each |x|
    {
      entry := base?.entriesMap?.get(x.name) ?: MLibEntry(x)
      list.add(entry)
      map.add(x.name, entry)
    }
    this.names       = names
    this.entriesList = list
    this.entriesMap  = map

    // load sys library
    if (loadSys == null)
    {
      // local ns does normal sync load
      this.sysLib = lib("sys")
    }
    else
    {
      // remote ns uses callback to read from boot buffer
      this.sysLib = loadSys(this)
      entry("sys").setOk(this.sysLib)
    }

    // check all loaded flag
    checkAllLoaded

    // now we can initialize sys for fast lookups
    this.sys = base?.sys ?: MSys(sysLib)
  }

//////////////////////////////////////////////////////////////////////////
// Identity
//////////////////////////////////////////////////////////////////////////

  const override NameTable names

  const override MNamespace? base

  override Bool isOverlay() { base != null }

  override once Str digest()
  {
    buf := Buf()
    keys := versions.dup.sort |a, b| { a.name <=> b.name }
    keys.each |v|
    {
      buf.print(v.name).print(" ").print(v.version.toStr).print("\n")
    }
    return buf.toDigest("SHA-1").toBase64Uri
  }

//////////////////////////////////////////////////////////////////////////
// Libs
//////////////////////////////////////////////////////////////////////////

  const override Lib sysLib

  override LibVersion[] versions()
  {
    entriesList.map |x->LibVersion| { x.version }
  }

  override LibVersion? version(Str name, Bool checked :=true)
  {
    entry(name, checked)?.version
  }

  override Bool hasLib(Str name)
  {
    entry(name, false) != null
  }

  override LibStatus? libStatus(Str name, Bool checked := true)
  {
    entry(name, checked)?.status
  }

  override Err? libErr(Str name)
  {
    entry(name).err
  }

  override Bool isAllLoaded()
  {
    libsRef.val != null
  }

  override Lib? lib(Str name, Bool checked := true)
  {
    e := entry(name, false)
    if (e == null)
    {
      if (checked) throw UnknownLibErr(name)
      return null
    }
    if (e.status.isNotLoaded) loadSyncWithDepends(e)
    if (e.status.isOk) return e.get
    throw e.err ?: Err("$name [$e.status]")
  }

  override Lib[] libs()
  {
    libs := libsRef.val as Lib[]
    if (libs != null) return libs
    loadAllSync
    return libsRef.val
  }

  override Void libsAllAsync(|Err?, Lib[]?| f)
  {
    libs := libsRef.val as Lib[]
    if (libs != null) { f(null, libs); return }
    loadAllAsync(f)
  }

  override Void libAsync(Str name, |Err?, Lib?| f)
  {
    e := entry(name, false)
    if (e == null) { f(UnknownLibErr(name), null); return }
    if (e.status.isOk) { f(null, e.get); return }
    if (e.status.isErr) { f(e.err, null); return }

    toLoadWithDepends := flattenUnloadedDepends([e])
    loadListAsync(toLoadWithDepends) |err|
    {
      if (err != null) return f(err, null)
      if (e.status.isErr)
        f(e.err, null)
      else
        f(null, e.get)
    }
  }

  override Void libListAsync(Str[] names, |Err?, Lib[]?| f)
  {
    // find all the libs already loaded and entries not loaded
    loaded := Lib[,]
    toLoad := MLibEntry[,]
    for (i := 0; i<names.size; ++i)
    {
      name := names[i]
      e := entry(name, false)
      if (e == null) { f(UnknownLibErr(name), null); return }
      if (e.status.isNotLoaded) toLoad.add(e)
      else if (e.status.isOk) loaded.add(e.get)
    }

    // if we have loaded them all then complete synchronously
    if (toLoad.isEmpty) return f(null, loaded)

    // flatten dependency chain and load
    toLoadWithDepends := flattenUnloadedDepends(toLoad)
    loadListAsync(toLoadWithDepends) |err|
    {
      // complete callback with error
      if (err != null) return f(err, null)

      // otherwise build result lib list
      result := Lib[,]
      names.each |name|
      {
        e := entry(name, false)
        if (e != null && e.status.isOk) result.add(e.get)
      }
      f(null, result)
    }
  }

  internal MLibEntry? entry(Str name, Bool checked := true)
  {
    entry := entriesMap.get(name) as MLibEntry
    if (entry != null) return entry
    if (checked) throw UnknownLibErr(name)
    return null
  }

  private MLibEntry[] flattenUnloadedDepends(MLibEntry[] entries)
  {
    // flatten depends
    toLoad := Str:MLibEntry[:]
    entries.each |entry| { doFlattenUnloadedDepends(toLoad, entry) }

    // now map them back in the correct dependency order
    return entriesList.findAll |e| { toLoad.containsKey(e.name) }
  }

  private Void doFlattenUnloadedDepends(Str:MLibEntry acc, MLibEntry e)
  {
    if (e.status.isNotLoaded) acc[e.name] = e
    e.version.depends.each |depend| { doFlattenUnloadedDepends(acc, entry(depend.name)) }
  }

//////////////////////////////////////////////////////////////////////////
// Loading
//////////////////////////////////////////////////////////////////////////

  private Void loadAllSync()
  {
    if (isAllLoaded) return
    entriesList.each |entry|
    {
      loadSync(entry)
    }
    checkAllLoaded
  }

  private Void loadSyncWithDepends(MLibEntry entry)
  {
    entry.version.depends.each |depend|
    {
      if (entry.status.isNotLoaded)
        loadSync(this.entry(depend.name))
    }
    loadSync(entry)
    checkAllLoaded
  }

  private Void loadSync(MLibEntry entry)
  {
    try
    {
      lib := doLoadSync(entry.version)
      entry.setOk(lib)
    }
    catch (Err e)
    {
      entry.setErr(e)
    }
  }

  internal Void checkAllLoaded()
  {
    allLoaded := entriesList.all |e| { e.status.isLoaded }
    if (!allLoaded) return
    acc := Lib[,]
    acc.capacity = entriesList.size
    entriesList.each |e| { if (e.status.isOk) acc.add(e.get) }
    libsRef.val = acc.toImmutable
  }

  private Void loadAllAsync(|Err?, Lib[]?| f)
  {
    if (isAllLoaded) { f(null, libs); return }

    // find all the libs not loaded yet
    toLoad := entriesList.findAll |e| { e.status.isNotLoaded }

    loadListAsync(toLoad) |err|
    {
      if (err != null) f(err, null)
      else f(null, libsRef.val)
    }
  }

  private Void loadListAsync(MLibEntry[] toLoad, |Err?| f)
  {
    doLoadListAsync(toLoad, 0, f)
  }

  private Void doLoadListAsync(MLibEntry[] toLoad, Int index, |Err?| f)
  {
    // load from pluggable loader
    doLoadAsync(toLoad[index].version) |err, libOrErr|
    {
      // handle top-level error
      if (err != null)
      {
        f(err)
        return
      }

      // update entry
      e := toLoad[index]
      lib := libOrErr as XetoLib
      if (lib != null)
        e.setOk(lib)
      else
        e.setErr(libOrErr)

      // recursively load next lib
      index++
      if (index < toLoad.size) return doLoadListAsync(toLoad, index, f)

      // we loaded all of them, now finish and invoke final callback
      checkAllLoaded

      // do not raise exception from client callback
      try
        f(null)
      catch(Err e2)
        e2.trace
    }
  }

  ** Load given version synchronously.  If the libary can not be
  ** loaed then raise exception to the caller of this method.
  abstract XetoLib doLoadSync(LibVersion v)

  ** Load a list of versions asynchronously and return result
  ** of either a XetoLib or Err (is error on server)
  abstract Void doLoadAsync(LibVersion v, |Err?, Obj?| f)

//////////////////////////////////////////////////////////////////////////
// Lookups
//////////////////////////////////////////////////////////////////////////

  override XetoSpec? type(Str qname, Bool checked := true)
  {
    colon := qname.index("::") ?: throw ArgErr("Invalid qname: $qname")
    libName := qname[0..<colon]
    typeName := qname[colon+2..-1]
    type := lib(libName, false)?.type(typeName, false)
    if (type != null) return type
    if (checked) throw UnknownSpecErr("Unknown data type: $qname")
    return null
  }

  override XetoSpec? spec(Str qname, Bool checked := true)
  {
    colon := qname.index("::") ?: throw ArgErr("Invalid qname: $qname")

    libName := qname[0..<colon]
    names := qname[colon+2..-1].split('.', false)

    spec := lib(libName, false)?.spec(names.first, false)
    for (i:=1; spec != null && i<names.size; ++i)
      spec = spec.slot(names[i], false)

    if (spec != null) return spec
    if (checked) throw UnknownSpecErr(qname)
    return null
  }

  override Dict? instance(Str qname, Bool checked := true)
  {
    colon := qname.index("::") ?: throw ArgErr("Invalid qname: $qname")

    libName := qname[0..<colon]
    name := qname[colon+2..-1]

    instance := lib(libName, false)?.instance(name, false)

    if (instance != null) return instance
    if (checked) throw haystack::UnknownRecErr(qname)
    return null
  }

  override Spec? unqualifiedType(Str name, Bool checked := true)
  {
    acc := Spec[,]
    libs.each |lib|
    {
      acc.addNotNull(lib.type(name, false))
    }
    if (acc.size == 1) return acc[0]
    if (acc.size > 1) throw Err("Ambiguous types for '$name' $acc")
    if (checked) throw UnknownTypeErr(name)
    return null
  }

  override Spec? global(Str name, Bool checked := true)
  {
    match :=  entriesList.eachWhile |entry|
    {
      entry.status.isOk ? entry.get.global(name, false) : null
    }
    if (match != null) return match
    if (checked) throw UnknownSpecErr(name)
    return null
  }

  override Dict? xmeta(Str qname, Bool checked := true)
  {
    XMeta(this).xmeta(qname, checked)
  }

  override SpecEnum? xmetaEnum(Str qname, Bool checked := true)
  {
    XMeta(this).xmetaEnum(qname, checked)
  }

  override Void eachType(|Spec| f)
  {
    eachLibForIter |lib|
    {
      lib.types.each |type| { f(type) }
    }
  }

  override Void eachInstance(|Dict| f)
  {
    eachLibForIter |lib|
    {
      lib.eachInstance(f)
    }
  }

  override Void eachInstanceThatIs(Spec type, |Dict, Spec| f)
  {
    eachInstance |x|
    {
      xSpecRef := x["spec"] as Ref
      if (xSpecRef == null) return
      xSpec := spec(xSpecRef.id, false)
      if (xSpec == null) return
      if (xSpec.isa(type)) f(x, xSpec)
    }
  }

  Void eachLibForIter(|Lib| f)
  {
    if (!isRemote)
    {
      libs.each(f)
    }
    else
    {
      entriesList.each |entry|
      {
        if (entry.status.isOk) f(entry.get)
      }
    }
  }

//////////////////////////////////////////////////////////////////////////
// Reflection
//////////////////////////////////////////////////////////////////////////

  override Spec? specOf(Obj? val, Bool checked := true)
  {
    if (val == null) return sys.none

    // dict handling
    dict := val as Dict
    if (dict != null)
    {
      specRef := dict["spec"] as Ref
      if (specRef == null) return sys.dict
      return spec(specRef.id, checked)
    }

    // look in Fantom class hiearchy
    type := val as Type ?: val.typeof
    for (Type? p := type; p.base != null; p = p.base)
    {
      spec := factories.typeToSpec(p)
      if (spec != null) return spec
      spec = p.mixins.eachWhile |m| { factories.typeToSpec(m) }
      if (spec != null) return spec
    }

    // fallbacks
    if (val is Scalar) return spec(((Scalar)val).qname, checked)
    if (type.fits(List#)) return sys.list
    if (type.fits(Grid#)) return sys.grid

    // if we didn't find a match and we aren't fully
    // loaded, then do a full load and try again
    if (!isAllLoaded && !isRemote)
    {
      loadAllSync
      if (isAllLoaded) return specOf(val, checked)
    }

    // cannot map to spec
    if (checked) throw UnknownSpecErr("No spec mapped for '$type'")
    return null
  }

  override Bool fits(XetoContext cx, Obj? val, Spec spec, Dict? opts := null)
  {
    if (opts == null) opts = Etc.dict0
    explain := XetoUtil.optLog(opts, "explain")
    if (explain == null)
      return Fitter(this, cx, opts).valFits(val, spec)
    else
      return ExplainFitter(this, cx, opts, explain).valFits(val, spec)
  }

  override Bool specFits(Spec a, Spec b, Dict? opts := null)
  {
    if (opts == null) opts = Etc.dict0
    explain := XetoUtil.optLog(opts, "explain")
    cx := NilXetoContext.val
    if (explain == null)
      return Fitter(this, cx, opts).specFits(a, b)
    else
      return ExplainFitter(this, cx, opts, explain).specFits(a, b)
  }

  override Obj? queryWhile(XetoContext cx, Dict subject, Spec query, Dict? opts, |Dict->Obj?| f)
  {
    Query(this, cx, opts).query(subject, query).eachWhile(f)
  }

  override Obj? instantiate(Spec spec, Dict? opts := null)
  {
    XetoUtil.instantiate(this, spec, opts ?: Etc.dict0)
  }

  override SpecChoice choice(Spec spec)
  {
    MChoice(this, spec)
  }

//////////////////////////////////////////////////////////////////////////
// Interfaces
//////////////////////////////////////////////////////////////////////////

  override Method? interfaceMethod(Spec spec, Str methodName)
  {
    interfaces.method(spec, methodName)
  }

  override Method? interfaceMethodOn(Obj target, Str methodName)
  {
    interfaces.methodOn(target, methodName)
  }

//////////////////////////////////////////////////////////////////////////
// Compile
//////////////////////////////////////////////////////////////////////////

  override Dict[] compileDicts(Str src, Dict? opts := null)
  {
    val := compileData(src, opts)
    if (val is List) return ((List)val).map |x->Dict| { x as Dict ?: throw IOErr("Expecting Xeto list of dicts, not ${x?.typeof}") }
    if (val is Dict) return Dict[val]
    throw IOErr("Expecting Xeto dict data, not ${val?.typeof}")
  }

  override Void writeData(OutStream out, Obj val, Dict? opts := null)
  {
    Printer(this, out, opts ?: Etc.dict0).xetoTop(val)
  }

  override Void print(Obj? val, OutStream out := Env.cur.out, Dict? opts := null)
  {
    Printer(this, out, opts ?: Etc.dict0).print(val)
  }

//////////////////////////////////////////////////////////////////////////
// CNamespace
//////////////////////////////////////////////////////////////////////////

  override Void eachSubtype(CSpec ctype, |CSpec| f)
  {
    type := (Spec)ctype
    eachType |x|
    {
      if (x.isa(type)) f((XetoSpec)x)
    }
  }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  override Void dump(OutStream out := Env.cur.out)
  {
    out.printLine("--- $typeof [$versions.size libs, allLoaded=$isAllLoaded] ---")
    versions.each |v| { out.printLine("  $v [" + libStatus(v.name) + "]") }
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  const MSys sys
  const MFactories factories
  internal const MLibEntry[] entriesList  // orderd by depends
  private const Str:MLibEntry entriesMap
  private const AtomicRef libsRef := AtomicRef()
  private const MInterfaces interfaces := MInterfaces(this)
}

**************************************************************************
**MLibEntry
**************************************************************************

@Js
internal const class MLibEntry
{
  new make(LibVersion version) { this.version = version }

  Str name() { version.name }

  const LibVersion version

  override Int compare(Obj that) { this.name <=> ((MLibEntry)that).name }

  LibStatus status() { statusRef.val }

  Err? err() { loadRef.val as Err }

  XetoLib get() { loadRef.val as XetoLib ?: throw Err("Not loaded: $name [$status]") }

  Void setOk(XetoLib lib)
  {
    loadRef.compareAndSet(null, lib)
    statusRef.val = LibStatus.ok
  }

  Void setErr(Err err)
  {
    loadRef.compareAndSet(null, err)
    statusRef.val = LibStatus.err
  }

  override Str toStr() { "MLibEntry $name [$status] $err" }

  private const AtomicRef statusRef := AtomicRef(LibStatus.notLoaded)
  private const AtomicRef loadRef := AtomicRef() // XetoLib or Err
}

