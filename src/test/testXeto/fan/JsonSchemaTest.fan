//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   7 May 2026  Mike Jarmy  Creation
//

using util
using xeto
using xetom
using haystack

**
** JsonSchemaTest
**
@Js
class JsonSchemaTest : AbstractXetoTest
{

  Void testFuncToParams()
  {
    ns := createNamespace(["sys", "hx", "hx.math"])
    sysVer := ns.lib("sys").version.toStr.replace(".", "-")
    sysNumberRef := Obj:Obj["\$ref": "#/\$defs/sys-${sysVer}-Number"]
    sysRefRef    := Obj:Obj["\$ref": "#/\$defs/sys-${sysVer}-Ref"]

    mathFuncs := ns.lib("hx.math").spec("Funcs")
    hxFuncs   := ns.lib("hx").spec("Funcs")

    // pi: Func { returns: Number }
    ex := JsonSchemaExporter(ns, Buf().out, Etc.dict0)
    actual := ex.funcToParams(mathFuncs.slot("pi"))
    verifyEq(actual, Str:Obj[
      "type": "object",
      "properties": Str:Obj[:],
    ])
    verifyAllRefsResolved(actual, ex.defs)

    // remainder: Func { a: Number, b: Number, returns: Number }
    ex = JsonSchemaExporter(ns, Buf().out, Etc.dict0)
    actual = ex.funcToParams(mathFuncs.slot("remainder"))
    verifyEq(actual, Str:Obj[
      "type": "object",
      "properties": Str:Obj[
        "a": sysNumberRef,
        "b": sysNumberRef,
      ],
      "required": Obj["a", "b"],
    ])
    verifyAllRefsResolved(actual, ex.defs)

    // random: Func { range: Obj?, returns: Number }
    ex = JsonSchemaExporter(ns, Buf().out, Etc.dict0)
    actual = ex.funcToParams(mathFuncs.slot("random"))
    verifyEq(actual, Str:Obj[
      "type": "object",
      "properties": Str:Obj[
        "range": Obj:Obj[:],
      ],
    ])
    verifyAllRefsResolved(actual, ex.defs)

    // readByIds: Func { ids: List <of:Ref>, checked: Bool, returns: Grid }
    ex = JsonSchemaExporter(ns, Buf().out, Etc.dict0)
    actual = ex.funcToParams(hxFuncs.slot("readByIds"))
    verifyEq(actual, Str:Obj[
      "type": "object",
      "properties": Str:Obj[
        "ids": Obj:Obj["type": "array", "items": sysRefRef],
        "checked": Obj:Obj["type": "boolean"],
      ],
      "required": Obj["ids", "checked"],
    ])
    verifyAllRefsResolved(actual, ex.defs)

    // error: not a func
    ex = JsonSchemaExporter(ns, Buf().out, Etc.dict0)
    verifyErr(ArgErr#) { ex.funcToParams(ns.spec("sys::Dict")) }
  }

  Void testSlotDescriptions()
  {
    ns := createNamespace(["sys"])
    sysVer := ns.lib("sys").version.toStr.replace(".", "-")
    sysNumberRef := Obj:Obj["\$ref": "#/\$defs/sys-${sysVer}-Number"]

    // a temp lib with a Func whose params carry slot-level <doc:"..."> meta,
    // plus an object spec whose own slots carry <doc:"...">.  exercises both
    // funcToParams and the doSpecObj slot-prop path through prop().
    src :=
      Str<|Divide: Func {
             a: sys::Number <doc:"the dividend">,
             b: sys::Number <doc:"the divisor">,
             returns: sys::Number
           }
           Mix: Func {
             label: sys::Str <doc:"display label">,
             enabled: sys::Bool <doc:"whether the mix is enabled">,
             count: sys::Int,
             sample: sys::Obj? <doc:"opaque sample value">,
             ids: List <of:sys::Ref, doc:"list of refs to mix in">,
             returns: sys::Number
           }
           Person: {
             name: sys::Str <doc:"full name">,
             age: sys::Number <doc:"age in years">,
             pet: sys::Number? <doc:"pet's age in years">
           }|>

    lib := ns.compileTempLib(src)

    //
    // funcToParams: every documented slot picks up "description"; refs
    // get wrapped in allOf so description survives draft-07 sibling
    // ignore rules; primitives carry description as a direct sibling.
    //
    ex := JsonSchemaExporter(ns, Buf().out, Etc.dict0)
    actual := ex.funcToParams(lib.type("Divide"))
    verifyEq(actual, Str:Obj[
      "type": "object",
      "properties": Str:Obj[
        "a": Obj:Obj["allOf": Obj[sysNumberRef], "description": "the dividend"],
        "b": Obj:Obj["allOf": Obj[sysNumberRef], "description": "the divisor"],
      ],
      "required": Obj["a", "b"],
    ])
    verifyAllRefsResolved(actual, ex.defs)

    // mixed: primitives get direct description; ref + list each get the
    // appropriate shape; sample (sys::Obj?) gets description on an empty
    // schema; count has no doc and stays bare.
    ex = JsonSchemaExporter(ns, Buf().out, Etc.dict0)
    actual = ex.funcToParams(lib.type("Mix"))
    verifyEq(actual, Str:Obj[
      "type": "object",
      "properties": Str:Obj[
        "label":   Obj:Obj["type": "string", "description": "display label"],
        "enabled": Obj:Obj["type": "boolean", "description": "whether the mix is enabled"],
        "count":   Obj:Obj["type": "integer"],            // no doc
        "sample":  Obj:Obj["description": "opaque sample value"],
        "ids":     Obj:Obj[
          "type": "array",
          "items": Obj:Obj["\$ref": "#/\$defs/sys-${sysVer}-Ref"],
          "description": "list of refs to mix in",
        ],
      ],
      "required": Obj["label", "enabled", "count", "ids"],
    ])
    verifyAllRefsResolved(actual, ex.defs)

    //
    // doSpecObj: same prop() path as funcToParams, so slot docs surface
    // as descriptions in the generated def.  spot-check the def for
    // Person -- "name", "age" land as documented props; "pet" is a
    // documented ref-shaped slot wrapped in allOf.
    //
    ex = JsonSchemaExporter(ns, Buf().out, Etc.dict0)
    ex.spec(lib.type("Person"))
    libVer := lib.version.toStr.replace(".", "-")
    personDef := (Obj:Obj)ex.defs["${lib.name}-${libVer}-Person"]
    personProps := (Obj:Obj)personDef["properties"]
    verifyEq(personProps["name"],
      Obj:Obj["type": "string", "description": "full name"])
    verifyEq(personProps["age"],
      Obj:Obj["allOf": Obj[sysNumberRef], "description": "age in years"])
    verifyEq(personProps["pet"],
      Obj:Obj["allOf": Obj[sysNumberRef], "description": "pet's age in years"])
    verifyAllRefsResolved(personDef, ex.defs)
  }

  private Void verifyAllRefsResolved(Obj? val, Str:Obj defs)
  {
    if (val is Map)
    {
      ((Map)val).each |v, k|
      {
        if (k == "\$ref")
        {
          prefix := "#/\$defs/"
          ref := (Str)v
          verifyEq(ref.startsWith(prefix), true)
          defKey := ref[prefix.size..-1]
          verify(defs.containsKey(defKey), "missing def: $defKey")
        }
        else
        {
          verifyAllRefsResolved(v, defs)
        }
      }
    }
    else if (val is List)
    {
      ((List)val).each |v| { verifyAllRefsResolved(v, defs) }
    }
  }
}
