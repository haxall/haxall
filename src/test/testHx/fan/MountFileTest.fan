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

//////////////////////////////////////////////////////////////////////////
// LibMount
//////////////////////////////////////////////////////////////////////////

  ** LibMount exposes published lib files as lib/{xetoLib}/{path}
  @HxTestProj
  Void testLibMount()
  {
    addLib("hx.test.xeto")
    setupContext

    // directories exist only in their dir form; a lib with no files
    // still exists
    verifyLibExists(`lib/`, true)
    verifyLibExists(`lib/axon/`, true)
    verifyLibExists(`lib/hx.test.xeto/`, true)
    verifyLibExists(`lib/hx.test.xeto`, false)
    verifyLibExists(`lib/hx.nope/`, false)
    verifyLibExists(`lib/hx.test.xeto/res/`, true)
    verifyLibExists(`lib/hx.test.xeto/res`, false)
    verifyLibExists(`lib/hx.test.xeto/res/subdir/`, true)

    // published files resolve and read
    verifyLibRead(`lib/hx.test.xeto/pub-root.txt`, "root!\n\n")
    verifyLibRead(`lib/hx.test.xeto/res/a.txt`, "alpha\n")
    verifyLibRead(`lib/hx.test.xeto/res/subdir/b.txt`, "beta\n")

    // root markdown chapters are intrinsically published
    verifyLibExists(`lib/hx.test.xeto/Readme.md`, true)

    // a file merely included in the lib is not reachable even by its
    // exact path, and its directory stays hidden too
    verifyLibExists(`lib/hx.test.xeto/dist/`, false)
    verifyLibExists(`lib/hx.test.xeto/data/`, false)
    verifyLibExists(`lib/hx.test.xeto/data/c.txt`, false)
    verifyErr(IOErr#) { resolve(`lib/hx.test.xeto/data/c.txt`).withIn |in| { in.readAllStr } }

    // listings surface only published entries; xeto sources and root
    // markdown chapters are intrinsically published
    names := resolve(`lib/hx.test.xeto/`).list.map |x->Str| { x.name }
    ["lib.xeto", "ChapterA.md", "Readme.md", "pub-root.txt", "res"].each |n| { verify(names.contains(n), n) }
    ["data", "dist"].each |n| { verifyFalse(names.contains(n), n) }
    verifyLibList(`lib/hx.test.xeto/res/`, ["a.txt", "subdir"])
    verifyLibList(`lib/hx.test.xeto/res/subdir/`, ["b.txt"])

    // size/modified come from the LibFile; dirs have no size
    libFile := Context.cur.ns.lib("hx.test.xeto").files.get(`/res/a.txt`)
    f := resolve(`lib/hx.test.xeto/res/a.txt`)
    verifyEq(f.size, libFile.size)
    verifyEq(f.modified, libFile.modified)
    verifyNull(resolve(`lib/hx.test.xeto/`).size)

    // lib files are read only
    verifyErr(IOErr#) { f.withOut |out| { out.writeChars("this should fail") } }
  }

  private File resolve(Uri uri) { Context.cur.sys.file.resolve(uri) }

  private Void verifyLibExists(Uri uri, Bool expect)
  {
    verifyEq(resolve(uri).exists, expect, uri.toStr)
  }

  private Void verifyLibRead(Uri uri, Str expect)
  {
    verifyEq(resolve(uri).withIn |in| { in.readAllStr }, expect, uri.toStr)
  }

  private Void verifyLibList(Uri uri, Str[] names)
  {
    verifyEq(resolve(uri).list.map |f->Str| { f.name }.sort, names, uri.toStr)
  }

}
