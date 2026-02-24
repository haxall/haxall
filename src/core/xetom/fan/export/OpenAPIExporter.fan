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
** OpenAPI Exporter
**
@Js
class OpenAPIExporter : Exporter
{

//////////////////////////////////////////////////////////////////////////
// Constructor
//////////////////////////////////////////////////////////////////////////

  new make(MNamespace ns, OutStream out, Dict opts) : super(ns, out, opts)
  {
    schemaExporter = JsonSchemaExporter(ns, out, Etc.dict0, "components/schemas")

    map["openapi"] = "3.0.0"
    map["info"] = [
      "title": "Xeto OpenApi definition",
      "version": "0.0.1"
    ]
    map["paths"] = paths
    map["components"] = [
      "schemas": schemaExporter.defs,
      "parameters": [
        "projName": [
          "name": "projName",
          "in": "path",
          "required": "true",
          "schema": [
            "type": "string",
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
    //js := JsonOutStream(Env.cur.out)
    //js.prettyPrint = true
    //js.writeJson(map)

    ym := YamlWriter(Env.cur.out)
    ym.writeYaml(map)
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

    path := spec.qname
    n := path.index("::Funcs.")
    if (n != null)
      path = path[0..n+1] + path[(n+"..Funcs.".size)..-1]
    uri := "/api/{projName}/" + path.replace("::", ".")

    props := Obj:Obj[:]
    required := Obj[,]
    response := Obj:Obj[:]
    responseRequired := false

    slots := spec.slots()
    slots.each |slot, name|
    {
      if (name == "returns")
      {
        if (!slot.isMaybe)
          responseRequired = true
        response = schemaExporter.prop(slot)
      }
      else
      {
        if (!slot.isMaybe)
          required.add(name)
        props[name] = schemaExporter.prop(slot)
      }
    }

    // request body
    reqSchema := ["type": "object", "properties": props]
    if (required.size > 0)
      reqSchema["required"] = required
    requestBody := [
      "required": true,
      "content": jsonSchema(reqSchema)
    ]

    // responses
    responses := Obj:Obj[:] { ordered = true }
    responses["'200'"] = [
      "description": "Success",
      "content": jsonSchema(response)
    ]

    if (!responseRequired)
      responses["'204'"] = [
        "description": "No data returned"
      ]

    responses["'400'"] = [
      "description": "Bad Request",
      "content": jsonSchema(["type": "object"])
    ]

    // done
    paths[uri] = [
      "post": [
        "requestBody": requestBody,
        "responses": responses,
        "parameters": [["\$ref": "#/components/parameters/projName"]],
      ]
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

  private Obj:Obj map := [:] { ordered = true }
  private Obj:Obj paths := [:] { ordered = true }
}
