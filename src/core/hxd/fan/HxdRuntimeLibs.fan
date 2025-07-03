//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   20 May 2021  Brian Frank  Creation
//

using concurrent
using xeto
using haystack
using folio
using hx

**
** HxdRuntimeLibs manages the runtime lib registry
**
const class HxdRuntimeLibs : Actor, HxRuntimeLibs
{
  new make(HxdRuntime rt, Str[] required) : super(rt.libsActorPool)
  {
    this.rt = rt
    this.required = required
    this.actorPool = this.pool
  }

  Void init(Bool removeUnknown)
  {
    // init libs from database ext records
    map := Str:HxLib[:]
    installed := rt.installed
    rt.db.readAllList(Filter.has("ext")).each |rec|
    {
      try
      {
        // instantiate the HxLib
        name := (Str)rec->ext
        install := installed.lib(name)
        lib := HxdLibSpi.instantiate(rt, install, rec)
        map.add(name, lib)
      }
      catch (UnknownLibErr e)
      {
        if (removeUnknown)
        {
          rt.log.err("Removing unknown lib: $rec.id.toCode [${rec->ext}]")
          try
            rt.db.commit(Diff(rec, null, Diff.remove.or(Diff.bypassRestricted)))
          catch (Err e2)
            rt.log.err("Remove failed", e)
        }
        else
        {
          rt.log.err("Lib not installed: $rec.id.toCode [${rec->ext}]")
        }
      }
      catch (Err e)
      {
        rt.log.err("Cannot init lib: $rec.id.toCode [${rec->ext}]", e)
      }
    }

    // check dependencies
    map.dup.each |lib|
    {
      try
      {
        // check if all the dependenices are met
        install := ((HxdLibSpi)lib.spi).install
        unmet := install.depends.findAll |d| { !map.containsKey(d) }
        if (unmet.isEmpty) return

        // if not all met then put the lib into a fault condition
        err := DependErr("$lib.name.toCode unmet depends: $unmet")
        rt.log.info("Disabling lib with unmet depends: $lib.name", err)
        map.remove(lib.name)
      }
      catch (Err e) rt.log.err("Depend check failed: $lib.name", e)
    }

    // build remaining lookup tables
    list := HxLib[,]
    map.each |lib| { list.add(lib) }
    list.sort |a, b| { a.name <=> b.name }

    // save lookup tables
    this.listRef.val = list.toImmutable
    this.mapRef.val = map.toImmutable

    // initialize services registry now that we know initial libs
    rt.servicesRebuild
  }

  const HxdRuntime rt

  override const ActorPool actorPool

  const Str[] required

  override HxLib[] list() { listRef.val }
  private const AtomicRef listRef := AtomicRef(HxLib[,].toImmutable)

  override Bool has(Str name) { map.containsKey(name) }

  override HxLib? get(Str name, Bool checked := true)
  {
    lib := map[name]
    if (lib != null) return lib
    if (checked) throw UnknownLibErr(name)
    return null
  }
  internal Str:HxLib map() { mapRef.val }
  private const AtomicRef mapRef := AtomicRef(Str:HxLib[:].toImmutable)

  HxLib? getType(Type type, Bool checked := true)
  {
    lib := list.find |lib| { lib.typeof.fits(type) }
    if (lib != null) return lib
    if (checked) throw UnknownLibErr(type.qname)
    return null
  }

  override HxLib add(Str name, Dict tags := Etc.emptyDict)
  {
    // lookup installed lib callers thread
    install := rt.installed.lib(name)

    // add dis name if not defined
    if (tags.missing("dis")) tags = Etc.dictSet(tags, "dis", "lib:$name")

    // process on our background actor
    return send(HxMsg("add", install, tags)).get(null)
  }

  override Void remove(Obj arg)
  {
    // check argument on caller's thread
    HxLib? lib
    if (arg is HxLib)
    {
      lib = arg
      if (lib.rt !== rt) throw ArgErr("HxLib has different rt")
    }
    else if (arg is DefLib)
    {
      lib = get(((Lib)arg).name)
    }
    else if (arg is Str)
    {
      // handle lib name in db which wasn't loaded
      // properly to allow cleanup of old libs
      lib = get(arg, false)
      if (lib == null)
      {
        rec := rt.db.read(Filter.eq("ext", arg.toStr), false)
        if (rec == null) throw UnknownLibErr(arg.toStr)
        rt.db.commit(Diff(rec, null, Diff.remove.or(Diff.bypassRestricted)))
        return
      }
    }
    else throw ArgErr("Invalid arg type for libRemove: $arg ($arg.typeof)")

    // process on our background actor
    send(HxMsg("remove", lib.name)).get(null)
  }

  override Grid status()
  {
    gb := GridBuilder()
    gb.addCol("name").addCol("libStatus").addCol("statusMsg")
    list.each |lib|
    {
      spi := (HxdLibSpi)lib.spi
      gb.addRow([lib.name, spi.status, spi.statusMsg])
    }
    return gb.toGrid
  }

  override Obj? receive(Obj? arg)
  {
    msg := (HxMsg)arg
    switch (msg.id)
    {
      case "add":    return onAdd(msg.a, msg.b)
      case "remove": return onRemove(msg.a)
      default:       throw ArgErr("Unsupported msg: $msg")
    }
  }

  private HxLib onAdd(HxdInstalledLib install, Dict extraTags)
  {
    // check for dup
    name := install.name
    dup := get(name, false)
    if (dup != null) throw Err("HxLib $name.toCode already exists")

    // check depends
    install.depends.each |d|
    {
      if (get(d, false) == null) throw DependErr("HxLib $name.toCode missing dependency on $d.toCode")
    }

    // add to db
    rt.log.info("Add lib: $name")
    tags := Etc.dictToMap(extraTags)
    tags["ext"] = name
    rec := rt.db.commit(Diff(null, tags, Diff.add.or(Diff.bypassRestricted))).newRec

    // instantiate the HxLib
    lib := HxdLibSpi.instantiate(rt, install, rec)

    // register in lookup data structures
    listRef.val = list.dup.add(lib).sort(|x, y| { x.name <=> y.name }).toImmutable
    mapRef.val  = map.dup.add(name, lib).toImmutable

    // common modification processing
    onModified

    // register observables
    rt.obs.addLib(lib)

    // call onStart, onReady asynchronously
    spi := (HxdLibSpi)lib.spi
    spi.start
    spi.ready
    if (rt.isSteadyState) spi.steadyState

    // done!
    return lib
  }

  private Obj? onRemove(Str name)
  {
    lib := get(name)
    def := lib.def

    // verify removing it wouldn't break any dependencies
    list.each |x|
    {
      if (x.def.depends.any |symbol| { symbol.name == name })
        throw DependErr("HxLib $x.name.toCode has dependency on $name.toCode")
    }

    // unregister observables
    rt.obs.removeLib(lib)

    // call onUnready, onStop asynchronously
    spi := (HxdLibSpi)lib.spi
    spi.unready
    spi.stop

    // remove rec from database
    rt.log.info("Remove lib: $name")
    rt.db.commit(Diff(lib.rec, null, Diff.remove.or(Diff.bypassRestricted)))

    // remove from lookup data structures
    listRef.val = list.dup { it.removeSame(lib) }.toImmutable
    mapRef.val  = map.dup { it.remove(name) }.toImmutable

    // common modification processing
    onModified

    // done!
    return "removed: $name"
  }

  private Void onModified()
  {
    rt.nsBaseRecompile
    rt.servicesRebuild
  }

}

