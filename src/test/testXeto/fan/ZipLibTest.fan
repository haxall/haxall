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
using xetoc
using haystack

**
** ZipLibTest verifies a lib loaded from its packaged xetolib zip behaves
** the same as one loaded from source.  The dev environment always has both
** and source wins, so without this the zip half of the compiler - the half
** which actually ships - is never exercised.
**
class ZipLibTest : AbstractXetoTest
{

//////////////////////////////////////////////////////////////////////////
// Packaging
//////////////////////////////////////////////////////////////////////////

  ** The zip scanner and the dir scanner must classify identically: the
  ** patterns come from the pragma either way, so the same lib loaded two
  ** ways must package and publish the same files
  Void testPackagingMatchesSource()
  {
    ns := createZipNamespace(["hx.test.xeto"])
    if (ns == null) return

    zipLib := ns.lib("hx.test.xeto")
    srcLib := createNamespace(["hx.test.xeto"]).lib("hx.test.xeto")

    // the source lib is the reference; both must agree exactly
    verifyEq(uris(zipLib.files.list), uris(srcLib.files.list))
    verifyEq(uris(zipLib.files.published), uris(srcLib.files.published))

    // and the three tiers are what we expect, not merely equal to each other
    verifyEq(zipLib.files.get(`/lib.xeto`).isPublished, true)      // source
    verifyEq(zipLib.files.get(`/ChapterA.md`).isPublished, true)   // chapter
    verifyEq(zipLib.files.get(`/pub-root.txt`).isPublished, true)  // publish
    verifyEq(zipLib.files.get(`/res/a.txt`).isPublished, true)     // publish dir
    verifyEq(zipLib.files.get(`/data/c.txt`).isPublished, false)   // include only
  }

