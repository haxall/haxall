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
  ** Info carries the box doctrine and an overridable title
  **
  Void testInfo()
  {
    ns := createNamespace(["sys", "sys.api"])
    buf := StrBuf()
    ex := OpenApiExporter(ns, buf.out, Etc.dict2("format", "json", "title", "Demo API"))
    ex.start
    ex.lib(ns.lib("sys.api"))
    ex.end

    doc := (Str:Obj?)JsonInStream(buf.toStr.in).readJson
    info := (Str:Obj?)doc["info"]
    verifyEq(info["title"], "Demo API")
    verifyEq(info["x-xeto-box"], "none")
    verify(((Str)info["description"]).contains("box=none"))
  }

  **
  ** A file typed param documents as a raw binary request body under the
  ** file spec's own mime type, and a file return as a binary response --
  ** the upload and download halves the dispatcher implements
  **
  Void testFileOps()
  {
    ns := createNamespace(["sys", "sys.api", "sys.files", "sys.repo"])
    ex := OpenApiExporter(ns, Buf().out, Etc.dict0)
    ex.lib(ns.lib("sys.repo"))

    // repoPublish { file: XetoLibFile } uploads the raw body
    pub := (Obj:Obj)ex.paths.getChecked("/api/{projName}/sys.repo.repoPublish")
    body := (Obj:Obj)((Obj:Obj)pub["post"])["requestBody"]
    schema := binarySchema((Obj:Obj)body["content"])
    verifyEq(schema["format"], "binary")

    // repoFetch returns XetoLibFile as a raw download
    fetch := (Obj:Obj)ex.paths.getChecked("/api/{projName}/sys.repo.repoFetch")
    responses := (Obj:Obj)((Obj:Obj)fetch["post"])["responses"]
    ok := (Obj:Obj)responses.getChecked("200")
    schema = binarySchema((Obj:Obj)ok["content"])
    verifyEq(schema["format"], "binary")
  }

  ** Dig the schema out of a binary content map keyed by the xetolib mime
  private Obj:Obj binarySchema(Obj:Obj content)
  {
    (Obj:Obj)((Obj:Obj)content.getChecked("application/xetolib"))["schema"]
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
