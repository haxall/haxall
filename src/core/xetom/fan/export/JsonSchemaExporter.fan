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
    //map["\$schema"] = "https://json-schema.org/draft/2020-12/schema"
    map["\$schema"] = "http://json-schema.org/draft-07/schema#"
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
    map["\$defs"] = defs

    js := JsonOutStream(Env.cur.out)
    js.prettyPrint = true
    js.writeJson(map)
    return this
  }

  override This lib(Lib lib)
  {
    map["\$id"] = libNameVer(lib)

    if (lib.meta.has("doc"))
      map["title"] = lib.meta->doc

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
    if (seenAlready(spec))
      return

    if (spec.isEnum)
      doSpecEnum(spec)
    else if (spec.isScalar)
      doSpecScalar(spec)
    else
      doSpecObj(spec)
  }

  private Bool seenAlready(Spec spec)
  {
    if (seen.containsKey(spec.qname))
      return true
    seen[spec.qname] = Marker.val
    return false
  }
  private Str:Marker seen := Str:Marker[:]

  private Void doSpecScalar(Spec spec)
  {
    defs[spec.name] = [
      "type": "string",
      "pattern": spec.meta["pattern"]
    ]
  }

  private Void doSpecEnum(Spec spec)
  {
    defs[spec.name] = [
      "type": "string",
      "enum": spec.enum.keys
    ]
  }

  private Void doSpecObj(Spec spec)
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
        props[name] = prop(slot, spec.lib)
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
    if (type.base != null)
    {
      if (type.isCompound)
        throw Err("TODO Compound type not supported: $type")

      if (type.base.qname == "sys::Dict")
      {
        defs[spec.name] = schema
      }
      else
      {
        defs[spec.name] = ["allOf": [
          ["\$ref": typeRef(type.base, spec.lib) ],
          schema
        ]]
      }
    }
  }

  private Obj:Obj prop(Spec slot, Lib lib)
  {
    // primitives
    prm := primitives.getChecked(slot.type.qname, false)
    if (prm != null) return prm

    // list
    else if (slot.type.isList())
      return [
        "type": "array",
         "items": [ "\$ref": typeRef(slot.of, lib) ]
      ]

    // anything else
    else
      return ["\$ref": typeRef(slot.type, lib) ]
  }

  private Str typeRef(Spec type, Lib lib)
  {
    doSpec(type)

    return (type.lib.name == lib.name) ?
      "#/\$defs/$type.name" :
      "${libNameVer(type.lib)}#/\$defs/$type.name"
  }

  private static Str libNameVer(Lib lib)
  {
     return "$lib.name-$lib.version"
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  private static const Str:[Obj:Obj] primitives := [
    "sys::Str":   ["type": "string"],
    "sys::Bool":  ["type": "boolean"],
    "sys::Int":   ["type": "integer"],
    "sys::Float": ["type": "number"],
  ]

  private Obj:Obj map := [:] { ordered = true }
  private Obj:Obj defs := [:] { ordered = true }
}

//    //------------------------------
//    // inheritance
//
//    type := spec.type
//
//    // sys::Obj
//    if (type.base == null)
//    {
//      defs[spec.qname] = schema
//    }
//    else
//    {
//      allOf := Obj[,]
//
//      // compound
//      if (type.isCompound)
//      {
//        type.ofs.each |cmp|
//        {
//          allOf.add(["\$ref": typeRef(cmp, spec.lib) ])
//        }
//      }
//      // single inheritance
//      else
//      {
//        allOf.add(["\$ref": typeRef(type.base, spec.lib) ])
//      }
//
//      allOf.add(schema)
//      defs[spec.qname] = ["allOf": allOf]
//    }
//  }
