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
** MountFileTest verifies a file resolved under a context can still be
** used from a thread which does not have one.  Files are commonly
** resolved on a web/Axon thread but not read until later on a background
** actor thread; see MountFile.withCx
**
class MountFileTest : HxTest
{

  @HxTestProj
  Void testOffContext()
  {
    setupContext
    content := "hello mount file!"

    file := Context.cur.sys.file.resolve(`io/test.txt`)
    file.out.print(content).close

    verifyOffContext(file, content)

    // a file resolved from another file must carry the user forward too
    verifyOffContext(Context.cur.sys.file.resolve(`io/`).plus(`test.txt`), content)
  }

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

  ** Read the file with no context bound to this thread
  private Void verifyOffContext(File f, Str content)
  {
    cx := Actor.locals.remove(Context.actorLocalsKey)
    try
    {
      verifyNull(Context.cur(false))
      verifyEq(f.exists, true)
      verifyEq(f.name, "test.txt")
      verifyEq(f.size, content.size)
      verifyEq(f.readAllStr, content)
    }
    finally Actor.locals[Context.actorLocalsKey] = cx
  }

}
