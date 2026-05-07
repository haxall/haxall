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