  ** A file selected by no pattern never made it into the zip at all
  Void testUnselectedNotPackaged()
  {
    ns := createZipNamespace(["hx.test.xeto"])
    if (ns == null) return

    files := ns.lib("hx.test.xeto").files
    verifyEq(files.get(`/test-exclude/excluded.txt`, false), null)
    verifyErr(UnresolvedErr#) { files.get(`/test-exclude/excluded.txt`) }
  }

  ** The "xeto-" system files are in the zip but are not lib files
  Void testSystemFilesHidden()
  {
    ns := createZipNamespace(["hx.test.xeto"])
    if (ns == null) return

    files := ns.lib("hx.test.xeto").files
    verifyEq(files.get(XetoUtil.xetoMetaPropsUri, false), null)
    verifyEq(files.get(XetoUtil.xetoBuildPropsUri, false), null)
    verifyEq(files.list.any |f| { XetoUtil.isXetoSystemFile(f.uri.name) }, false)
  }

//////////////////////////////////////////////////////////////////////////
// Build Vars
//////////////////////////////////////////////////////////////////////////

  ** BuildVar tokens must be resolved when the lib is read back from its
  ** zip.  The xeto source ships byte true, so "lib.xeto" still literally
  ** reads 'version: BuildVar "hx.version"' - it only resolves because
  ** xeto-build.props was packaged beside it and the scanner feeds it to
  ** the parser.  This is the whole reason that props file exists.
  Void testBuildVarsResolved()
  {
    ns := createZipNamespace(["hx.test.xeto"])
    if (ns == null) return

    zipLib := ns.lib("hx.test.xeto")

    // the packaged source is still verbatim, so every value below is only
    // correct because xeto-build.props resolved it when the zip was loaded
    src := zipLib.files.get(`/lib.xeto`).readAllStr
    verify(src.contains("version: BuildVar \"hx.version\""))
    verify(src.contains("license: BuildVar \"hx.license\""))

    // assert against the props packaged in the zip, not against the source
    // lib which would share any common bug
    props := buildProps(zipLib)
    verifyEq(zipLib.version.toStr, props.getChecked("hx.version"))
    verifyEq(zipLib.meta["license"], props.getChecked("hx.license"))
    verifyEq(((Dict)zipLib.meta["org"])["dis"], props.getChecked("hx.org.dis"))

    // depends carry a BuildVar in their version constraint too
    verifyEq(zipLib.depends.find { it.name == "sys" }.versions.toStr,
             props.getChecked("ph.depend"))

    verifyNotEq(zipLib.version, Version.defVal)
  }

  ** The check above cannot tell whether the vars came from the zip or from
  ** this environment, because a lib built here has the same values in both.
  ** So build a lib whose vars exist nowhere but its own zip and verify it
  ** still resolves - if resolution leaked from the env this would fail.
  Void testBuildVarsComeFromZip()
  {
    vars := BuildVars(["zip.only.version": "9.8.7", "zip.only.license": "ZIP-1.0"])

    dir := tempDir + `bvsrc/test.bv/`
    dir.delete
    (dir + `lib.xeto`).out.print(
      Str<|pragma: Lib <
             version: BuildVar "zip.only.version"
             license: BuildVar "zip.only.license"
             depends: { { lib: "sys" } }
           >
         |>).close

    // compile to a zip with vars which are not in this env at all
    zipFile := tempDir + `bv/test.bv.xetolib`
    zipFile.parent.create
    XetoCompiler.init
    {
      it.ns            = createNamespace(["sys"])
      it.libName       = "test.bv"
      it.input         = dir
      it.build         = zipFile
      it.srcBuildVars  = vars
    }.compileLib

    // "zip.only.*" is defined in no xeto-build.props on this env's path,
    // so the only place it can come from is the zip we just wrote

    // load the zip and verify the packaged props resolved it
    lib := XetoCompiler.init |c|
    {
      c.ns      = createNamespace(["sys"])
      c.libName = "test.bv"
      c.input   = zipFile
    }.compileLib

    verifyEq(lib.version, Version("9.8.7"))
    verifyEq(lib.meta["license"], "ZIP-1.0")
    verify(lib.files.get(`/lib.xeto`).readAllStr.contains("BuildVar"))
  }

//////////////////////////////////////////////////////////////////////////
// Meta Props
//////////////////////////////////////////////////////////////////////////

  ** A xetolib carries precompiled meta so its name, version, and depends
  ** can be read without compiling it.  That is a second source of truth for
  ** what lib.xeto declares, so a zip whose props disagree would resolve as
  ** one lib and compile as another.  Verify we reject that instead.
  Void testMetaPropsMustAgree()
  {
    verifyMetaSkew("version", "7.7.7")
    verifyMetaSkew("depends", "sys 5.0.0;ph 5.0.0")
    verifyMetaSkew("name", "some.other.lib")
  }

  ** A zip missing the props entirely is also rejected
  Void testMetaPropsRequired()
  {
    verifyMetaSkew("version", null)
  }

  ** Lib name comes from meta.props so an uploaded zip spooled to a
  ** temp file with a meaningless name still loads with its real name
  Void testLoadZipFileName()
  {
    upload := tempDir + `upload-123.xetolib`
    buildLibZip.copyTo(upload)
    v := FileLibVersion.loadZipFile(upload)
    verifyEq(v.name, "test.skew")
    verifyEq(v.version, Version("1.0.0"))
  }

  ** Build a lib zip, rewrite one meta prop, and verify the compile fails
  private Void verifyMetaSkew(Str tag, Str? val)
  {
    zip := buildLibZip
    tamper(zip, tag, val)

    Str? msg := null
    try
      compileZip(zip)
    catch (Err e)
      msg = e.msg
    if (msg == null) return fail("expected err for skewed '$tag'")

    verify(msg.contains(XetoUtil.xetoMetaPropsUri.name), msg)
    verify(msg.contains("'$tag'"), msg)
  }

  ** Compile a minimal lib to its own zip
  private File buildLibZip()
  {
    dir := tempDir + `metaskew/test.skew/`
    dir.delete
    (dir + `lib.xeto`).out.print(
      Str<|pragma: Lib < version: "1.0.0", depends: { { lib: "sys" } } >
         |>).close

    zip := tempDir + `metaskew/test.skew.xetolib`
    XetoCompiler.init |c|
    {
      c.ns      = createNamespace(["sys"])
      c.libName = "test.skew"
      c.input   = dir
      c.build   = zip
    }.compileLib
    return zip
  }

  ** Rewrite one key of the zip's meta props, or remove it if val is null
  private Void tamper(File zip, Str tag, Str? val)
  {
    entries := Uri:Buf[:] { ordered = true }
    z := Zip.read(zip.in)
    try
      z.readEach |f| { if (!f.isDir) entries[f.uri] = f.readAllBuf }
    finally z.close

    props := entries[XetoUtil.xetoMetaPropsUri].seek(0).readProps
    if (val == null) props.remove(tag); else props[tag] = val
    buf := Buf(); buf.writeProps(props)
    entries[XetoUtil.xetoMetaPropsUri] = buf

    out := Zip.write(zip.out)
    entries.each |content, uri| { out.writeNext(uri).writeBuf(content.seek(0)).close }
    out.close
  }

  private Lib compileZip(File zip)
  {
    XetoCompiler.init |c|
    {
      c.ns      = createNamespace(["sys"])
      c.libName = "test.skew"
      c.input   = zip
      c.log     = XetoCallbackLog.make(|XetoLogRec rec| {})
    }.compileLib
  }

  ** Read the "xeto-build.props" packaged inside the lib's own zip
  private Str:Str buildProps(Lib lib)
  {
    zip := Zip.open(tempDir + `zipenv/lib/xeto/${lib.name}.xetolib`)
    try
      return zip.contents.getChecked(XetoUtil.xetoBuildPropsUri).readProps
    finally
      zip.close
  }

//////////////////////////////////////////////////////////////////////////
// Content
//////////////////////////////////////////////////////////////////////////

  ** Reading content from a zip backed lib must work after the compile has
  ** finished: the LibFile reopens the zip rather than holding the handle
  ** the scanner used
  Void testReadContent()
  {
    ns := createZipNamespace(["hx.test.xeto"])
    if (ns == null) return

    files := ns.lib("hx.test.xeto").files
    verifyEq(files.get(`/res/a.txt`).readAllStr.trim, "alpha")
    verifyEq(files.get(`/res/subdir/b.txt`).readAllStr.trim, "beta")
    verifyEq(files.get(`/data/c.txt`).readAllStr.trim, "gamma")

    // repeat reads of the same file each reopen cleanly
    f := files.get(`/res/a.txt`)
    verifyEq(f.readAllStr.trim, "alpha")
    verifyEq(f.readAllStr.trim, "alpha")

    // metadata comes from the scan, so it is available without a reopen
    verify(f.size > 0)
    verifyNotNull(f.modified)
  }

//////////////////////////////////////////////////////////////////////////
// Specs
//////////////////////////////////////////////////////////////////////////

  ** Specs and instances must resolve the same from the zip, including
  ** across depends which are themselves loaded from zips
  Void testSpecs()
  {
    ns := createZipNamespace(["hx.test.xeto"])
    if (ns == null) return

    lib := ns.lib("hx.test.xeto")
    verifyEq(lib.spec("Alpha").qname, "hx.test.xeto::Alpha")
    verifyEq(lib.hasChapters, true)

    // a spec whose base comes from a depend loaded out of another zip
    verifyEq(ns.spec("ph::Site").name, "Site")

    // instances round trip
    verifyDictEq(lib.instance("simple-inst"),
      ["id":Ref("hx.test.xeto::simple-inst"), "dis":"hi"])
  }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  private Uri[] uris(LibFile[] files) { files.map |f->Uri| { f.uri }.sort }
}

