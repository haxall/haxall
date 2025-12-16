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
    // TODO
    if (!(spec.type.qname == "hx.test.xeto::Product" ||
          spec.type.qname == "hx.test.xeto::Order"))
      return
    //echo("doSpec: $spec")

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
        props[name] = prop(name, slot.type, spec.lib)
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

  private static Obj:Obj prop(Str name, Spec type, Lib lib)
  {
    // TODO
    //debug := "  prop name:$name type:$type isList:$type.isList"
    //if (type.isList())
    //{
    //  // If of() is called with checked := true, we get
    //  // xeto::UnknownNameErr: Missing 'of' meta
    //  listOf := type.of(false)
    //  debug += " of:$listOf"
    //}
    //echo(debug)

    // json primitives
    if      (type.qname == "sys::Int")   return [ "type": "string" /*TODO "integer"*/ ]
    else if (type.qname == "sys::Float") return [ "type": "string" /*TODO "number" */ ]
    else if (type.qname == "sys::Str")   return [ "type": "string"  ]
    else if (type.qname == "sys::Bool")  return [ "type": "boolean" ]

    // sys primitives
    else if (type.qname == "sys::Marker")   return [ "\$ref": "sys-5.0.0#/\$defs/Marker" ]
    else if (type.qname == "sys::Ref")      return [ "\$ref": "sys-5.0.0#/\$defs/Ref" ]
    else if (type.qname == "sys::DateTime") return [ "\$ref": "sys-5.0.0#/\$defs/DateTime" ]

    // list
    else if (type.isList())
    {
      return [
        "type": "array",
        // TODO "items": [ "\$ref": typeRef(type.of, lib) ]
        "items": [ "\$ref": "#/\$defs/Product" ]
      ]
    }

    // anything else
    else
      return ["type": typeRef(type, lib) ]
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
