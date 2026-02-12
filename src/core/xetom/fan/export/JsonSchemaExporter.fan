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

  Void doSpec(Spec spec)
  {
    if (alreadyDefined(spec))
      return

    if (spec.isEnum)
      doSpecEnum(spec)
    else if (spec.isScalar)
      doSpecScalar(spec)
    else
      doSpecObj(spec)
  }

  private Bool alreadyDefined(Spec spec)
  {
    if (defined.containsKey(spec.qname))
      return true
    defined[spec.qname] = Marker.val
    return false
  }

  private Void doSpecScalar(Spec spec)
  {
    addDef(spec, [
      "type": "string",
      "pattern": spec.meta["pattern"]
    ])
  }

  private Void doSpecEnum(Spec spec)
  {
    addDef(spec, [
      "type": "string",
      "enum": spec.enum.keys
    ])
  }

  private Void doSpecObj(Spec spec)
  {
    //------------------------------
    // properties

    props := Obj:Obj[:]
    required := Obj[,]

    slots := spec.slots()
    slots.each |slot, name|
    {
      if (!slot.isMaybe)
        required.add(name)
      props[name] = prop(slot, spec.lib)
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
      {
        if (!type.isAnd)
          throw Err("TODO Compound type not supported: $type")

        allOf := [schema]
        type.ofs.each |of|
        {
          allOf.add(["\$ref": typeRef(of)])
        }
        addDef(spec, [ "allOf": allOf ])
      }
      else
      {
        if (type.base.qname == "sys::Dict")
        {
          addDef(spec, schema)
        }
        else
        {
          addDef(
            spec, [
              "allOf": [
                ["\$ref": typeRef(type.base)],
                schema
              ]
            ])
        }
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
    {
      res := Obj:Obj["type": "array"]
      of := slot.of(false)
      if (of != null)
        res["items"] = ["\$ref": typeRef(of)]
      return res
    }

    // anything else
    else
      return ["\$ref": typeRef(slot.type) ]
  }

  private Str typeRef(Spec type)
  {
    // recursively ensure that everything is defined.
    doSpec(type)

    // create a typeref
    nameVer := libNameVer(type.lib)
    return "#/\$defs/$nameVer/$type.name"
  }

  private Void addDef(Spec type, Obj:Obj schema)
  {
    nameVer := libNameVer(type.lib)
    if (!defs.containsKey(nameVer))
      defs[nameVer] = Obj:Obj[:]

    defs[nameVer][type.name] = schema
  }

  static Str libNameVer(Lib lib)
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

  // qnames that have already been defined
  private Str:Marker defined := Str:Marker[:]

  private Obj:Obj map := [:] { ordered = true }
  /*private*/ Obj:[Obj:Obj] defs := [:] { ordered = true }
}
