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
** JSON Schema Exporter
**
@Js
class JsonSchemaExporter : Exporter
{

//////////////////////////////////////////////////////////////////////////
// Constructor
//////////////////////////////////////////////////////////////////////////

  new make(MNamespace ns, OutStream out, Dict opts) : super(ns, out, opts)
  {
    map["\$defs"] = defs
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
    map["\$schema"] = "https://json-schema.org/draft/2020-12/schema"
    map["\$id"]     = lib.id.toStr
    map["title"]    = lib.name
    map["version"]  = lib.version.toStr

    lib.specs.each |x| { doSpec(x) }

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
    schema := Obj:Obj[
      "type": "object",
      // Allows subtype-specific fields.
      "additionalProperties": true
    ]

    // properties
    slots := spec.slotsOwn()
    if (!slots.isEmpty())
    {
      props := Obj:Obj[:]
      required := Obj[,]

      slots.each |slot, name|
      {
        if (!slot.isMaybe)
          required.add(name)

        type := slot.type
        prim := primitiveTypeName(type)

        // not primitive
        if (prim == null)
        {
          typeName := type.name
          typeLib := type.lib.name

          // internal
          if (typeLib == spec.lib.name)
            props[name] = ["\$ref": "#/\$defs/$typeName"]
          // external
          else
            props[name] = ["\$ref": "$typeLib#/\$defs/$typeName"]
        }
        // primitive
        else
        {
          props[name] = ["type": prim]
        }
      }

      schema["properties"] = props
      if (required.size > 0)
        schema["required"] = required
    }

    defs[spec.qname] = schema
  }

  private static Str? primitiveTypeName(Spec type)
  {
    if      (type.qname == "sys::Int")  return "integer"
    else if (type.qname == "sys::Str")  return "string"
    else if (type.qname == "sys::Bool") return "boolean"
    else
      return null
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  private Obj:Obj map := [:]
  private Obj:Obj defs := [:]
}

