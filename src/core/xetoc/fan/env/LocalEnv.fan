//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   16 Jan 2023  Brian Frank  Creation
//

using concurrent
using xeto
using xetoEnv

**
** Local environment that compiles source from file system
**
internal const class LocalEnv : MEnv
{
  new make() : super(NameTable(), LocalRegistry(this), null)
  {
    this.registry = registryRef
  }

  override Bool isRemote() { false }

  override const LocalRegistry registry

/*
  override Lib compileLib(Str src, Dict? opts := null)
  {
    if (opts == null) opts = dict0

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

    lib := c.compileLib

    if (opts.has("register")) registry.addTemp(lib)

    return lib
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
*/

  override Void dump(OutStream out := Env.cur.out)
  {
    out.printLine("=== LocalXetoEnv ===")
    out.printLine("Env Path:")
    registry.envPath.eachr |x| { out.printLine("  $x.osPath") }
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

