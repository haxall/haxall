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
using haystack

**
** LibNamespace implementation base class
**
@Js
abstract const class MNamespace : LibNamespace, CNamespace
{
  new make(MNamespace? base, NameTable names, LibVersion[] versions, |This->XetoLib|? loadSys)
  {
    this.base = base
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

  const override LibNamespace? base

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
    if (e.status.isNotLoaded)
    {
      if (isRemote)
      {
        if (checked) throw UnsupportedErr("Must use libAsync [$e.version]")
        return null
      }
      else
      {
        loadSyncWithDepends(e)
      }
    }
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

  override Spec? type(Str qname, Bool checked := true)
  {
    colon := qname.index("::") ?: throw ArgErr("Invalid qname: $qname")
    libName := qname[0..<colon]
    typeName := qname[colon+2..-1]
    type := lib(libName, false)?.type(typeName, false)
    if (type != null) return type
    if (checked) throw UnknownSpecErr("Unknown data type: $qname")
    return null
  }

  override Spec? spec(Str qname, Bool checked := true)
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
    if (checked) throw UnknownRecErr(qname)
    return null
  }

  override Void specAsync(Str qname, |Err?, Spec?| f)
  {
    colon := qname.index("::") ?: throw ArgErr("Invalid qname: $qname")

    libName := qname[0..<colon]
    name := qname[colon+2..-1]

    libAsync(libName) |err, lib|
    {
      if (err != null) return f(err, null)
      spec := lib.spec(name, false)
      if (spec == null) return f(UnknownSpecErr(qname), null)
      f(null, spec)
    }
  }

  override Void instanceAsync(Str qname, |Err?, Dict?| f)
  {
    colon := qname.index("::") ?: throw ArgErr("Invalid qname: $qname")

    libName := qname[0..<colon]
    name := qname[colon+2..-1]

    libAsync(libName) |err, lib|
    {
      if (err != null) return f(err, null)
      instance := lib.instance(name, false)
      if (instance == null) return f(UnknownRecErr(qname), null)
      f(null, instance)
    }
  }

  override Spec? unqualifiedType(Str name, Bool checked := true)
  {
    if (!isRemote) loadAllSync
    acc := Spec[,]
    entriesList.each |entry|
    {
      if (entry.status.isOk) acc.addNotNull(entry.get.type(name, false))
    }
    if (acc.size == 1) return acc[0]
    if (acc.size > 1) throw Err("Ambiguous types for '$name' $acc")
    if (checked) throw UnknownTypeErr(name)
    return null
  }

  override Spec? global(Str name, Bool checked := true)
  {
    if (!isRemote) loadAllSync
    match := entriesList.eachWhile |entry|
    {
      entry.status.isOk ? entry.get.global(name, false) : null
    }
    if (match != null) return match
    if (checked) throw UnknownSpecErr(name)
    return null
  }

  override Spec? api(Str opName, Bool checked := true)
  {
    // try cache
    func := apiCache.get(opName)
    if (func != null) return func

    // parse to "lib.func" and try "lib.api::func" and "lib::func"
    func = findApi(opName)
    if (func != null)
    {
      apiCache[opName] = func
      return func
    }

    // no joy
    if (checked) throw UnknownSpecErr("API $opName.toCode")
    return null
  }

  private Spec? findApi(Str op)
  {
    dot := op.indexr(".")
    if (dot == null || dot == 0 || dot == op.size-1) return null

    libName  := op[0..<dot]
    funcName := op[dot+1..-1]

    lib := this.lib(libName+".api", false)
    if (lib == null) lib = this.lib(libName, false)
    if (lib == null) return null

    func := lib.global(funcName, false)
    if (func == null) return null
    if (!func.isFunc) return null
    return func
  }

  private const ConcurrentMap apiCache := ConcurrentMap()

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

  override Obj? eachTypeWhile(|Spec->Obj?| f)
  {
    eachLibForIterWhile |lib|
    {
      lib.types.eachWhile |type| { f(type) }
    }
  }

  override Void eachSubtype(Spec base, |Spec| f)
  {
    eachType |x|
    {
      if (XetoUtil.isDirectSubtype(x, base)) f(x)
    }
  }

  override Bool hasSubtypes(Spec base)
  {
    r := eachTypeWhile |x|
    {
      XetoUtil.isDirectSubtype(x, base) ? "yes" : null
    }
    return r != null
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

  Obj? eachLibForIterWhile(|Lib->Obj?| f)
  {
    if (!isRemote)
    {
      return libs.eachWhile(f)
    }
    else
    {
      return entriesList.eachWhile |entry|
      {
        if (entry.status.isOk)
          return f(entry.get)
        else
          return null
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
    bindings := SpecBindings.cur
    for (Type? p := type; p.base != null; p = p.base)
    {
      spec := bindings.forTypeToSpec(this, p)
      if (spec != null) return spec
      spec = p.mixins.eachWhile |m| { bindings.forTypeToSpec(this, m) }
      if (spec != null) return spec
    }

    // fallbacks
    if (val is Scalar) return spec(((Scalar)val).qname, checked)
    if (type.fits(List#)) return sys.list
    if (type.fits(Grid#)) return sys.grid
    if (type.fits(Function#)) return sys.func

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

  override Bool fits(Obj? val, Spec spec, Dict? opts := null)
  {
    if (opts == null) opts = Etc.dict0
    explain := XetoUtil.optLog(opts, "explain")
    cx := XetoContext.curx(false) ?: NilXetoContext.val
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

  override Obj? queryWhile(Dict subject, Spec query, Dict? opts, |Dict->Obj?| f)
  {
    cx := XetoContext.curx(false) ?: NilXetoContext.val
    return Query(this, cx, opts).query(subject, query).eachWhile(f)
  }

  override Obj? instantiate(Spec spec, Dict? opts := null)
  {
    Instantiator(this, opts ?: Etc.dict0).instantiate(spec)
  }

  override SpecChoice choice(Spec spec)
  {
    MChoice(this, spec)
  }

  override ReflectDict reflect(Dict rec, Spec? spec := null)
  {
    MReflectDict(this, rec, spec ?: specOf(rec))
  }

//////////////////////////////////////////////////////////////////////////
// Validation
//////////////////////////////////////////////////////////////////////////

  override ValidateReport validate(Obj? val, Spec? spec := null, Dict? opts := null)
  {
    // TODO: for now reuse existing fitsExplain
    items := MValidateItem[,]
    subject := val as Dict ?: Etc.dict0
    logger := |XetoLogRec x| { items.add(logRecToItem(subject, x)) }

    cx := ActorContext.curx(false) as XetoContext
    if (cx == null) Console.cur.warn("Must call LibNamespace.validate within XetoContext")

    opts = Etc.dictSet(opts, "explain", Unsafe(logger))
    if (spec == null) spec = specOf(val)
    fits(val, spec, opts)

    return MValidateReport(Dict[subject], items)
  }

  override ValidateReport validateAll(Dict[] subjects, Dict? opts := null)
  {
    // TODO: for now reuse existing fitsExplain
    items := MValidateItem[,]
    Dict? subject
    logger := |XetoLogRec x| { items.add(logRecToItem(subject, x)) }

    opts = Etc.dictSet(opts, "explain", Unsafe(logger))
    subjects.each |x| { subject = x; fits(x, specOf(x), opts) }

    return MValidateReport(subjects, items)
  }

  private MValidateItem logRecToItem(Dict subject, XetoLogRec x)
  {
    level := x.level === LogLevel.err ? ValidateLevel.err : ValidateLevel.warn
    msg   := x->msg.toStr
    slot  := null

    if (msg.startsWith("Slot '"))
    {
      end := msg.index("': ")
      slot = msg[6..<end]
      msg  = msg[end+3..-1]
    }

    return MValidateItem(level, subject, slot, msg)
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

  override Void ceachTypeThatIs(CSpec ctype, |CSpec| f)
  {
    type := (Spec)ctype
    eachType |x|
    {
      if (x.isa(type)) f((CSpec)x)
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
  internal const MLibEntry[] entriesList  // orderd by depends
  private const Str:MLibEntry entriesMap
  private const AtomicRef libsRef := AtomicRef()
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

