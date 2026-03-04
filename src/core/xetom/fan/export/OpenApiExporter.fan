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
    schemaExporter = JsonSchemaExporter(ns, out, opts, "components/schemas")

    errRef = schemaExporter.ensureRef(ns.spec("sys::Err"))

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
    format := opts["format"] ?: "yaml"
    if (format == "json")
    {
      js := JsonOutStream(Env.cur.out)
      js.prettyPrint = true
      js.writeJson(map)
    }
    else if (format == "yaml")
    {
      ym := YamlWriter(Env.cur.out)
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

    props := Obj:Obj[:]
    required := Obj[,]
    response := Obj:Obj[:]

    slots := spec.slots()
    slots.each |slot, name|
    {
      if (name == "returns")
      {
        response = schemaExporter.prop(slot)
        if (slot.isMaybe)
          response["nullable"] = true
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
        "parameters": [["\$ref": "#/components/parameters/projName"]],
      ]
    // POST
    else
      path["post"] =  [
        "requestBody": requestBody,
        "responses": responses,
        "parameters": [["\$ref": "#/components/parameters/projName"]],
      ]

    // done
    paths[uri] = path
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
