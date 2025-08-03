//
// Copyright (c) 2025, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   12 Jul 2025  Brian Frank  Creation
//

using xeto
using xetom
using haystack

**
** AST for extension
**
class AExt
{
  static Void scan(Ast ast, APod pod)
  {
    libTrio := pod.dir + `lib/lib.trio`
    if (libTrio.exists) return scanLib(ast, pod, libTrio)
  }

  static Void scanLib(Ast ast, APod pod, File libFile)
  {
    dicts := TrioReader(libFile.in).readAllDicts
    meta := dicts.first
    def := meta["def"]?.toStr ?: throw Err("Missing def: $libFile")
    if (!def.startsWith("lib:")) throw Err("Invalid lib def: $libFile")

    if (def.lower.contains("test")) return

    oldName := def["lib:".size..-1]
    specName := oldName.capitalize + "Ext"
    ext := make(ast, pod, oldName, specName, AExtType.ext, meta)
    pod.exts.add(ext)

    AFunc.scanExt(ast, ext)
  }

  static Str oldNameToLibName(Ast ast, Str oldName)
  {
    prefix  := ast.config.libPrefix
    if (oldName == "axon") return "axon"
    if (oldName.endsWith("Auth")) return prefix + ".auth." + oldName[0..-5].lower
    if (prefix == oldName) return oldName
    start := prefix + "."
    dotted := oldName.lower
    if (dotted.startsWith(start)) dotted = dotted[start.size..-1]
    return start + dotted
  }

  new make(Ast ast, APod pod, Str oldName, Str specName, AExtType type, Dict meta)
  {
    this.ast        = ast
    this.pod        = pod
    this.oldName    = oldName
    this.libName    = oldNameToLibName(ast, oldName)
    this.type       = type
    this.meta       = meta
    this.xetoSrcDir = ast.xetoSrcDir + `${libName}/`
    this.specName   = specName
  }

  Ast ast { private }
  APod pod { private set }
  const Str oldName
  const Str libName
  const AExtType type
  const Dict meta
  const File xetoSrcDir
  const Str specName
  Str specBase() { type == AExtType.mod ? "SysExt" : "Ext" }

  Str? fantomFuncType
  AFunc[] funcs := [,]

  Bool dependOnIon()
  {
    funcs.any |f|
    {
      m := f.meta
      return m.has("text") || m.has("selectMode") || m.has("confirm") || m.has("noFlash") || m.has("noUpdate")
    }
  }

  override Str toStr() { "$oldName [$type]" }
}

** Haxall HxLib, SS Ext or SS SysMod
enum class AExtType { ext, mod }

