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
** This class does not write anything to output stream until end.
**
@Js
class JsonSchemaExporter : Exporter
{

//////////////////////////////////////////////////////////////////////////
// Constructor
//////////////////////////////////////////////////////////////////////////

  new make(MNamespace ns, OutStream out, Dict opts := Etc.dict0,
           Str refPath := "\$defs", Bool standalone := true) : super(ns, out, opts)
  {
    this.refPath    = refPath
    this.standalone = standalone

    // $schema is a document-level keyword.  embedded in an OpenAPI doc the
    // root declares jsonSchemaDialect once and the component schemas must
    // not carry their own.
    if (standalone)
      map["\$schema"] = dialect
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

    format := opts["format"] ?: "yaml"
    if (format == "json")
    {
      js := JsonOutStream(out)
      js.prettyPrint = true
      js.writeJson(map)
    }
    else if (format == "yaml")
    {
      ym := YamlWriter(out)
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
    // the one place a version still belongs
    map["\$id"] = "${lib.name}-${lib.version}"

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

  ** Convert a func spec's parameters into a JSON Schema object.
  ** The `returns` slot is skipped. Referenced types are registered in `defs`.
  Str:Obj funcToParams(Spec funcSpec)
  {
    if (!funcSpec.isFunc) throw ArgErr("Not a func: $funcSpec.qname")

    props := Str:Obj[:] { ordered = true }
    required := Obj[,]

    funcSpec.slots.each |slot, name|
    {
      if (name == "returns") return
      if (!slot.isMaybe) required.add(name)
      props[name] = prop(slot)
    }

    schema := Str:Obj[:] { ordered = true }
    schema["type"] = "object"
    schema["properties"] = props
    if (required.size > 0)
      schema["required"] = required
    return schema
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
      // primitives are inlined at the use site, never given a def
      if (primitives.containsKey(spec.qname)) return

      pattern := spec.meta["pattern"]
      if (pattern == null)
      {
        addDef(spec, doc, [
          "type": "string",
        ])
      }
      else
      {
        addDef(spec, doc, [
          "type": "string",
          "pattern": anchor((Str)pattern),
        ])
      }
    }
  }

  ** JSON Schema patterns are not implicitly anchored (2020-12 §6.3.3) but
  ** Xeto patterns are whole-value matches, so anchor centrally.  The pattern
  ** is otherwise passed through verbatim -- both writers escape on their own.
  private static Str anchor(Str pattern) { "^(?:" + pattern + ")\$" }

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
    res := propSchema(slot)

    // attach the slot's own doc as description.  in 2020-12 $ref is an
    // ordinary keyword whose siblings apply, so every shape takes the
    // same path.
    doc := slot.metaOwn["doc"] as Str
    if (doc != null)
    {
      // .rw: propSchema may hand back a shared immutable map from primitives
      res = res.rw
      res["description"] = doc
    }

    // no "spec" here -- a $ref already names the type, and an inline type
    // is fully expressed by its own keywords
    return xeto(res, slot, false)
  }

  ** Widen a schema to also admit JSON null.
  **
  ** Only for positions that have no key to omit -- a func return body, or
  ** list items.  A maybe dict slot is NOT nullable: Xeto "Foo?" means the
  ** slot may be absent, and null is unrepresentable in a Dict, so omitting
  ** it from "required" already says everything there is to say.
  Obj:Obj nullable(Obj:Obj schema)
  {
    // an unconstrained schema already admits null.  description alone
    // constrains nothing, and "returns: Obj?" is far and away the common
    // case, so this keeps anyOf noise out of most of the surface.
    if (schema.keys.all |k| { k == "description" }) return schema

    // a lone type widens in place
    type := schema["type"]
    if (type is Str)
    {
      schema = schema.rw
      schema["type"] = Obj[(Str)type, "null"]
      return schema
    }

    // otherwise wrap -- $ref-shaped and multi-branch schemas.  hoist any
    // description so it stays on the node consumers render.
    desc := schema["description"]
    if (desc != null)
    {
      schema = schema.rw
      schema.remove("description")
    }
    res := Obj:Obj[:] { ordered = true }
    res["anyOf"] = Obj[schema, Obj:Obj["type": "null"]]
    if (desc != null) res["description"] = desc
    return res
  }

