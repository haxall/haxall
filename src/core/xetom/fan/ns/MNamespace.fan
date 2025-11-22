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
** Namespace implementation base class
**
@Js
const class MNamespace : Namespace, CNamespace
{

//////////////////////////////////////////////////////////////////////////
// Construction
//////////////////////////////////////////////////////////////////////////

  **
  ** Constructor options:
  **   - uncheckedDepends: load with unmet depends (libs just go into err)
  **
  new make(MEnv env, LibVersion[] versions, Dict opts := Etc.dict0)
  {
    this.envRef = env
    this.opts = opts
    this.companionRecs = opts["companionRecs"]

    // order versions by depends and check all dependencies
    dependErrs := Str:Err[:]
    this.versions = LibVersion.checkDepends(versions, dependErrs)

    // fail fast on depend error unless options has uncheckedDepends flag
    if (!dependErrs.isEmpty && opts.missing("uncheckedDepends"))
      throw dependErrs.vals.first

    // first one must be sys
    sysVer := this.versions[0]
    if (sysVer.name != "sys") throw Err("Must include 'sys' lib")
    this.sysLib = initEntry(sysVer, null).lib
    this.sys = MSys(sysLib)

    // build list/map of entries (just process sys again from cache)
    libs := Lib[,]
    libs.capacity = versions.size
    this.versions.each |v|
    {
      // init entry for LibVersion
      entry := initEntry(v, dependErrs[v.name])

      // add to our lookup tables
      entriesMap.add(v.name, entry)
      libs.addNotNull(entry.lib)
    }
    this.libs = libs
  }

  private MLibEntry initEntry(LibVersion version, Err? dependErr)
  {
    // if depend error then immediately return error entry
    if (dependErr != null) return MLibEntry(version, dependErr)

    // get from cache or compile
    try
    {
      lib := envRef.getOrCompile(this, version)
      return MLibEntry(version, lib)
    }
    catch (Err err)
    {
     return MLibEntry(version, err)
    }
  }

//////////////////////////////////////////////////////////////////////////
// Identity
//////////////////////////////////////////////////////////////////////////

  override XetoEnv env() { envRef }
  const MEnv envRef

  Bool isRemote() { env.isRemote }

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

  const CompanionRecs? companionRecs

//////////////////////////////////////////////////////////////////////////
// Libs
//////////////////////////////////////////////////////////////////////////

  override const Lib sysLib

  override const Lib[] libs

  override const LibVersion[] versions

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

  override Err? libErr(Str name, Bool checked := true)
  {
    entry(name, checked)?.err
  }

  override Lib? lib(Str name, Bool checked := true)
  {
    e := entry(name, false)
    if (e == null)
    {
      if (checked) throw UnknownLibErr(name)
      return null
    }
    if (e.status.isOk) return e.get
    if (checked) throw LibLoadErr("Lib '$name' could not be loaded", e.err)
    return null
  }

  internal MLibEntry? entry(Str name, Bool checked := true)
  {
    entry := entriesMap.get(name) as MLibEntry
    if (entry != null) return entry
    if (checked) throw UnknownLibErr(name)
    return null
  }

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
      spec = spec.member(names[i], false)

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

  override Spec[] mixinsFor(Spec type)
  {
    acc := Str:Spec[:]
    type.eachInherited |x|
    {
      libs.each |lib|
      {
        m := lib.mixinFor(x, false)
        if (m != null) acc[m.qname] = m
      }
    }
    return acc.vals.toImmutable
  }

  override Spec specx(Spec spec)
  {
    mixins := mixinsFor(spec)
    if (mixins.isEmpty) return spec
    return XSpec(spec, mixins)
  }

  override Void eachType(|Spec| f)
  {
    libs.each |lib|
    {
      lib.types.each |type| { f(type) }
    }
  }

  override Obj? eachTypeWhile(|Spec->Obj?| f)
  {
    libs.eachWhile |lib|
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
    libs.each |lib|
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

//////////////////////////////////////////////////////////////////////////
// Unqualified Lookups
//////////////////////////////////////////////////////////////////////////

  override Spec? unqualifiedType(Str name, Bool checked := true)
  {
    acc := unqualifiedTypes(name)
    if (acc.size == 1) return acc[0]
    if (acc.size > 1) throw AmbiguousSpecErr("Ambiguous type for '$name' $acc")
    if (checked) throw UnknownTypeErr(name)
    return null
  }

  override Spec[] unqualifiedTypes(Str name)
  {
    acc := Spec[,]
    libs.each |lib|
    {
      acc.addNotNull(lib.type(name, false))
    }
    return acc
  }

  override Spec? unqualifiedMeta(Str name, Bool checked := true)
  {
    acc := unqualifiedMetas(name)
    if (acc.size == 1) return acc[0]
    if (acc.size > 1) throw AmbiguousSpecErr("Ambiguous meta for '$name' $acc")
    if (checked) throw UnknownSpecErr(name)
    return null
  }

  override Spec[] unqualifiedMetas(Str name)
  {
    acc := Spec[,]
    libs.each |lib|
    {
      acc.addNotNull(lib.metaSpec(name, false))
    }
    return acc
  }

  override Spec? unqualifiedFunc(Str name, Bool checked := true)
  {
    map := funcMapRef.val as Str:Obj
    if (map == null) funcMapRef.val = map = loadFuncMap
    list := map[name] as Spec[]
    if (list != null)
    {
      if (list.size == 1) return list.first
      throw AmbiguousSpecErr("Ambiguous func for '$name' $list")
    }
    if (checked) throw UnknownFuncErr(name)
    return null
  }

  override Spec[] unqualifiedFuncs(Str name)
  {
    map := funcMapRef.val as Str:Obj
    if (map == null) funcMapRef.val = map = loadFuncMap
    return map[name] ?: Spec#.emptyList
  }

  private Str:Obj loadFuncMap()
  {
    // we build cache of funcs by name, values are Spec[]
    acc := Str:Obj[:]
    libs.each |lib|
    {
      lib.funcs.each |spec|
      {
        name := spec.name
        dup := acc[name]
        if (dup == null)
        {
          acc[name] = Spec[spec]
        }
        else
        {
          list := dup as Spec[]
          list.add(spec)
          acc[name] = list
        }
      }
    }
    return acc.toImmutable
  }
  private const AtomicRef funcMapRef := AtomicRef()

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
    if (cx == null) Console.cur.warn("Must call Namespace.validate within XetoContext")

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
    XetoPrinter(this, out, opts ?: Etc.dict0).data(val)
  }

  override Void print(Obj? val, OutStream out := Env.cur.out, Dict? opts := null)
  {
    Printer(this, out, opts ?: Etc.dict0).print(val)
  }

  override Dict[] parseToDicts(Str src, Dict? opts := null)
  {
    envRef.parseToDicts(this, src, opts ?: Etc.dict0)
  }

  override final Obj? compileData(Str src, Dict? opts := null)
  {
    envRef.compileData(this, src, opts ?: Etc.dict0)
  }

  override final Lib compileTempLib(Str src, Dict? opts := null)
  {
    envRef.compileTempLib(this, src, opts ?: Etc.dict0)
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
    out.printLine("--- $typeof [$versions.size libs, $digest] ---")
    versions.each |v| { out.printLine("  $v [" + libStatus(v.name) + "]") }
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  const MSys sys
  const Dict opts
  private const ConcurrentMap entriesMap := ConcurrentMap()
  private const AtomicRef libsRef := AtomicRef()
}

**************************************************************************
** CompanionRecs
**************************************************************************

@Js
const class CompanionRecs
{
  ** Construct with list of recs and thunks to reuse
  new make(Dict[] recs, Str:Thunk thunks)
  {
    this.recs   = recs
    this.thunks = thunks
  }

  ** Companion recs from database
  const Dict[] recs

  ** Thunks to reuse by spec name
  const Str:Thunk thunks
}

**************************************************************************
**MLibEntry
**************************************************************************

@Js
internal const class MLibEntry
{
  new makeOk(LibVersion version, Lib lib) { this.version = version; this.lib = lib }

  new makeErr(LibVersion version, Err err) { this.version = version; this.err = err }

  Str name() { version.name }

  const LibVersion version

  override Int compare(Obj that) { this.name <=> ((MLibEntry)that).name }

  LibStatus status() { lib != null ? LibStatus.ok : LibStatus.err }

  const Err? err

  const XetoLib? lib

  XetoLib get() { lib ?: throw err }

  override Str toStr() { "MLibEntry $name [$status] $err" }
}

