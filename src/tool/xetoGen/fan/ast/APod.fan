//
// Copyright (c) 2026, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   22 Jul 2026  Brian Frank  Creation
//

using util
using xeto

**
** APod models the source directory of a pod matched to a spec lib
**
internal class APod
{
  new make(Lib[] libs, Str podName, File dir)
  {
    this.libs    = libs
    this.podName = podName
    this.dir     = dir
  }

  const Lib[] libs               // Xeto libraries bound to the pod
  const Str podName              // Fantom pod name
  const File dir                 // Dir which contains build.fan, fan, etc
  AFile[] files := [,]           // FindTypes: files with @Gen types

  Void eachType(|AType| f) { files.each |file| { file.types.each(f) } }

  Int numTypes() { files.reduce(0) |Int acc, f->Int| { acc + f.types.size } }

  Void dump(Console con := Console.cur)
  {
    con.group("$toStr [$numTypes types]")
    files.each |f| { f.dump(con) }
    con.groupEnd
  }

  override Str toStr() { podName + " => " + libs.join(", ") |lib| { lib.name } }
}

