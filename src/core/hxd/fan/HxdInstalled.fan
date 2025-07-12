//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   25 May 2021  Brian Frank  Creation
//

using xeto
using haystack
using hx

**
** Model of what libs are installed in the host system
**
const class HxdInstalled
{
  ** Build the install image
  static HxdInstalled build()
  {
    make(HxdInstalledBuilder().build)
  }

  ** Private constructor used by build
  private new make(HxdInstalledBuilder b)
  {
    this.map = b.map
  }

  ** Lookup an installed lib entry by name
  HxdInstalledLib? lib(Str name, Bool checked := true)
  {
    lib := map[name]
    if (lib != null) return lib
    if (checked) throw UnknownLibErr("Lib not installed: $name")
    return null
  }

  ** Test main
  static Void main()
  {
    list := build.map.vals.mapNotNull |x| { x.type }.sort
    echo(list.join("\n"))
  }

  private const Str:HxdInstalledLib map
}

**************************************************************************
** HxdInstalledLib
**************************************************************************

const class HxdInstalledLib
{
  internal new make(Str name, Pod pod, Dict meta)
  {
    this.name  = name
    this.pod   = pod
    this.meta  = meta
  }

  const Str name
  const Pod pod
  const Dict meta

  Type? type()
  {
    typeName := meta["typeName"] as Str
    if (typeName == null) return null
    return Type.find(typeName)
  }

  Str[] depends()
  {
    Symbol.toList(meta["depends"]).map |x->Str|
    {
      if (!x.toStr.startsWith("lib:")) throw Err("Invalid depend: $x")
      return x.name
    }
  }

  File metaFile()
  {
    pod.file(`/lib/lib.trio`)
  }

  override Str toStr() { name }
}

**************************************************************************
** HxdInstalledBuilder
**************************************************************************

internal class HxdInstalledBuilder
{
  This build()
  {
    t1 := Duration.now
    mapPods
    t2 := Duration.now
    //echo("HxdInstalled load [" + (t2-t1).toLocale + "]")
    return this
  }

  private Void mapPods()
  {
    // iterator all pods which declare ph.lib in their index
    Env.cur.indexPodNames("ph.lib").each |podName|
    {
      try
        mapPod(podName)
      catch (Err e)
        log.err("Invalid pod ph.lib index [$podName]", e)
    }
  }

  private Void mapPod(Str podName)
  {
    // load pod
    pod := Pod.find(podName)

    // parse index.props
    index := pod.file(`/index.props`).in.readPropsListVals

    // get the list of values for "ph.lib" key
    libNames := index["ph.lib"]
    libNames.each |libName|
    {
      dup := map[libName]
      if (dup != null)
      {
        log.err("Duplicate ph.lib index for $libName.toCode [$dup.pod.name, $pod.name]")
        return
      }

      try
        map[libName] = mapLib(libName, pod)
      catch (Err e)
        log.err("Cannot load installed lib $libName.toCode from pod $podName.toCode", e)
    }
  }

  private HxdInstalledLib mapLib(Str name, Pod pod)
  {
    // parse lib.trio file
    file := toMetaFile(name, pod)
    dicts := TrioReader(file.in).readAllDicts
    if (dicts.size != 1)
    {
      defSymStr := "lib:${name}"
      dicts = dicts.findAll |m| { m["def"]?.toStr == defSymStr }
      if (dicts.size != 1) throw Err("Lib meta '$defSymStr' not found [$file]")
    }

    // sanity check the meta
    meta := dicts[0]
    symbol := meta["def"] as Symbol ?: throw Err("Missing 'def' symbol [$file]")
    if (symbol.toStr != "lib:$name") throw Err("Mismatched 'def' symbol: '$symbol' != 'lib:$name' [$file]")

    // normalize lib meta with pod meta
    meta = normMeta(name, pod, meta)

    // create install entry
    return HxdInstalledLib(name, pod, meta)
  }

  private Dict normMeta(Str name, Pod pod, Dict meta)
  {
    acc := Etc.dictToMap(meta)

    // infer version tag
    if (acc["version"] == null)
      acc["version"] = pod.version.toStr

    // infer baseUri tag
    if (acc["baseUri"] == null)
    {
      domain := pod.meta["proj.uri"]
      if (domain == null) domain = pod.meta["org.uri"]
      if (domain == null) domain = "http://localhost/"
      acc["baseUri"] = domain.toUri + `/def/${name}/`
    }

    // normalize depends
    if (acc["depends"] is List)
      acc["depends"] = normDepends(acc["depends"])

    return Etc.makeDict(acc)
  }

  private File toMetaFile(Str name, Pod pod)
  {
    pod.file(`/lib/lib.trio`, false) ?: throw Err("Pod missing /lib/lib.trio")
  }

  private Obj[] normDepends(Obj[] depends)
  {
    // exclude skyarc as optional dependency
    depends.findAll |d| { d.toStr != "lib:skyarc" }
  }

  Log log := Log.get("hxd")
  Str:HxdInstalledLib map := [:]
}

