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
** OpenApi Exporter
**
@Js
class OpenApiExporter : Exporter
{

//////////////////////////////////////////////////////////////////////////
// Constructor
//////////////////////////////////////////////////////////////////////////

  new make(MNamespace ns, OutStream out, Dict opts) : super(ns, out, opts)
  {
    schemaExporter = JsonSchemaExporter(ns, out, opts, "components/schemas", false)

    errRef = schemaExporter.ensureRef(ns.spec("sys::Err"))

    map["openapi"] = "3.1.0"
    map["jsonSchemaDialect"] = JsonSchemaExporter.dialect
    sysVer := ns.sysLib.version

    map["info"] = [
      "title": opts["title"] as Str ?: "Xeto API",
      "version": opts["version"] as Str ?: sysVer.toStr,
      "description": boxDoctrine,
      "x-xeto-box": "none",
      "x-xeto-libs": ns.versions.map |v->Obj| {
        Obj:Obj["name": v.name, "version": v.version.toStr]
      },
    ]
    map["paths"] = paths
    map["components"] = [
      "schemas": schemaExporter.defs,
      "parameters": [
        "projName": [
          "name": "projName",
          "in": "path",
          "required": true,
          "schema": [
            "type": "string",
          ]
        ],
        "xetoVersion": [
          "name": "Xeto-Version",
          "in": "header",
          "required": true,
          // single-element enum, not const: openapi-python-client
          // rejects const in header params even with an explicit type
          "schema": [
            "type": "string",
            "enum": [sysVer.major.toStr],
          ]
        ]
      ]
    ]
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
    if (spec.type.qname == "sys::Funcs")
    {
      slots := spec.slots()
      slots.each |slot| { doFunc(slot) }
    }
    else if (spec.isFunc)
    {
      doFunc(spec)
    }
  }

  private Void doFunc(Spec spec)
  {
    if (!isOp(spec)) return
    checkCollision(spec)

    uri := "/api/{projName}/" + spec.func.qname

    // request body: a file typed param receives the raw body per the
    // dispatcher's upload contract, everything else is the JSON args object
    [Obj:Obj]? requestBody
    props := Str:Obj[:]
    fileParam := toFileParam(spec)
    if (fileParam != null)
    {
      requestBody = [
        "required": true,
        "content": binarySchema(fileParam.type)
      ]
    }
    else
    {
      reqSchema := schemaExporter.funcToParams(spec)
      props = (Str:Obj)reqSchema["properties"]
      requestBody = [
        "required": true,
        "content": jsonSchema(reqSchema)
      ]
    }

    // response
    response := Obj:Obj[:]
    returns := spec.slot("returns", false)
    if (returns != null)
    {
      // Jeto encodes a None return as JSON null, not the "∅" slot sentinel
      if (returns.type.isNone)
        response = Obj:Obj["type": "null"]
      else
        response = schemaExporter.prop(returns)
      // the response body has no key to omit, so a maybe return really can
      // answer JSON null -- ApiDispatchV5 writes it literally
      if (returns.isMaybe)
        response = schemaExporter.nullable(response)
    }

    // a file return is served as a raw download with the file's own mime
    resContent := spec.func.isFileReturn
      ? binarySchema(returns.type)
      : jsonSchema(response)

    // responses
    responses := Obj:Obj[:] { ordered = true }
    responses["200"] = [
      "description": "Success",
      "content": resContent
    ]
    errResponses.each |pair|
    {
      responses[pair[0]] = [
        "description": pair[1],
        "content": jsonSchema(errRef)
      ]
    }

    // path
    path := Obj:Obj[:] { ordered = true }
    doc := spec.metaOwn["doc"]
    if (doc != null)
      path["description"] = doc

    // GET
    if (fileParam == null && props.isEmpty && spec.meta.has("noSideEffects"))
      path["get"] =  [
        "operationId": spec.name,
        "responses": responses,
        "parameters": opParams,
      ]
    // POST
    else
      path["post"] =  [
        "operationId": spec.name,
        "requestBody": requestBody,
        "responses": responses,
        "parameters": opParams,
      ]

    // done
    paths[uri] = path
  }

  ** Is this func part of the published surface?
  **
  ** <op> is an audience marker -- func-as-operation vs func-as-vocabulary --
  ** and never a security boundary.  Every func remains callable over HTTP
  ** whether or not it is documented here; permissions are a separate axis.
  ** Without the filter a real project's doc is mostly Axon vocabulary.
  **
  ** Lib-level <op> is additive sugar marking every func in the lib.  nodoc
  ** excludes unconditionally, independent of <op>.
  private static Bool isOp(Spec spec)
  {
    if (spec.meta.has("nodoc")) return false
    if (spec.meta.has("op")) return true
    return spec.lib.meta.has("op")
  }

  ** The published surface is addressed by unqualified name in Axon, so two
  ** libs contributing the same <op> name is a generator error rather than a
  ** silent last-wins.
  private Void checkCollision(Spec spec)
  {
    dup := opNames[spec.name]
    if (dup != null)
      throw Err("Duplicate <op> name '$spec.name': $dup.qname and $spec.qname -- alias or exclude one")
    opNames[spec.name] = spec
  }

  ** Params every operation carries.  Returns a fresh list each call so
  ** nothing downstream mutates a shared map.
  private static Obj[] opParams()
  {
    return [
      Obj:Obj["\$ref": "#/components/parameters/projName"],
      Obj:Obj["\$ref": "#/components/parameters/xetoVersion"],
    ]
  }

  private static Obj:Obj jsonSchema(Obj:Obj schema)
  {
    return [
      "application/json": [
        "schema": schema
      ]
    ]
  }

  ** File typed param which receives the raw request body, or null when
  ** the op takes JSON args.  Mirrors the dispatcher's upload contract:
  ** the file must be the op's only param.
  private static Spec? toFileParam(Spec spec)
  {
    spec.func.isFileParam ? spec.func.params.first : null
  }

  ** Raw binary content keyed by the file spec's own mime type
  private static Obj:Obj binarySchema(Spec fileType)
  {
    mime := fileType.meta["mimeType"] as Str ?: "application/octet-stream"
    return [
      mime: [
        "schema": ["type": "string", "format": "binary"]
      ]
    ]
  }

  ** Schemas describe the unboxed wire; see doc.xeto::HttpApi box modes
  private static const Str boxDoctrine :=
    "Schemas describe the box=none wire encoding. Clients validating or " +
    "generating code from this document should request responses with " +
    "Accept: application/json;box=none"

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  ** Stamped on every operation, all carrying the sys::Err dict.  Keys are
  ** plain "400", not the old "'400'" -- the quotes were a workaround for
  ** YAML coercing a bare numeric key to an int, but they landed as literal
  ** apostrophes in both writers.  JSON is now correct; a YAML consumer still
  ** sees an int key until YamlWriter learns to quote numeric strings.
  ** List of pairs, not a map: Map.ordered can only be set while the map is
  ** empty, and output order here must be stable.
  private static const Str[][] errResponses := [
    ["400", "Bad Request"],
    ["401", "Unauthorized"],
    ["403", "Forbidden"],
    ["404", "Not Found"],
    ["500", "Internal Server Error"],
  ]

  private JsonSchemaExporter schemaExporter
  private Obj:Obj errRef

  private Obj:Obj map := [:] { ordered = true }
  Obj:Obj paths := [:] { ordered = true }

  // published <op> simple names, for collision detection
  private Str:Spec opNames := Str:Spec[:]
}