  ** Stamp x-xeto annotations from the spec's own meta.  Returns schema for
  ** chaining; no-op when there is nothing to add.
  **
  ** Carries the Xeto type information JSON Schema cannot express, alongside
  ** the lossy approximation of the same node.  Meta with a faithful keyword
  ** equivalent goes to that keyword and never appears here, so there is no
  ** ambiguity about which copy is authoritative.  This is a documentation
  ** projection, not a round-trippable encoding -- consumers needing full
  ** fidelity resolve "spec" against the server.
  private Obj:Obj xeto(Obj:Obj schema, Spec spec, Bool withSpec := true)
  {
    meta := spec.metaOwn

    acc := Str:Obj[:]
    xetoMeta.each |name|
    {
      v := meta[name]
      if (v == null) return

      // never duplicate what a standard keyword already carries
      if (name == "of" && schema.containsKey("items")) return

      acc[name] = jsonVal(v)
    }

    // minVal/maxVal are the one conditional entry: a unitless bound is a
    // JSON number and maps to minimum/maximum, but a united bound is not a
    // JSON number and has to spill into x-xeto instead.
    keywords := Str:Obj[:] { ordered = true }
    boundKeywords.each |keyword, name|
    {
      v := meta[name]
      if (v == null) return
      num := v as Number
      if (num != null && num.unit == null)
        keywords[keyword] = numVal(num)
      else
        acc[name] = jsonVal(v)
    }

    if (acc.isEmpty && keywords.isEmpty && !withSpec) return schema

    schema = schema.rw
    keywords.each |v, k| { schema[k] = v }

    // spec first, then meta alphabetically
    if (withSpec || !acc.isEmpty)
    {
      x := Str:Obj[:] { ordered = true }
      if (withSpec) x["spec"] = spec.qname
      acc.keys.sort.each |k| { x[k] = acc.getChecked(k) }
      schema["x-xeto"] = x
    }
    return schema
  }

  ** Clean JSON projection of a meta value: markers are true, spec
  ** references are bare qname strings, lists stay lists.
  **
  ** "of" and "ofs" are declared Ref<of:Spec> rather than Spec, and Ref.toStr
  ** is the bare qname, so they land on the trailing toStr.
  private static Obj jsonVal(Obj v)
  {
    if (v is Marker) return true
    if (v is Spec)   return ((Spec)v).qname
    if (v is List)   return ((List)v).map |x->Obj| { jsonVal(x) }
    if (v is Str || v is Bool || v is Int || v is Float) return v
    return v.toStr
  }

  ** Integral numbers emit as JSON integers, matching XetoJsonWriter
  private static Obj numVal(Number n)
  {
    f := n.toFloat
    return f.toInt.toFloat == f ? (Obj)f.toInt : (Obj)f
  }

  private Obj:Obj propSchema(Spec slot)
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
      {
        // List<of:Foo?> legitimately holds nulls -- Fitter.fitsList only
        // rejects them when the of type is not maybe
        items := ensureRef(of)
        res["items"] = of.isMaybe ? nullable(items) : items
      }
      return res
    }

    // anything else
    return ensureRef(slot.type)
  }

  private Void addDef(Spec spec, Str? doc, Obj:Obj schema, Str? syntheticName := null)
  {
    // .rw: schema may be a shared immutable map from primitives
    if (doc != null)
    {
      schema = schema.rw
      schema["description"] = doc
    }

    // synthetic nodes are not a spec, so they carry no annotation
    if (syntheticName == null)
      schema = xeto(schema, spec)

    specName := syntheticName ?: spec.name
    defs[defName(spec.lib, specName)] = schema
  }

  Obj:Obj ensureRef(Spec type)
  {
    // recursively ensure that the type is defined
    doSpec(type)

    return ref(type.lib, type.name)
  }

  private Obj:Obj ref(Lib lib, Str specName)
  {
    return Obj:Obj["\$ref": "#/$refPath/${defName(lib, specName)}"]
  }

  ** Flat qname key -- "sys.Ref", "ph.Site".  No version stamp: one document
  ** is one namespace and cannot hold two versions of a lib, so versions are
  ** carried once in info/x-xeto-libs.  "." is legal both in an OpenAPI 3.1
  ** component key and in a JSON pointer segment, so it needs no escaping.
  private static Str defName(Lib lib, Str specName)
  {
    return "${lib.name}.${specName}"
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  ** JSON Schema dialect emitted as $schema, and advertised by
  ** OpenApiExporter as the document's jsonSchemaDialect.
  static const Str dialect := "https://json-schema.org/draft/2020-12/schema"

  ** Xeto meta projected into x-xeto.  Tags with a faithful JSON Schema
  ** equivalent map to that keyword instead and are absent here.
  **
  ** Allowlist, not denylist: otherwise every new sys meta tag silently
  ** leaks compiler internals (loc, class, sealed, mixin, noInherit) into a
  ** published API surface.  Cost is an exporter edit per new tag, which is
  ** the right trade for a public surface.  Keep alphabetical.
  static const Str[] xetoMeta := [
    "abstract", "async", "inverse", "multiChoice", "of", "ofs",
    "quantity", "transient", "unit", "unitless", "via",
  ]

  ** Conditional entries -- see xeto()
  private static const Str:Str boundKeywords := [
    "minVal": "minimum",
    "maxVal": "maximum",
  ]

  static const Str:[Obj:Obj] primitives := [
    "sys::Str":   Obj:Obj["type": "string"],
    "sys::Bool":  Obj:Obj["type": "boolean"],
    "sys::Int":   Obj:Obj["type": "integer"],
    "sys::Float": Obj:Obj["type": "number"],
  ]

  // qnames that have already been defined
  private Str:Marker defined := Str:Marker[:]

  private const Str refPath

  // standalone document vs embedded in an OpenAPI doc
  private const Bool standalone

  private Obj:Obj map := [:] { ordered = true }

  Obj:Obj defs := [:] { ordered = true }
}

