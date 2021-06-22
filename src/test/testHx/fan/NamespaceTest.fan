//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   26 May 2021  Brian Frank  Creation
//

using concurrent
using haystack
using axon
using hx

**
** NamespaceTest
**
class NamespaceTest : HxTest
{

  @HxRuntimeTest
  Void testBasics()
  {
    // project haystack
    ph := verifyLib("ph",     Pod.find("ph"),    `https://project-haystack.org/def/ph/`)
    verifyLib("phIoT",  Pod.find("phIoT"), `https://project-haystack.org/def/phIoT/`)
    verifyLib("hx",     Pod.find("hx"),    `https://haxall.io/def/hx/`)

    // haxall libs
    hx   := verifyLib("hx",   Pod.find("hx"),    `https://haxall.io/def/hx/`)
    axon := verifyLib("axon", Pod.find("axon"),  `https://haxall.io/def/axon/`)

    // overlay lib
    ns1 := rt.ns
    overlayName := ns1.libsList.find { it.name.contains("_") }.name // proj_{name} or hx_db
    overlay1 := verifyLibDef(overlayName,  rt.version, rt.siteUri+`/def/$overlayName/`)

    // add def rec
    verifyEq(rt.ns.def("customTag", false), null)
    tagRec := addRec(["def":Symbol("customTag"), "is":Symbol("str"), "doc":"?"])
Actor.sleep(250ms) // TODO

    // verify base stayed the same, but overlayout updated
    ns2 := rt.ns
    overlay2 := verifyLibDef(overlayName,  rt.version, rt.siteUri+`/def/$overlayName/`)
    verifyNotSame(ns1, ns2)
    verifyNotSame(overlay1, overlay2)
    verifySame(ns1->base, ns2->base)
    verifySame(rt.ns.lib("ph"), ph)
    verifySame(rt.ns.lib("hx"), hx)

    // verify our new tag def
    tag := rt.ns.def("customTag") as Dict
    tag = Etc.dictRemove(tag, "linter")
    verifyDictEq(tag, ["id":tagRec.id, "mod":tagRec->mod, "def":Symbol("customTag"),
      "is":Symbol("str"), "lib":Symbol("lib:${overlayName}"), "doc":"?"])

  }

  Lib verifyLib(Str name, Pod pod, Uri baseUri)
  {
    def := verifyLibDef(name, pod.version, baseUri)
    lib := rt.lib(name)
    verifySame(lib.def, def)
    return def
  }

  Def verifyLibDef(Str name, Version ver, Uri baseUri)
  {
    def := rt.ns.lib(name)
    verifyEq(def.name, name)
    verifyEq(def->def, Symbol("lib:$name"))
    verifyEq(def.version, ver)
    verifyEq(def.baseUri, baseUri)
    return def
  }

}