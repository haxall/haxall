//
// Copyright (c) 2024, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   11 Apr 2024  Brian Frank  Creation
//

using concurrent
using xeto
using haystack
using folio
using hx
using def
using defc

**
** ShellNamespace wraps the xeto LibNamespace
**
const class ShellNamespace : MBuiltNamespace
{
  static ShellNamespace init(ShellRuntime rt)
  {
    c := DefCompiler
    {
      it.factory = ShellDefFactory(rt)
    }
    return c.compileNamespace
  }

  new make(BNamespace b, ShellRuntime rt) : super(b) { this.rt = rt }

  const ShellRuntime rt

  const LibRepo repo := LibRepo.cur

  const AtomicRef xetoRef := AtomicRef(repo.bootNamespace)

  Void xetoReload() { xetoRef.val = repo.createNamespace([repo.latest("sys")]) }

  Void addUsing(Str libName, OutStream out)
  {
    // add everything current loaded and new lib
    depends := Str:LibDepend[:]
    xeto.libs.each |lib|
    {
      depends[lib.name] = LibDepend(lib.name, LibDependVersions(lib.version))
    }

    // add new one or if "*" then all
    if (libName == "*")
    {
      repo.libs.each |x|
      {
        if (depends[x] != null) return
        depends[x] = LibDepend(x)
      }
    }
    else
    {
      depends[libName] = LibDepend(libName)
    }

    // solve dependency graph and rebuild namespace
    vers := repo.solveDepends(depends.vals)

    // print which new libs we are adding
    old := xeto
    vers.each |ver|
    {
      if (old.version(ver.name, false) == null)
        out.printLine("using $ver.name")
    }

    xetoRef.val = repo.createNamespace(vers)
  }
}

**************************************************************************
** ShellXetoGetter
**************************************************************************

internal const class ShellXetoGetter : XetoGetter
{
  new make(ShellRuntime rt) { this.rt = rt }

  const ShellRuntime rt

  override LibNamespace get() { rt.ns.xetoRef.val }
}

**************************************************************************
** ShellDefFactory
**************************************************************************

internal const class ShellDefFactory : DefFactory
{
  new make(ShellRuntime rt) { this.rt = rt }

  const ShellRuntime rt

  override MNamespace createNamespace(BNamespace b)
  {
    b.xetoGetter = ShellXetoGetter(rt)
    return ShellNamespace(b, rt)
  }
}

