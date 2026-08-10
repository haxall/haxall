//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   7 Aug 2026  Mike Jarmy  Creation
//

using util
using xeto
using xetom
using haystack

**
** OpenApiTest
**
@Js
class OpenApiTest : AbstractXetoTest
{

  **
  ** C2: only <op> funcs publish.  Without the filter a real project's doc
  ** is enormous and mostly Axon vocabulary.
  **
  Void testOpFilter()
  {
    ns := createNamespace(["sys", "sys.api", "axon"])
    ex := OpenApiExporter(ns, Buf().out, Etc.dict0)
    ex.lib(ns.lib("sys.api"))
    ex.lib(ns.lib("axon"))

    // sys.api marks its funcs <op>
    verify(ex.paths.containsKey("/api/{projName}/sys.api.readById"))
    verify(ex.paths.containsKey("/api/{projName}/sys.api.about"))

    // axon is vocabulary, not an API surface -- nothing from it publishes
    ex.paths.keys.each |k|
    {
      verify(((Str)k).startsWith("/api/{projName}/sys.api."), "unexpected path: $k")
    }
  }

  **
  ** C3: <op, noSideEffects> composes to a GET; <op> alone is a POST.
  **
  Void testMethodFromSideEffects()
  {
    ns := createNamespace(["sys", "sys.api"])
    ex := OpenApiExporter(ns, Buf().out, Etc.dict0)
    ex.lib(ns.lib("sys.api"))

    // about: Func <op, noSideEffects> { returns: AboutInfo } -- no params
    about := (Obj:Obj)ex.paths.getChecked("/api/{projName}/sys.api.about")
    verifyNotNull(about["get"])
    verifyEq(about["post"], null)

    // close: Func <op> { returns: None } -- side effects, so POST
    close := (Obj:Obj)ex.paths.getChecked("/api/{projName}/sys.api.close")
    verifyNotNull(close["post"])
    verifyEq(close["get"], null)

    // every operation carries both hoisted params
    params := (Obj[])((Obj:Obj)about["get"])["parameters"]
    verifyEq(params.size, 2)
    verifyEq(((Obj:Obj)params[0])["\$ref"], "#/components/parameters/projName")
    verifyEq(((Obj:Obj)params[1])["\$ref"], "#/components/parameters/xetoVersion")
  }

  **
  ** B4: standard error responses on every operation, keyed by plain "400"
  ** rather than the old "'400'".
  **
  Void testErrorResponses()
  {
    ns := createNamespace(["sys", "sys.api"])
    ex := OpenApiExporter(ns, Buf().out, Etc.dict0)
    ex.lib(ns.lib("sys.api"))

    about := (Obj:Obj)ex.paths.getChecked("/api/{projName}/sys.api.about")
    responses := (Obj:Obj)((Obj:Obj)about["get"])["responses"]

    verifyNotNull(responses["200"])
    ["400", "401", "403", "404", "500"].each |code|
    {
      resp := responses[code] as Obj:Obj
      verifyNotNull(resp, "missing response: $code")
      content := (Obj:Obj)((Obj:Obj)resp["content"])["application/json"]
      verifyEq(((Obj:Obj)content["schema"])["\$ref"],
               "#/components/schemas/sys.Err")
    }
  }

  **
  ** C4: a cross-lib collision of <op> names is a generator error, not a
  ** silent last-wins -- the published surface is addressed by unqualified
  ** name in Axon.
  **
  Void testCollisionDetection()
  {
    ns := createNamespace(["sys", "sys.api"])

    // a second lib publishing "about" collides with sys.api::Funcs.about
    lib := ns.compileTempLib(
      Str<|+Funcs {
             about: Func <op, noSideEffects> { returns: Dict }
           }|>)

    ex := OpenApiExporter(ns, Buf().out, Etc.dict0)
    ex.lib(ns.lib("sys.api"))
    verifyErr(Err#) { ex.lib(lib) }
  }
}
