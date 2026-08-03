//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   29 Jul 2026  Brian Frank  Creation
//

using util
using xeto
using haystack
using axon
using hx
using web

**
** ApiDispatchV5 for version 5 xeto protocol
**
class ApiDispatchV5 : ApiDispatch
{
  new make(ApiPipeline p) : super(p) {}

//////////////////////////////////////////////////////////////////////////
// Read Request
//////////////////////////////////////////////////////////////////////////

  ** Each query param is decoded against its declared param spec.  Control
  ** params are reserved for the request itself and never map to a func arg.
  override Obj?[] readReqGet()
  {
    args := Str:Str[:]
    req.uri.query.each |val, name|
    {
      if (!isControlParam(name)) args[name] = toJson(val)
    }
    return mapArgs(args)
  }

  ** A query param is a bare value rather than JSON text so that URLs stay
  ** readable: 'checked=true' not 'checked=%22true%22'.  Scalars are quoted
  ** into a JSON string, which is also how the codec wants every scalar it
  ** decodes against a spec.  A value which is already JSON punctuation is
  ** passed through so lists and dicts can still be expressed.
  private static Str toJson(Str val)
  {
    if (val.isEmpty) return "\"\""
    c := val[0]
    if (c == '[' || c == '{') return val
    return JsonOutStream.writeJsonToStr(val)
  }

  ** The post body is a JSON object whose members are the named args.  Each
  ** member is decoded against its own param spec rather than the body being
  ** decoded whole, because JSON alone is lossy: a date is just a string
  ** until a spec says otherwise.
  override Obj?[] readReqPost()
  {
    // an op whose params all default may be posted with no body at all
    body := req.in.readAllStr
    args := body.isSpace ? Str:Str[:] : splitBody(body)
    return mapArgs(args)
  }

  ** Split the post body into the raw JSON text of each named arg so that
  ** every member can be decoded against its declared param spec
  private Str:Str splitBody(Str body)
  {
    val := null
    try
      val = JsonInStream(body.in).readJson
    catch (Err e)
      throw ApiErr.invalidArgsErr("JSON", e)

    map := val as Str:Obj?
    if (map == null) throw ApiErr.invalidArgsErr("JSON", IOErr("Expecting JSON object, not ${val?.typeof}"))

    acc := Str:Str[:]
    map.each |v, n| { acc[n] = JsonOutStream.writeJsonToStr(v) }
    return acc
  }

  ** Map named args onto the positional list the thunk expects, applying
  ** each param's default when the caller supplied no value.  The default
  ** comes from 'metaOwn' so that meta inherited from the param's type is
  ** not mistaken for one: sys::Ref declares 'val:"x"' as an example which
  ** must never be injected as a caller's missing id.
  private Obj?[] mapArgs(Str:Str args)
  {
    func.func.params.map |p->Obj?|
    {
      json := args[p.name]
      if (json != null) return decodeArg(p, json)
      def := p.metaOwn["val"]
      if (def != null) return def
      if (p.type.isMaybe) return null
      throw ApiErr.invalidArgsErrMissing(func.name, p.name)
    }
  }

  ** Decode one arg's JSON text against its declared param spec
  private Obj? decodeArg(Spec p, Str json)
  {
    try
      return cx.ns.io.readJson(json.in, p)
    catch (Err e)
      throw ApiErr.invalidArgsErrParam(p.name, e)
  }

//////////////////////////////////////////////////////////////////////////
// Write Response
//////////////////////////////////////////////////////////////////////////

  ** Encode the result as JSON using the namespace codec.  Unlike version 4
  ** there is no grid envelope: a func which returns nothing answers JSON
  ** null.  A file result never reaches here - `ApiDispatch.writeRes` serves
  ** it as a download regardless of version.
  override Void writeResVal(Obj? result)
  {
    gzip := acceptGzip(req)

    res.statusCode = 200
    res.headers["Content-Type"] = "application/json"
    res.headers["Cache-Control"] = "no-cache, no-store"
    res.headers["Xeto-Version"] = ApiVersion.v5.token
    if (gzip) res.headers["Content-Encoding"] = "gzip"

    OutStream out := res.out
    if (gzip) out = Zip.gzipOutStream(out)
    cx.ns.io.writeJson(out, result)
    out.close
  }
}

