//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   16 Jan 2023  Brian Frank  Creation
//

using concurrent
using util
using xeto
using xetoEnv
using haystack::Etc
using haystack::Marker
using haystack::NA
using haystack::Remove
using haystack::Grid
using haystack::Symbol
using haystack::UnknownSpecErr

**
** Local environment that compiles source from file system
**
internal const class LocalEnv : MEnv
{
  new make() : super(LocalRegistry(this))
  {
    this.registry = registryRef
  }

  override const LocalRegistry registry

  override Lib compileLib(Str src, Dict? opts := null)
  {
    libName := "temp" + compileCount.getAndIncrement

    if (!src.startsWith("pragma:"))
      src = """pragma: Lib <
                  version: "0.0.0"
                  depends: { { lib: "sys" } }
                >
                """ + src

    c := XetoCompiler
    {
      it.env     = this
      it.libName = libName
      it.input   = src.toBuf.toFile(`temp.xeto`)
      it.applyOpts(opts)
    }
    return c.compileLib
  }

  override Obj? compileData(Str src, Dict? opts := null)
  {
    c := XetoCompiler
    {
      it.env = this
      it.input = src.toBuf.toFile(`parse.xeto`)
      it.applyOpts(opts)
    }
    return c.compileData
  }

  override Dict parsePragma(File file, Dict? opts := null)
  {
    c := XetoCompiler
    {
      it.env = this
      it.input = file
      it.applyOpts(opts)
    }
    return c.parsePragma
  }

  override Void dump(OutStream out := Env.cur.out)
  {
    registry := (LocalRegistry)this.registry
    out.printLine("=== XetoEnv ===")
    out.printLine("Lib Path:")
    registry.libPath.eachr |x| { out.printLine("  $x.osPath") }
    max := registry.list.reduce(10) |acc, x| { x.name.size.max(acc) }
    out.printLine("Installed Libs:")
    registry.list.each |entry|
    {
      out.print("  ").print(entry.name.padr(max))
      if (entry.isSrc)
        out.print(" [SRC ").print(entry.srcDir.osPath)
      else
        out.print(" [").print(entry.zip.osPath)
      out.printLine("]")
    }
  }

  private const AtomicInt compileCount := AtomicInt()
}


