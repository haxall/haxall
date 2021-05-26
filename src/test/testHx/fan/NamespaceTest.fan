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
    verifyLib("ph",     Pod.find("ph"),    `https://project-haystack.org/def/ph/`)
    verifyLib("phIoT",  Pod.find("phIoT"), `https://project-haystack.org/def/phIoT/`)
    verifyLib("hx",     Pod.find("hx"),    `https://haxall.io/def/hx/`)
  }

  Void verifyLib(Str name, Pod pod, Uri baseUri)
  {
    def := rt.ns.lib(name)
    verifyEq(def.name, name)
    verifyEq(def->def, Symbol("lib:$name"))
    verifyEq(def.version, pod.version)
    verifyEq(def.baseUri, baseUri)

    lib := rt.lib(name)
    verifySame(lib.def, def)
  }

}