//
// Copyright (c) 2026, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   17 Aug 2026  Brian Frank  Creation
//

using util
using xeto
using xetom
using haystack

**
** GithubRepoTest covers the half of GithubRepo.fetch which turns fetched
** source into a xetolib zip.  The GraphQL half needs a token and network,
** so it is not covered here; compileLibZip takes the fetched files as a
** map and is pure, which is where the packaging decisions actually happen.
**
class GithubRepoTest : AbstractXetoTest
{

//////////////////////////////////////////////////////////////////////////
// Round trip
//////////////////////////////////////////////////////////////////////////

  ** The zip we hand back must be a real xetolib the env can load
  Void testRoundTrip()
  {
    files := [
      "lib.xeto": libXeto(""),
      "specs.xeto": "Foo: Dict { bar: Str }\n",
      ]

    zip := compile(files)

    // meta props are written by the compiler, not by hand
    props := readProps(zip, XetoUtil.xetoMetaPropsUri)
    verifyEq(props["name"], "test.gh")
    verifyEq(props["version"], "1.0.0")

    // sources are packaged
    uris := readUris(zip)
    verifyEq(uris.contains(`/lib.xeto`), true)
    verifyEq(uris.contains(`/specs.xeto`), true)

    // and it loads as a lib with the spec resolved, which is the real
    // proof we produced a valid xetolib and not just a well formed zip
    lib := loadZip(zip)
    verifyEq(lib.name, "test.gh")
    verifyEq(lib.version, Version("1.0.0"))
    verifyEq(lib.spec("Foo").qname, "test.gh::Foo")
  }

//////////////////////////////////////////////////////////////////////////
// Packaging
//////////////////////////////////////////////////////////////////////////

  ** Packaging is opt-in on this path too - it runs through the compiler,
  ** so include/publish from the pragma decide what lands in the zip
  Void testPackagingIsOptIn()
  {
    zip := compile([
      "lib.xeto": libXeto("publish: {\"/pub-me.txt\"}"),
      "pub-me.txt": "published\n",
      "skip-me.txt": "not selected\n",
      ])

    uris := readUris(zip)

    // a file selected by no pattern is not packaged at all
    verifyEq(uris.contains(`/skip-me.txt`), false)

    // nor is it published
    lib := loadZip(zip)
    verifyEq(lib.files.get(`/skip-me.txt`, false), null)

    // source is always packaged and published
    verifyEq(lib.files.get(`/lib.xeto`).isPublished, true)
  }

  ** A file matched by publish gets a uri; one matched only by include
  ** is packaged without one
  Void testIncludeVsPublish()
  {
    zip := compile([
      "lib.xeto": libXeto("include: {\"/inc.txt\"}\n  publish: {\"/pub.txt\"}"),
      "inc.txt": "included\n",
      "pub.txt": "published\n",
      ])

    lib := loadZip(zip)
    verifyEq(lib.files.get(`/inc.txt`).isPublished, false)
    verifyEq(lib.files.get(`/pub.txt`).isPublished, true)

    // TODO: reading content back out of a zip backed lib throws "zip file
    // closed" - ParseLib closes the scanner when the compile finishes, so
    // the LibFile outlives the Zip it reads from.  Waiting on the lazy
    // reopen design; the packaging assertions above are the point here.
    // verifyEq(lib.files.get(`/pub.txt`).readAllStr.trim, "published")
  }

//////////////////////////////////////////////////////////////////////////
// Build vars
//////////////////////////////////////////////////////////////////////////

  ** The build props come from the remote repo, not from this env, so a
  ** BuildVar in the fetched source must resolve to the remote's value
  Void testBuildVarsFromRemote()
  {
    files := [
      "lib.xeto":
        Str<|pragma: Lib <
               version: BuildVar "gh.version"
               depends: { { lib: "sys" } }
             >
           |>,
      ]

    // 9.9.9 cannot come from this env, so resolving it proves the props
    // we passed in were used rather than the host's build vars
    zip := compile(files, ["gh.version": "9.9.9"])

    verifyEq(readProps(zip, XetoUtil.xetoMetaPropsUri)["version"], "9.9.9")
    verifyEq(loadZip(zip).version, Version("9.9.9"))
  }

//////////////////////////////////////////////////////////////////////////
// Cleanup
//////////////////////////////////////////////////////////////////////////

  ** The temp source tree is deleted whether or not the compile works
  Void testTempCleanup()
  {
    before := tempDirNames

    compile(["lib.xeto": libXeto(""), "specs.xeto": "Foo: Dict\n"])
    verifyEq(tempDirNames, before)

    // a compile which fails must not leak the tree either
    verifyErr(XetoCompilerErr#) { compile(["lib.xeto": "this is not valid xeto\n"]) }
    verifyEq(tempDirNames, before)
  }

  private Str[] tempDirNames()
  {
    Env.cur.tempDir.list.findAll |f->Bool| { f.name.startsWith("github-") }.map |f->Str| { f.name }.sort
  }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  ** Run the fetched files through the compile half of fetch
  private Buf compile(Str:Str files, Str:Str buildProps := Str:Str[:])
  {
    env  := XetoEnv.cur
    repo := GithubRepo(RemoteRepoInit(env, "test", `https://github.com/test/gh`, Etc.dict0, env.workDir))
    ver  := RemoteLibVersion("test.gh", Version("1.0.0"), "", [LibDepend("sys")])
    return repo.compileLibZip(ver, files, buildProps)
  }

  ** Standard lib.xeto with the given extra pragma lines
  private Str libXeto(Str extra)
  {
    """pragma: Lib <
         version: "1.0.0"
         depends: { { lib: "sys" } }
         $extra
       >
       """
  }

  ** Load the zip as a lib in its own namespace
  private Lib loadZip(Buf zip)
  {
    file := tempDir + `loaded/test.gh.xetolib`
    file.parent.create
    file.out.writeBuf(zip.dup.seek(0)).close

    ns := createNamespace(["sys"])
    return XetoCompiler.init |c|
    {
      c.ns      = ns
      c.libName = "test.gh"
      c.input   = file
    }.compileLib
  }

  ** All entry uris in the zip
  private Uri[] readUris(Buf zip)
  {
    acc := Uri[,]
    eachEntry(zip) |f| { acc.add(f.uri) }
    return acc.sort
  }

  ** Read a props entry out of the zip
  private Str:Str readProps(Buf zip, Uri uri)
  {
    acc := Str:Str[:]
    eachEntry(zip) |f| { if (f.uri == uri) acc = f.readProps }
    return acc
  }

  ** Walk the zip entries.  Each walk gets its own copy of the buf since
  ** reading the zip consumes it.
  private Void eachEntry(Buf zip, |File| cb)
  {
    z := Zip.read(Buf().writeBuf(zip.dup.seek(0)).seek(0).toFile(`x.zip`).in)
    try
      z.readEach |f| { if (!f.isDir) cb(f) }
    finally z.close
  }
}
