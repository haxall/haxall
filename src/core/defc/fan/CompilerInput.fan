//
// Copyright (c) 2019, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   29 Jan 2019  Brian Frank  Creation
//

using haystack

**
** CompilerInput defines one lib or manual to scan
**
abstract const class CompilerInput
{
  ** Make list of defaults
  @NoDoc static CompilerInput[] makeDefaults()
  {
    [makePodName("ph"),
     makePodName("phScience", false),
     makePodName("phIoT", false),
     makePodName("phIct", false),
     makePodName("docHaystack", false),
    ].findNotNull
  }

  ** Convenience for 'makePod(Pod.find(podName))'
  static new makePodName(Str podName, Bool checked := true)
  {
    pod := Pod.find(podName, false)
    if (pod == null) return null
    return makePod(pod)
  }

  ** Construct input for a pod with lib/*.trio files
  static new makePod(Pod pod)
  {
    toc := pod.file(`/doc/index.fog`, false)
    return toc == null ? PodLibInput(pod) : ManualInput(pod)
  }

  ** Constructor for a directory containing a lib.trio file
  static new makeDir(File dir)
  {
    DirLibInput(dir)
  }

  ** Scan a directory to find all directories containing lib.trio
  static CompilerInput[] scanDir(File dir)
  {
    acc := CompilerInput[,]
    doScanDir(acc, dir)
    return acc
  }

  private static Void doScanDir(CompilerInput[] acc, File dir)
  {
    if (dir.plus(`lib.trio`).exists) acc.add(makeDir(dir))
    dir.listDirs.each |subDir| { doScanDir(acc, subDir) }
  }

  ** Type of input
  abstract CompilerInputType inputType()

  ** Parse lib.trio and return Dict or CompilerErr
  static Obj parseLibMetaFile(DefCompiler c, File file)
  {
    loc := CLoc(file)
    if (!file.exists) return c.err("Lib meta not found", loc)

    // parse dicts defined in lib.trio
    dicts := Dict[,]
    try
    {
      reader := TrioReader(file.in)
      reader.factory = c.intern
      dicts = reader.readAllDicts
    }
    catch (Err e)
    {
      return c.err("Cannot parse file", loc, e)
    }

    // verify only one dict in lib.trio
    if (dicts.size != 1) return c.err("Must define exactly one lib dict", loc)
    return dicts.first
  }

  ** Utility to parse each Dict+CLoc within a trio file
  static Void parseEachDict(DefCompiler? c, File file, |Dict,CLoc| f)
  {
    loc := CLoc(file)
    reader := TrioReader(file.in)
    if (c != null) reader.factory = c.intern
    reader.eachDict |dict|
    {
      f(dict, CLoc(loc.file, reader.recLineNum))
    }
  }
}

enum class CompilerInputType { lib, manual }

**************************************************************************
** LibInput
**************************************************************************

**
** LibInput defines one library to scan and compile
**
abstract const class LibInput : CompilerInput
{
  ** Lib type
  override CompilerInputType inputType() { CompilerInputType.lib }

  ** Return location to use for library itself
  abstract CLoc loc()

  ** Scan the lib def meta and return Dict or CompilerErr.
  ** See parseLibMetaFile utility.
  abstract Obj scanMeta(DefCompiler c)

  ** Return trio files to scan
  virtual File[] scanFiles(DefCompiler c) { File#.emptyList }

  ** Reflection inputs
  virtual ReflectInput[] scanReflects(DefCompiler c) { ReflectInput#.emptyList }

  ** Additional def inputs which are not in files or reflection
  virtual Dict[] scanExtra(DefCompiler c) { Dict#.emptyList }

  ** Adapt a dict without a 'def' tag to its proper def declaration
  virtual Dict? adapt(DefCompiler c, Dict dict, CLoc loc) { null }
}

**************************************************************************
** ReflectInput
**************************************************************************

**
** Reflect input is used to generate defs from Fantom
** reflection of types, methods, and fields.  Callbacks will
** pass null for slot if working at the type level.
**
abstract const class ReflectInput
{
  ** Type to reflect
  abstract Type type()

  ** Type facet to reflect or null to skip reflection at type level
  virtual Type? typeFacet() { null }

  ** Field facet type to reflect or null to skip fields
  virtual Type? fieldFacet() { null }

  ** Method facet type to reflect or null to skip methods
  virtual Type? methodFacet() { null }

  ** Map to type/slot def symbol
  abstract Symbol toSymbol(Slot? slot)

  ** Callback to add additional meta
  virtual Void addMeta(Symbol symbol, Str:Obj acc) {}

  ** Callback after a type/slot has been mapped to def
  virtual Void onDef(Slot? slot, CDef def) {}
}

**************************************************************************
** DirLibInput
**************************************************************************

internal const class DirLibInput : LibInput
{
  new make(File dir)
  {
    if (!dir.isDir) throw ArgErr("Not dir: $dir")
    this.dir = dir
    this.loc = CLoc(dir)
  }

  const File dir

  override Str toStr() { "DirLibInput [$dir.osPath]" }

  override const CLoc loc

  override Obj scanMeta(DefCompiler c)
  {
    meta := parseLibMetaFile(c, dir + `lib.trio`)
    if (meta is Dict && ((Dict)meta).missing("version"))
      meta = Etc.dictSet(meta, "version", tryVersionFromEtc)
    return meta
  }

  private Str tryVersionFromEtc()
  {
    // lookup directories for etc/build.config
    for (dir := this.dir.parent; dir != null; dir = dir.parent)
    {
      config := dir + `etc/build/config.props`
      if (config.exists) return config.readProps["buildVersion"] ?: "0.0"
    }
    return "0.0"  // just fallback to dummy
  }

  override File[] scanFiles(DefCompiler c)
  {
    return dir.listFiles.findAll |file|
    {
      file.ext == "trio" && file.name != "lib.trio"
    }
  }

}

**************************************************************************
** PodLibInput
**************************************************************************

internal const class PodLibInput : LibInput
{
  new make(Pod p)
  {
    this.pod = p
    this.loc = CLoc("$pod::/lib/lib.trio")
  }

  const Pod pod

  override Str toStr() { "PodLibInput [$pod]" }

  override const CLoc loc

  override Obj scanMeta(DefCompiler c)
  {
    // check for lib.trio meta file
    libFile := pod.file(`/lib/lib.trio`, false)
    if (libFile == null) return c.err("No lib.trio found", CLoc(pod.name))

    meta := parseLibMetaFile(c, libFile) as Dict
    if (meta != null)
    {
      if (meta.missing("version")) meta = Etc.dictSet(meta, "version", pod.version.toStr)
      if (meta.missing("baseUri")) meta = Etc.dictSet(meta, "baseUri", `/def/${meta->def}`)
    }
    return meta
  }

  override File[] scanFiles(DefCompiler c)
  {
    libDir := "/lib/"
    return pod.files.findAll |file|
    {
      file.ext == "trio" && file.name != "lib.trio" && file.pathStr.startsWith(libDir)
    }
  }

}

**************************************************************************
** ManualInput
**************************************************************************

const class ManualInput : CompilerInput
{
  new make(Pod p) { pod = p }

  const Pod pod

  override CompilerInputType inputType() { CompilerInputType.manual }

  override Str toStr() { "ManualInput [$pod]" }

}


