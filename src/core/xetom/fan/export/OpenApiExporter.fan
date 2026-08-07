//
// Copyright (c) 2024, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   10 Dec 2025  Mike Jarmy  Creation
//

using xeto
using haystack
using util
using yaml

**
** OpenApi Exporter
**
@Js
class OpenApiExporter : Exporter
{

//////////////////////////////////////////////////////////////////////////
// Constructor
//////////////////////////////////////////////////////////////////////////

  new make(MNamespace ns, OutStream out, Dict opts) : super(ns, out, opts)
  {
    schemaExporter = JsonSchemaExporter(ns, out, opts, "components/schemas", false)

    errRef = schemaExporter.ensureRef(ns.spec("sys::Err"))

    map["openapi"] = "3.1.0"
    map["jsonSchemaDialect"] = JsonSchemaExporter.dialect
    sysVer := ns.sysLib.version

    // TODO: title and version want a project handle, which the exporter
    // does not have until the /openapi.json endpoint passes one in.
    map["info"] = [
      "title": "Xeto API",
      "version": sysVer.toStr,
      "x-xeto-libs": ns.versions.map |v->Obj| {
        Obj:Obj["name": v.name, "version": v.version.toStr]
      },
    ]
    map["paths"] = paths
    map["components"] = [
      "schemas": schemaExporter.defs,
      "parameters": [
        "projName": [
          "name": "projName",
          "in": "path",
          "required": true,
          "schema": [
            "type": "string",
          ]
        ],
        "xetoVersion": [
          "name": "Xeto-Version",
          "in": "header",
          "required": true,
          "schema": [
            "const": sysVer.major.toStr,
          ]
        ]
      ]
    ]
  }

//////////////////////////////////////////////////////////////////////////
// API
//////////////////////////////////////////////////////////////////////////

  override This start()
  {
    return this
  }

  override This end()
  {
    format := opts["format"] ?: "yaml"
    if (format == "json")
    {
      js := JsonOutStream(out)
      js.prettyPrint = true
      js.writeJson(map)
    }
    else if (format == "yaml")
    {
      ym := YamlWriter(out)
      ym.writeYaml(map)
    }
    else
    {
      throw Err("${format} is an invalid output format")
    }

    return this
  }

  override This lib(Lib lib)
  {
    lib.specs.each |x| {
      doSpec(x)
    }

    return this
  }

  override This spec(Spec spec)
  {
    doSpec(spec)
    return this
  }

  override This instance(Dict instance)
  {
    // no-op
    return this
  }

//////////////////////////////////////////////////////////////////////////
// private
//////////////////////////////////////////////////////////////////////////

  private Void doSpec(Spec spec)
  {
    if (spec.type.qname == "sys::Funcs")
    {
      slots := spec.slots()
      slots.each |slot| { doFunc(slot) }
    }
    else if (spec.isFunc)
    {
      doFunc(spec)
    }
  }

  private Void doFunc(Spec spec)
  {
    //-------------------------------------------------
    //if (!["hx::Funcs.read"].contains(spec.qname)) return
    //-------------------------------------------------

    uri := spec.qname
    n := uri.index("::Funcs.")
    if (n != null)
      uri = uri[0..n+1] + uri[(n+"..Funcs.".size)..-1]
    uri = "/api/{projName}/" + uri.replace("::", ".")

    // request body
    reqSchema := schemaExporter.funcToParams(spec)
    props := (Str:Obj)reqSchema["properties"]
    requestBody := [
      "required": true,
      "content": jsonSchema(reqSchema)
    ]

    // response
    response := Obj:Obj[:]
    returns := spec.slot("returns", false)
    if (returns != null)
    {
      response = schemaExporter.prop(returns)
      // the response body has no key to omit, so a maybe return really can
      // answer JSON null -- ApiDispatchV5 writes it literally
      if (returns.isMaybe)
        response = schemaExporter.nullable(response)
    }

    // responses
    responses := Obj:Obj[:] { ordered = true }
    responses["'200'"] = [
      "description": "Success",
      "content": jsonSchema(response)
    ]

    responses["'400'"] = [
      "description": "Bad Request",
      "content": jsonSchema(errRef)
    ]

    // path
    path := Obj:Obj[:] { ordered = true }
    doc := spec.metaOwn["doc"]
    if (doc != null)
      path["description"] = doc

    // GET
    if (props.isEmpty && spec.meta.has("noSideEffects"))
      path["get"] =  [
        "responses": responses,
        "parameters": opParams,
      ]
    // POST
    else
      path["post"] =  [
        "requestBody": requestBody,
        "responses": responses,
        "parameters": opParams,
      ]

    // done
    paths[uri] = path
  }

  ** Params every operation carries.  Returns a fresh list each call so
  ** nothing downstream mutates a shared map.
  private static Obj[] opParams()
  {
    return [
      Obj:Obj["\$ref": "#/components/parameters/projName"],
      Obj:Obj["\$ref": "#/components/parameters/xetoVersion"],
    ]
  }

  private static Obj:Obj jsonSchema(Obj:Obj schema)
  {
    return [
      "application/json": [
        "schema": schema
      ]
    ]
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  private JsonSchemaExporter schemaExporter
  private Obj:Obj errRef

  private Obj:Obj map := [:] { ordered = true }
  private Obj:Obj paths := [:] { ordered = true }
}
