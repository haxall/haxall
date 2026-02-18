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

  new make(MNamespace ns, OutStream out, Dict opts, Str refPath := "\$defs") : super(ns, out, opts)
  {
    this.refPath = refPath

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
    if (spec.isEnum)
    {
      addDef(spec, [
        "type": "string",
        "enum": spec.enum.keys
      ])
    }
    else
    {
      prm := primitives.getChecked(spec.qname, false)

      addDef(spec, prm ?: [
        "type": "string",
        "pattern": spec.meta["pattern"]
      ])
    }
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
      props[name] = prop(slot)
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
          allOf.add(typeRef(of))
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
                typeRef(type.base),
                schema
              ]
            ])
        }
      }
    }
  }

  private Void addDef(Spec type, Obj:Obj schema)
  {
//    echo("---------------------------")
//    echo("addDef: $type.qname")
//    Err("foo").trace(Env.cur.out)

    nameVer := libNameVer(type.lib)
    if (!defs.containsKey(nameVer))
      defs[nameVer] = Obj:Obj[:]

    defs[nameVer][type.name] = schema
  }

  private static Str libNameVer(Lib lib)
  {
     return "$lib.name-$lib.version"
  }

  Obj:Obj prop(Spec slot)
  {
    // primitives
    prm := primitives.getChecked(slot.type.qname, false)
    if (prm != null) return prm

    // base obj -- "any" type
    if (slot.type.qname == "sys::Obj")
    {
      return Obj:Obj[:]
    }

    // dict -> obj
    if (slot.type.qname == "sys::Dict")
    {
      return Obj:Obj["type": "object"]
    }

    // list -> array
    if (slot.type.isList())
    {
      res := Obj:Obj["type": "array"]
      of := slot.of(false)
      if (of != null)
        res["items"] = typeRef(of)
      return res
    }

    // anything else
    return typeRef(slot.type)
  }

  private Obj:Obj typeRef(Spec type)
  {
    // recursively ensure that everything is defined.
    doSpec(type)

    // create a typeref
    nameVer := libNameVer(type.lib)
    return ["\$ref": "#/$refPath/$nameVer/$type.name"]
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  static const Str:[Obj:Obj] primitives := [
    "sys::Str":   ["type": "string"],
    "sys::Bool":  ["type": "boolean"],
    "sys::Int":   ["type": "integer"],
    "sys::Float": ["type": "number"],
  ]

  // qnames that have already been defined
  private Str:Marker defined := Str:Marker[:]

  private const Str refPath

  private Obj:Obj map := [:] { ordered = true }

  Obj:[Obj:Obj] defs := [:] { ordered = true }
}
