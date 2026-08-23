//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   26 May 2021  Brian Frank  Creation
//

using concurrent
using xeto
using xetom
using xetoc
using haystack
using axon
using hx

**
** NamespaceTest
**
class NamespaceTest : HxTest
{

//////////////////////////////////////////////////////////////////////////
// Defs (legacy)
//////////////////////////////////////////////////////////////////////////

  @HxTestProj
  Void testDefs()
  {
    // project haystack
    ph := verifyDefLib("ph", Pod.find("ph"),    `https://project-haystack.org/def/ph/`)
    verifyDefLib("phIoT",    Pod.find("phIoT"), `https://project-haystack.org/def/phIoT/`)

    // haxall libs
    hx   := verifyDefLib("hx",   Pod.find("hx"),    `/def/hx/`)
    axon := verifyDefLib("axon", Pod.find("axon"),  `/def/axon/`)

    // overlay lib
    ns1 := proj.defs
    overlayLib := ns1.libsList.find { it.name == "proj" }
    overlayName := overlayLib.name
    overlay1 := verifyLibDef(overlayName, sys.info.version, `/def/$overlayName/`)

    // add def rec
    verifyEq(proj.defs.def("customTag", false), null)
    tagRec := addRec(["def":Symbol("customTag"), "is":Symbol("str"), "doc":"?"])
    proj.sync

    // verify base stayed the same, but overlayout updated
    ns2 := proj.defs
    overlay2 := verifyLibDef(overlayName, sys.info.version, `/def/$overlayName/`)
    verifyNotSame(ns1, ns2)
    verifyNotSame(overlay1, overlay2)
    verifySame(ns1->base, ns2->base)
    verifySame(proj.defs.lib("ph"), ph)
    verifySame(proj.defs.lib("hx"), hx)

    // verify our new tag def
    tag := proj.defs.def("customTag") as Dict
    tag = Etc.dictRemove(tag, "linter")
    verifyDictEq(tag, ["id":tagRec.id, "mod":tagRec->mod, "def":Symbol("customTag"),
      "is":Symbol("str"), "lib":Symbol("lib:${overlayName}"), "doc":"?"])

  }

  DefLib verifyDefLib(Str name, Pod pod, Uri baseUri)
  {
    def := verifyLibDef(name, pod.version, baseUri)
    lib := proj.defs.lib(name)
    verifySame(lib, def)
    return def
  }

  Def verifyLibDef(Str name, Version ver, Uri baseUri)
  {
    def := proj.defs.lib(name)
    verifyEq(def.name, name)
    verifyEq(def->def, Symbol("lib:$name"))
    verifyEq(def.version, ver)
    verifyEq(def.baseUri, baseUri)
    return def
  }

//////////////////////////////////////////////////////////////////////////
// Thunk Reuse
//////////////////////////////////////////////////////////////////////////

  @HxTestProj
  Void testThunkReuse()
  {
    addLib("hx.task")
    addFunc("projA", "() => 1")
    addFunc("projB", "() => 2")
    verifyEq(eval("projA()"), n(1))
    verifyEq(eval("projB()"), n(2))

    ns1 := proj.ns
    t1 := ns1.spec("hx.task::Funcs.tasks").func.thunk
    a1 := ns1.spec("proj::Funcs.projA").func.thunk
    b1 := ns1.spec("proj::Funcs.projB").func.thunk
    /*
    echo("::: start")
    echo("  : t = $t1 0x" + Env.cur.idHash(t1))
    echo("  : a = $a1 0x" + Env.cur.idHash(a1))
    echo("  : b = $b1 0x" + Env.cur.idHash(b1))
    */

    // change namespace
    proj.companion.update(Etc.dictSet(proj.companion.readByName("projB"), "axon", "20"))
    ns2 := proj.ns
    verifyNotSame(ns1, ns2)
    verifyEq(eval("projA()"), n(1))
    verifyEq(eval("projB()"), n(20))

    // verify lib, a are same but that b is new thunk
    t2 := ns2.spec("hx.task::Funcs.tasks").func.thunk
    a2 := ns2.spec("proj::Funcs.projA").func.thunk
    b2 := ns2.spec("proj::Funcs.projB").func.thunk
    /*
    echo("::: change")
    echo("  : t = $t2 0x" + Env.cur.idHash(t2))
    echo("  : a = $a2 0x" + Env.cur.idHash(a2))
    echo("  : b = $b2 0x" + Env.cur.idHash(b2))
    */
    verifySame(t1, t2)
    verifySame(a1, a2)
    verifyNotSame(b1, b2)
  }

//////////////////////////////////////////////////////////////////////////
// Cache Keys
//////////////////////////////////////////////////////////////////////////

