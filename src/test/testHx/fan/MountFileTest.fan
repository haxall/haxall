//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   21 Aug 2026  Matthew Giannini  Creation
//

using concurrent
using xeto
using haystack
using hx

**
** MountFileTest
**
class MountFileTest : HxTest
{

  ** Files from a list() report exists without needing a resolve
  @HxTestProj
  Void testListExists()
  {
    setupContext
    dir := Context.cur.sys.file.resolve(`io/listed/`)
    (dir + `a.txt`).out.print("a").close
    (dir + `b.txt`).out.print("bb").close

    files := dir.list.sort |a, b| { a.name <=> b.name }
    verifyEq(files.size, 2)
    files.each |f|
    {
      verifyEq(f.exists, true)
      verifyEq(f.typeof.name, "HxListFile")
    }
    verifyEq(files[0].name, "a.txt")
    verifyEq(files[0].size, 1)
    verifyEq(files[1].size, 2)
  }

}
