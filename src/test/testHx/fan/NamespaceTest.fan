//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   26 May 2021  Brian Frank  Creation
//

using concurrent
using xeto
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
    proj.companion.update(Etc.dictSet(proj.companion.read("projB"), "axon", "20"))
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

}

