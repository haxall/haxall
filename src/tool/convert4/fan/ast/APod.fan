//
// Copyright (c) 2025, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   12 Jul 2025  Brian Frank  Creation
//

using util
using haystack

**
** AST pod
**
class APod
{
  static APod? scan(Ast ast, File buildFile)
  {
    dir := buildFile.parent
    name := dir.name

    pod := make(name, dir, buildFile)

    AExt.scan(ast, pod)

    if (pod.exts.isEmpty) return null
    return pod
  }

  new make(Str name, File dir, File buildFile)
  {
    this.name      = name
    this.dir       = dir
    this.buildFile = buildFile
  }

  const Str name
  const File dir
  const File buildFile
  AExt[] exts := [,]

  override Str toStr() { name }

  Void dump(Console con := Console.cur)
  {
    con.group(name)
    con.info("dir:  $dir.osPath")
    con.info("ext:  " + exts.join(", "))
    con.groupEnd
  }
}

