//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   19 May 2021  Brian Frank  Creation
//

using haystack
using folio
using hx
using defc

**
** Haxall definition compiler
**
class HxdDefCompiler : DefCompiler
{
  new make(Folio db, Log log) { this.db = db; this.log = log }

  const Folio db

  ** Utility to read the lib.trio meta Dict for given name since
  ** this runtime doesn't load it into the namespace if not enabled.
  ** Note: this dict is not exactly the same as the namespace Lib dict
  ** because no normalization is performed for baseUri, version, etc
  Dict readLibMeta(Str libName)
  {
    readStep := ReadLibMeta(this, libName)
    run([InitLibNameToPod(this), readStep])
    return readStep.libMeta
  }

  override DefCompilerStep[] frontend()
  {
    super.frontend.insertAll(0, [
      InitLibNameToPod(this),
      InitInputs(this)
    ])
  }

  internal Pod libNameToPod(Str name)
  {
    libNameToPodMap[name] ?: throw Err("No pod indexed for $name.toCode")
  }

  internal File libNameToMetaFile(Str name)
  {
    pod := libNameToPod(name)
    file := pod.file(`/lib/lib.trio`, false)
    if (file == null) file = pod.file(`/lib/${name}/lib.trio`, false)
    if (file == null) throw Err("Pod missing /lib/lib.trio: $pod.name.toCode")
    return file
  }

  internal [Str:Pod]? libNameToPodMap     // InitLibNameToPod
}

**************************************************************************
** InitLibNameToPod
**************************************************************************

internal class InitLibNameToPod : DefCompilerStep
{
  new make(HxdDefCompiler c) : super(c) {}

  override Void run()
  {
    c := (HxdDefCompiler)compiler
    acc := Str:Pod[:]

    // iterator all pods which declare ph.lib in their index
    Env.cur.indexPodNames("ph.lib").each |podName|
    {
      try
        mapPod(acc, podName)
      catch (Err e)
        err("Invalid pod ph.lib index", CLoc(podName), e)
    }

    // init compiler field
    c.libNameToPodMap = acc
  }

  private Void mapPod(Str:Pod acc, Str podName)
  {
    // load pod
    pod := Pod.find(podName)

    // parse index.props
    index := pod.file(`/index.props`).in.readPropsListVals

    // get the list of values for "ph.lib" key
    libNames := index["ph.lib"]
    libNames.each |n|
    {
      dup := acc[n]
      if (dup != null)
        err2("Duplicate ph.lib index for $n.toCode", CLoc(dup.name), CLoc(pod.name))
      else
        acc[n] = pod
    }
  }
}

**************************************************************************
** ReadLibMeta
**************************************************************************

internal class ReadLibMeta : DefCompilerStep
{
  new make(HxdDefCompiler c, Str libName) : super(c) { this.libName  = libName }

  override Void run()
  {
    // note: this is just a straight read of the "lib.trio"; it does
    // not perform any normalization such as baseUri, version, etc
    c := (HxdDefCompiler)compiler
    file := c.libNameToMetaFile(libName)
    this.libMeta = TrioReader(file.in).readDict
  }

  const Str libName
  Dict? libMeta
}

**************************************************************************
** InitInputs
**************************************************************************

internal class InitInputs : DefCompilerStep
{
  new make(HxdDefCompiler c) : super(c) {}

  override Void run()
  {
    c := (HxdDefCompiler)compiler
    acc := LibInput[,]

    // create LibInput for each hxLib record in database
    c.db.readAllList("hxLib").each |rec|
    {
      name := rec["hxLib"] as Str
      if (name == null) return

      try
        acc.add(initInput(c, name, rec))
      catch (Err e)
        err("Cannot init hxLib", CLoc(name), e)
    }

    c.inputs = acc
  }

  private LibInput initInput(HxdDefCompiler c, Str name, Dict rec)
  {
    pod := c.libNameToPod(name)
    libFile := c.libNameToMetaFile(name)
    return HxdLibInput(name, pod, libFile)
  }
}

**************************************************************************
** HxdLibInput
**************************************************************************

internal const class HxdLibInput : LibInput
{
  new make(Str name, Pod pod, File libFile)
  {
    this.name = name
    this.pod = pod
    this.libFile = libFile
    this.loc = CLoc(libFile)
  }

  const Str name
  const Pod pod
  const File libFile

  const override CLoc loc

  override Obj scanMeta(DefCompiler c)
  {
    meta := parseLibMetaFile(c, libFile)
    if (meta is Dict)
    {
      acc := Etc.dictToMap(meta)
      sym := acc["def"] as Symbol ?: throw c.err("Missing 'def' symbol", loc)
      if (sym.toStr != "lib:$name") throw c.err("Mismatched 'def' for lib.trio: $sym != lib:$name", loc)
      inferMeta(acc)
      return Etc.makeDict(acc)
    }
    return meta
  }

  private Void inferMeta(Str:Obj acc)
  {
    // infer version tag
    if (acc["version"] == null)
      acc["version"] = pod.version.toStr

    // infer baseUri tag
    if (acc["baseUri"] == null)
      acc["baseUri"] = (pod.meta["proj.uri"] ?: "http://localhost/").toUri + `/def/${name}/`
  }

  override File[] scanFiles(DefCompiler c)
  {
    libDir := "/" + libFile.path[0..-2].join("/") + "/"
    return pod.files.findAll |file|
    {
      file.ext == "trio" && file.name != "lib.trio" && file.pathStr.startsWith(libDir)
    }
  }
}


