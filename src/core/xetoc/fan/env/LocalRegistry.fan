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
    this.libPath = Env.cur.path.map |dir->File| { dir.plus(`lib/xeto/`) }
    this.map     = discover(this.libPath)
    this.list    = map.vals.sort |a, b| { a.name <=> b.name }
  }

  override LocalRegistryEntry? get(Str qname, Bool checked := true)
  {
    x := map[qname]
    if (x != null) return x
    if (checked) throw UnknownLibErr("Not installed: $qname")
    return null
  }

  private static Str:LocalRegistryEntry discover(File[] libPath)
  {
    acc := Str:LocalRegistryEntry[:]

    // find all lib/xeto entries
    libPath.each |dir|
    {
      dir.list.each |f|
      {
        if (!f.isDir && f.ext == "xetolib")
          doInitInstalled(acc, f.basename, null, f)
      }
    }

    // recursively find source entires
    initSrcEntries(acc, Env.cur.workDir + `src/xeto/`)

    return acc
  }

  private static Void initSrcEntries(Str:LocalRegistryEntry acc, File dir)
  {
    qname := dir.name
    lib := dir + `lib.xeto`
    if (lib.exists)
    {
      doInitInstalled(acc, qname, dir, Env.cur.workDir + `lib/xeto/${qname}.xetolib`)
    }
    else
    {
      dir.listDirs.each |subDir| { initSrcEntries(acc, subDir) }
    }
  }

  private static Void doInitInstalled(Str:LocalRegistryEntry acc, Str qname, File? src, File zip)
  {
    dup := acc[qname]
    if (dup != null)
    {
      if (dup.zip != zip) echo("WARN: XetoEnv '$qname' lib hidden [$dup.zip.osPath]")
    }
    acc[qname] = LocalRegistryEntry(qname, src, zip)
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

  override Void loadAsync(Str name, |Lib?| f)
  {
    f(loadSync(name, false))
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

  const MEnv env
  const File[] libPath
  override const LocalRegistryEntry[] list
  const Str:LocalRegistryEntry map
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