  ** Lib.cacheKey keys caches derived from a lib, and the runtime's pack
  ** digest composes those keys.  What matters is that the same content
  ** gives the same value, and any change gives a different one.
  @HxTestProj
  Void testCacheKeys()
  {
    ns := proj.ns

    // every lib has a key, stable on repeated reads and unique per lib
    byKey := Str:Str[:]
    ns.libs.each |lib|
    {
      key := lib.cacheKey
      verify(!key.isEmpty)
      verifySame(key, lib.cacheKey)

      dup := byKey[key]
      if (dup != null) fail("$lib.name and $dup have the same cacheKey")
      byKey[key] = lib.name
    }
    verifyEq(byKey.size, ns.libs.size)

    // the pack digest is derived from those keys
    pack1 := proj.libs.pack
    verify(!pack1.cacheKey.isEmpty)
    verifySame(pack1, proj.libs.pack)

    // the pack carries the runtime's own libs, never the companion
    verify(pack1.libs.all |lib| { lib.name != "proj" })

    // the pack keeps dependency order: a reader loads the libs in this
    // order and resolves each one's depends as it goes, so sorting them
    // by name would leave a lib referring to one not yet loaded
    verifyEq(pack1.libs.first.name, "sys")
    verifyLibsInDependOrder(pack1.libs)

    // a sys lib is not part of a project's pack, so enabling one
    // leaves the digest alone
    addLib("hx.task")
    pack2 := proj.libs.pack
    verifyEq(pack1.cacheKey, pack2.cacheKey)

    // and the libs it does carry keep their keys across the rebuild
    ns2 := proj.ns
    pack1.libs.each |old|
    {
      cur := ns2.lib(old.name, false)
      if (cur != null) verifyEq(old.cacheKey, cur.cacheKey)
    }
  }

  ** A lib read from its xetolib zip keys the same as the same lib read
  ** from its source dir.  The zip keeps the source file timestamps but
  ** truncates them to its two second resolution, so the key rounds to
  ** that resolution to let both forms share one cached artifact.
  Void testCacheKeyZipMatchesSource()
  {
    env := XetoEnv.cur
    name := "hx.test.xeto"

    // resolve from source, which is how the dev environment loads it
    vers := env.repo.resolveDepends([LibDepend(name)])
    srcLib := env.createNamespace(vers).lib(name)

    // skip unless every lib in the closure has a built zip; this is a
    // dev environment which builds from source, so the zips only exist
    // once the libs have been built
    missing := vers.findAll |v| { XetoUtil.srcToLibZip(v)?.exists != true }
    if (!missing.isEmpty)
    {
      echo("SKIP testCacheKeyZipMatchesSource: no zip for " + missing.map |v->Str| { v.name })
      return
    }

    // load the same closure from the zips
    zipVers := vers.map |v->LibVersion| { FileLibVersion.loadZipFile(XetoUtil.srcToLibZip(v)) }
    zipLib := env.createNamespace(zipVers).lib(name)

    verifyEq(uris(zipLib.files.list), uris(srcLib.files.list))
    verifyEq(zipLib.cacheKey, srcLib.cacheKey)
  }

  ** Verify every lib comes after all the libs it depends on
  private Void verifyLibsInDependOrder(Lib[] libs)
  {
    seen := Str:Str[:]
    libs.each |lib|
    {
      lib.depends.each |d|
      {
        // a depend outside this set is fine; one inside must come first
        if (libs.any |x| { x.name == d.name } && seen[d.name] == null)
          fail("$lib.name comes before its depend $d.name")
      }
      seen[lib.name] = lib.name
    }
  }

  private Uri[] uris(LibFile[] files) { files.map |f->Uri| { f.uri }.sort }

}

