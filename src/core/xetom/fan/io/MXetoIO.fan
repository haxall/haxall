//
// Copyright (c) 2026, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   7 Jan 2026  Brian Frank  Creation
//

using xeto
using haystack

**
** Implementation for XetoIO
**
@Js
const final class MXetoIO : XetoIO
{
  new make(MNamespace ns) { this.ns = ns }

  const MNamespace ns

//////////////////////////////////////////////////////////////////////////
// Xeto
//////////////////////////////////////////////////////////////////////////

  override Obj? readXeto(Str in, Dict? opts := null)
  {
    ns.envRef.readData(ns, in, opts ?: Etc.dict0)
  }

  override Dict[]  readXetoDicts(Str in, Dict? opts := null)
  {
    val := readXeto(in, opts)
    if (val is List) return ((List)val).map |x->Dict| { x as Dict ?: throw IOErr("Expecting Xeto list of dicts, not ${x?.typeof}") }
    if (val is Dict) return Dict[val]
    throw IOErr("Expecting Xeto dict data, not ${val?.typeof}")
  }

  override OutStream writeXeto(OutStream out, Obj? val, Dict? opts := null)
  {
    XetoPrinter(ns, out, opts ?: Etc.dict0).data(val)
    return out
  }

  override Str writeXetoToStr(Obj? val, Dict? opts := null)
  {
    buf := StrBuf(256)
    writeXeto(buf.out, val)
    return buf.toStr
  }

//////////////////////////////////////////////////////////////////////////
// JSON
//////////////////////////////////////////////////////////////////////////

  override Obj? readJson(InStream in, Spec? spec := null, Dict? opts := null)
  {
    try
      //return XetoJsonReader(ns, in, opts ?: Etc.dict0).readVal
      throw Err("TODO")
    finally
      in.close
  }

  override OutStream writeJson(OutStream out, Obj? val, Dict? opts := null)
  {
    XetoJsonWriter(out, opts ?: Etc.dict0).writeVal(val)
    return out
  }

  override Str writeJsonToStr(Obj? val, Dict? opts := null)
  {
    buf := StrBuf(256)
    writeJson(buf.out, val, opts)
    return buf.toStr
  }

//////////////////////////////////////////////////////////////////////////
// AST
//////////////////////////////////////////////////////////////////////////

  override Dict readAst(Str in, Dict? opts := null)
  {
    ns.envRef.readAst(ns, in, opts ?: Etc.dict0)
  }

  override OutStream writeAst(OutStream out, Dict ast, Dict? opts := null)
  {
    XetoPrinter(ns, out, opts).ast(ast)
    return out
  }

  override Str writeAstToStr(Dict ast, Dict? opts := null)
  {
    buf := StrBuf(256)
    writeAst(buf.out, ast, opts)
    return buf.toStr
  }

  override Dict readAxon(Str in, Dict funcMeta, Dict? opts := null)
  {
    throw Err("TODO")
  }

  override OutStream writeAxon(OutStream out, Dict ast, Dict? opts := null)
  {
    throw Err("TODO")
  }

  override Str writeAxonToStr(Dict ast, Dict? opts := null)
  {
    buf := StrBuf(256)
    writeAxon(buf.out, ast, opts)
    return buf.toStr
  }

//////////////////////////////////////////////////////////////////////////
// Binary
//////////////////////////////////////////////////////////////////////////

  override Obj? readBinary(InStream in, Dict? opts := null)
  {
    try
      return XetoBinaryReader(in).readVal
    finally
      in.close
  }

  override OutStream writeBinary(OutStream out, Obj? val, Dict? opts := null)
  {
    XetoBinaryWriter(out).writeVal(val)
    return out
  }

//////////////////////////////////////////////////////////////////////////
// Print
//////////////////////////////////////////////////////////////////////////

  override Void print(Obj? val, OutStream out := Env.cur.out, Dict? opts := null)
  {
    Printer(ns, out, opts ?: Etc.dict0).print(val)
  }
}

