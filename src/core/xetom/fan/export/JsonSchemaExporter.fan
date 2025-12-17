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
    map["\$id"] = "$lib.name-$lib.version"

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
    // TODO
    if (!(spec.type.qname == "hx.test.xeto::Product" ||
          spec.type.qname == "hx.test.xeto::Order"))
      return

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

    defs[spec.name] = schema
  }

  private static Obj:Obj prop(Spec slot, Lib lib)
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
      return ["type": typeRef(slot.type, lib) ]
  }

  private static Str typeRef(Spec type, Lib lib)
  {
    return (type.lib.name == lib.name) ?
      "#/\$defs/$type.name" :
      "$type.lib.name#/\$defs/$type.name"
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  private static const Str:[Obj:Obj] primitives := [
    "sys::Str":      ["type": "string"],
    "sys::Bool":     ["\$ref": "sys-5.0.0#/\$defs/Bool"],
    "sys::Int":      ["\$ref": "sys-5.0.0#/\$defs/Int"],
    "sys::Float":    ["\$ref": "sys-5.0.0#/\$defs/Float"],
    "sys::Marker":   ["\$ref": "sys-5.0.0#/\$defs/Marker"],
    "sys::Ref":      ["\$ref": "sys-5.0.0#/\$defs/Ref"],
    "sys::DateTime": ["\$ref": "sys-5.0.0#/\$defs/DateTime"],
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
