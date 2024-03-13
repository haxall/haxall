//
// Copyright (c) 2022, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   21 Dec 2022  Brian Frank  Creation
//

using util
using concurrent
using xeto
using xetoEnv
using haystack::UnknownLibErr

**
** Registry implementation for local file system
**
internal const class LocalRegistry : MRegistry
{
  new make(MEnv env)
  {
    this.env     = env
    this.envPath = Env.cur.path
    this.map     = discover(this.envPath)
  }

  override LocalRegistryEntry[] list()
  {
    map.vals(LocalRegistryEntry#).sort
  }

  override LocalRegistryEntry? get(Str qname, Bool checked := true)
  {
    x := map[qname]
    if (x != null) return x
    if (checked) throw UnknownLibErr("Not installed: $qname")
    return null
  }

  private static ConcurrentMap discover(File[] envPath)
  {
    acc := ConcurrentMap()

    // walk each directory in Fantom environment path
    envPath.eachr |dir|
    {
      libDir := dir + `lib/xeto/`

      // find all lib/xeto/*.xetolib entries
      libDir.list.each |f|
      {
        if (!f.isDir && f.ext == "xetolib")
          doInitInstalled(acc, f.basename, null, f)
      }

      // find all src/xeto/* source entries
      initSrcEntries(acc, libDir, dir + `src/xeto/`)
    }

    return acc
  }

  private static Void initSrcEntries(ConcurrentMap acc, File libDir, File dir)
  {
    name := dir.name
    lib := dir + `lib.xeto`
    if (lib.exists)
    {
      doInitInstalled(acc, name, dir, libDir + `${name}.xetolib`)
    }
    else
    {
      dir.listDirs.each |subDir| { initSrcEntries(acc, libDir, subDir) }
    }
  }

  private static Void doInitInstalled(ConcurrentMap acc, Str name, File? src, File zip)
  {
    dup := acc[name] as LocalRegistryEntry
    if (dup != null)
    {
      if (dup.zip != zip) echo("WARN: XetoEnv '$name' lib hidden [$dup.zip.osPath]")
    }
    acc[name] = LocalRegistryEntry(name, src, zip)
  }

  override Lib? loadSync(Str name, Bool checked := true)
  {
    // check for install
    entry := get(name, checked)
    if (entry == null) return null

    // check for cached loaded lib
    if (entry.isLoaded) return entry.get

    // compile the lib into memory and atomically cache once
    return compile(entry, null)
  }

  override Void loadAsync(Str name, |Err?, Lib?| f)
  {
    try
      f(null, loadSync(name, true))
    catch (Err e)
      f(e, null)
  }

  override Void loadAsyncList(Str[] names, |Err?| f)
  {
    try
    {
      names.each |name| { loadSync(name, true) }
      f(null)
    }
    catch (Err e)
    {
      f(e)
    }
  }

  override Int build(LibRegistryEntry[] libs)
  {
    // create a XetoLibEntry copy for each entry
    build := Str:LocalRegistryEntry[:]
    build.ordered = true
    libs.each |x|
    {
      build[x.name] = LocalRegistryEntry(x.name, x.srcDir, x.zip)
    }

    // now build using build entries for dependencies
    try
    {
      build.each |entry|
      {
        if (!entry.isLoaded) compile(entry, build)
      }
      return 0
    }
    catch (Err e)
    {
      echo("BUILD FAILED")
      return 1
    }
  }

  XetoLib? resolve(XetoCompiler c, Str qname)
  {
    // in build mode use build entries for depends
    if (c.isBuild)
    {
      entry := c.build[qname]
      if (entry != null)
      {
        if (entry.isLoaded) return entry.get
        return compile(entry, c.build)
      }
    }

    // use normal load code path
    return loadSync(qname, false)
  }

  Lib compile(LocalRegistryEntry entry, [Str:LocalRegistryEntry]? build)
  {
    compilingPush(entry.name)
    try
    {
      // compile
      compiler := XetoCompiler
      {
        it.env     = this.env
        it.libName = entry.name
        it.input   = entry.src ?: entry.zip
        it.zipOut  = entry.zip
        it.build   = build
      }
      lib := compiler.compileLib

      // atomically set entry and return
      entry.set(lib)
      return entry.get
    }
    finally
    {
      compilingPop
    }
  }

  private Void compilingPush(Str qname)
  {
    stack := Actor.locals[compilingKey] as Str[]
    if (stack == null) Actor.locals[compilingKey] = stack = Str[,]
    if (stack.contains(qname)) throw Err("Cyclic lib dependency: $stack")
    stack.push(qname)
  }

  private Void compilingPop()
  {
    stack := Actor.locals[compilingKey] as Str[]
    if (stack == null) return
    stack.pop
    if (stack.isEmpty) Actor.locals.remove(compilingKey)
  }

  internal Void addTemp(XetoLib lib)
  {
    zip := Env.cur.workDir + `lib/xeto/${lib.name}.xetolib`
    entry := LocalRegistryEntry(lib.name, null, zip)
    entry.set(lib)
    map.add(lib.name, entry)
  }

  const MEnv env
  const File[] envPath
  const ConcurrentMap map
  const Str compilingKey := "dataEnv.compiling"
}

**************************************************************************
** LocalRegistryEntry
**************************************************************************

@Js
internal const class LocalRegistryEntry : MRegistryEntry
{
  new make(Str name, File? src, File zip)
  {
    this.name = name
    this.src  = src
    this.zip  = zip
  }

  override const Str name

  override const File zip

  override Version version()
  {
    isLoaded ? get.version : Version.defVal
  }

  override Str doc()
  {
    isLoaded ? (get.meta["doc"] as Str ?: "") : ""
  }

  override Str toStr() { "$name [src: $src, zip: $zip.osPath]" }

  override Bool isSrc() { src != null }

  override File? srcDir(Bool checked := true)
  {
    if (src != null) return src
    if (checked) throw Err("Lib source not available: $name")
    return null
  }

  const File? src
}

