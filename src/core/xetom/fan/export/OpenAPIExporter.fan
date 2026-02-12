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
    schemaExporter = JsonSchemaExporter(ns, out, Etc.dict0)

    map["openapi"] = "3.0.0"
    map["paths"] = paths
    map["components"] = schemaExporter.defs
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
    js := JsonOutStream(Env.cur.out)
    js.prettyPrint = true
    js.writeJson(map)
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
    if (!spec.isFunc)
      return

    uri := "/api/" + spec.qname.replace("::", ".")

    props := Obj:Obj[:]
    required := Obj[,]
    response := ""
    responseRequired := false

    slots := spec.slots()
    slots.each |slot, name|
    {
      if (name == "returns")
      {
        if (!slot.isMaybe)
          responseRequired = true
        response = typeRef(slot.type)
      }
      else
      {
        if (!slot.isMaybe)
          required.add(name)
        props[name] = typeRef(slot.type)
      }
    }

    // request body
    requestBody := Obj:Obj[:] { ordered = true }
    if (props.size == 1)
    {
      requestBody = [
        "required": required.contains(props.keys[0]),
        "content": [
          "application/json": [
            "schema": [
                "\$ref": props.vals[0]
            ]
          ]
        ]
      ]
    }
    else
    {
      requestBody = [
        "required": true,
        "content": [
          "application/json": [
            [
              "type": "object",
              "required": required,
              "properties": props
            ]
          ]
        ]
      ]
    }

    // responses
    responses := Obj:Obj[:] { ordered = true }
    responses["200"] = [
      "content": [
        "application/json": [
          "schema": [
            "\$ref": response
          ]
        ]
      ]
    ]
    if (!responseRequired)
      responses["204"] = ["description": "No data returned"]
    responses["400"] = ["description": "TODO 4xx"]

    // done
    paths[uri] = [
      "post": [
        "requestBody": requestBody,
        "responses": responses
      ]
    ]
  }

  private Str typeRef(Spec type)
  {
    // recursively ensure that everything is defined.
    schemaExporter.doSpec(type)

    // create a typeref
    nameVer := JsonSchemaExporter.libNameVer(type.lib)
    return "#/components/$nameVer/$type.name"
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  private JsonSchemaExporter schemaExporter

  private Obj:Obj map := [:] { ordered = true }
  private Obj:Obj paths := [:] { ordered = true }
}
