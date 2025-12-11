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
    //map["\$schema"] = "https://json-schema.org/draft/2020-12/schema"
    map["\$schema"] = "http://json-schema.org/draft-07/schema#"

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
    //------------------------------
    // properties

    props := Obj:Obj[:]
    required := Obj[,]

    slots := spec.slotsOwn()
    if (!slots.isEmpty())
    {
      slots.each |slot, name|
      {
        if (!slot.isMaybe)
          required.add(name)

        type := slot.type
        prim := primitiveTypeName(type)
        if (prim == null)
          props[name] = ["\$ref": typeRef(type, spec.lib) ]
        else
          props[name] = ["type": prim]
      }
    }

    //------------------------------
    // schema

    schema := Obj:Obj[
      "type": "object",
      "additionalProperties": true, // Allows subtype-specific fields.
    ]
    if (props.size > 0)
      schema["properties"] = props
    if (required.size > 0)
      schema["required"] = required

    //------------------------------
    // inheritance

    type := spec.type

    // sys::Obj
    if (type.base == null)
    {
      defs[spec.qname] = schema
    }
    else
    {
      allOf := Obj[,]

      // compound
      if (type.isCompound)
      {
        type.ofs.each |cmp|
        {
          allOf.add(["\$ref": typeRef(cmp, spec.lib) ])
        }
      }
      // single inheritance
      else
      {
        allOf.add(["\$ref": typeRef(type.base, spec.lib) ])
      }

      allOf.add(schema)
      defs[spec.qname] = ["allOf": allOf]
    }
  }

  private static Str typeRef(Spec type, Lib curLib)
  {
    // internal
    if (type.lib.name == curLib.name)
      return "#/\$defs/$type.name"
    else
      return"$type.lib.name#/\$defs/$type.name"
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

