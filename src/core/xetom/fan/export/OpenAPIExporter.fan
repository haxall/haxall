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
    //required := Obj[,]
    Str response := ""

    slots := spec.slots()
    slots.each |slot, name|
    {
      //if (!slot.isMaybe)
      //  required.add(name)

      if (name == "returns")
        response = typeRef(slot.type)
      else
        props[name] = typeRef(slot.type)
    }

    post := [
      "requestBody": [
        //"required": true,
        "content": [
          "application/json": [
            "schema": [
              "type": "object",
              //"required": required,
              "properties": props
            ]
          ]
        ]
      ],
      "responses": [
        "200": [
          "content": [
            "application/json": [
              "schema": [
                "\$ref": response
              ]
            ]
          ]
        ],
        "400": "TODO"
      ]
    ]

//"post": {
//  "summary": "Add a new pet",
//  "requestBody": {
//    "description": "Information about the pet to add",
//    "required": true,
//    "content": {
//      "application/json": {
//        "schema": {
//          "$ref": "#/components/schemas/Pet"
//        }
//      }
//    }
//  },
//  "responses": {
//    "201": {
//      "description": "Pet created successfully"
//    },
//    "400": {
//      "description": "Invalid input"
//    }
//  }
//}

    paths[uri] = ["post": post]
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
