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

  @HxTestProj
  Void testBasics()
  {
    // project haystack
    ph := verifyLib("ph", Pod.find("ph"),    `https://project-haystack.org/def/ph/`)
    verifyLib("phIoT",    Pod.find("phIoT"), `https://project-haystack.org/def/phIoT/`)
    verifyLib("hx",       Pod.find("hx"),    `/def/hx/`)

    // haxall libs
    hx   := verifyLib("hx",   Pod.find("hx"),    `/def/hx/`)
    axon := verifyLib("axon", Pod.find("axon"),  `/def/axon/`)

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

  DefLib verifyLib(Str name, Pod pod, Uri baseUri)
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

}

