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

    if (opts->format == "json")
    {
      js := JsonOutStream(Env.cur.out)
      js.prettyPrint = true
      js.writeJson(map)
    }
    else if (opts->format == "yaml")
    {
      ym := YamlWriter(Env.cur.out)
      ym.writeYaml(map)
    }
    else
    {
      throw Err("${opts->format} is an invalid output format")
    }

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

    doc := spec.metaOwn["doc"]

    if (spec.isScalar)
      doSpecScalar(spec, doc)
    else if (spec.isGrid)
      doSpecGrid(spec, doc)
    else
      doSpecObj(spec, doc)
  }

  private Bool alreadyDefined(Spec spec)
  {
    if (defined.containsKey(spec.qname))
      return true
    defined[spec.qname] = Marker.val
    return false
  }

  private Void doSpecScalar(Spec spec, Str? doc)
  {
    if (spec.isEnum)
    {
      addDef(spec, doc, [
        "type": "string",
        "enum": spec.enum.keys
      ])
    }
    else
    {
      prim := primitives.getChecked(spec.qname, false)
      if (prim != null) return prim

      pattern := spec.meta["pattern"]
      if (pattern == null)
      {
        addDef(spec, doc, prim ?: [
          "type": "string",
        ])
      }
      else
      {
        addDef(spec, doc, prim ?: [
          "type": "string",
          "pattern": ((Str)pattern)
            .replace("\\", "\\\\")
            .replace("\"", "\\\"")
        ])
      }
    }
  }

  private Void doSpecObj(Spec spec, Str? doc)
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
          allOf.add(ensureRef(of))
        }
        addDef(spec, doc, [ "allOf": allOf ])
      }
      else
      {
        if (type.base.qname == "sys::Dict")
        {
          addDef(spec, doc, schema)
        }
        else
        {
          addDef(
            spec, doc, [
              "allOf": [
                ensureRef(type.base),
                schema
              ]
            ])
        }
      }
    }
  }

  private Void doSpecGrid(Spec spec, Str? doc)
  {
    addDef(
      spec, doc,
      [
        "additionalProperties": true,
        "type": "object",
        "properties": [
          "meta": [
            "type": "object"
          ],
          "rows": [
            "type": "array",
            "items": [
              "type": "object"
            ]
          ],
          "cols": [
            "type": "array",
            "items": ref(spec.lib, "GridCol")
          ]
        ],
        "required": [
          "cols",
          "rows"
        ]
      ])

    addDef(
      spec, null,
      [
        "type": "object",
        "properties": [
          "meta": [
            "type": "object"
          ],
          "name": [
            "type": "string"
          ]
        ],
        "required": [
          "name"
        ]
      ],
      "GridCol" /* synthetic name */)
  }

  Obj:Obj prop(Spec slot)
  {
    // primitives
    prim := primitives.getChecked(slot.type.qname, false)
    if (prim != null) return prim

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
        res["items"] = ensureRef(of)
      return res
    }

    // anything else
    return ensureRef(slot.type)
  }

  private Void addDef(Spec spec, Str? doc, Obj:Obj schema, Str? syntheticName := null)
  {
    if (doc != null)
      schema["description"] = doc

    libName := libNameVer(spec.lib)
    specName := syntheticName ?: spec.name
    defs["$libName-$specName"] = schema
  }

  Obj:Obj ensureRef(Spec type)
  {
    // recursively ensure that the type is defined
    doSpec(type)

    return ref(type.lib, type.name)
  }

  private Obj:Obj ref(Lib lib, Str specName)
  {
    libName := libNameVer(lib)
    return ["\$ref": "#/$refPath/$libName-$specName"]
  }

  private static Str libNameVer(Lib lib)
  {
     return "${lib.name}-${lib.version}".replace(".", "-")
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

  Obj:Obj defs := [:] { ordered = true }
}
