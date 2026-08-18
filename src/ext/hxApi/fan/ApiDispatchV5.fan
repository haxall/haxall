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
    return mapJsonArgs(args)
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
  ** until a spec says otherwise.  An op declaring a single file typed param
  ** instead receives the raw body spooled to a temp file, making upload the
  ** mirror of the file download in `ApiDispatch.writeRes`.
  override Obj?[] readReqPost()
  {
    // a file typed param receives the post body itself
    p := fileParam
    if (p != null) return [readReqFile(p)]

    // an op whose params all default may be posted with no body at all
    body := req.in.readAllStr
    args := body.isSpace ? Str:Str[:] : splitBody(body)
    return mapJsonArgs(args)
  }

  ** Spool the post body to a temp file for a file typed param.  The
  ** extension comes from the param type's fileExts meta so name sensitive
  ** loaders see the right type; the base name is meaningless.  Registered
  ** as `uploadFile` for the pipeline to delete after dispatch.
  private File readReqFile(Spec p)
  {
    ext := (p.type.meta["fileExts"] as Str)?.split?.first ?: "bin"
    ts := DateTime.now.toLocale("YYMMDD-hhmmss")
    rand := Buf.random(4).toHex
    file := Env.cur.tempDir + `api-upload-${ts}-${rand}.${ext}`
    out := file.out
    try
      req.in.pipe(out, null, false)
    finally
      out.close
    this.uploadFile = file
    return file
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

  ** Decode each named arg against its own param spec
  private Obj?[] mapJsonArgs(Str:Str args)
  {
    mapArgs |p->Obj?|
    {
      json := args[p.name]
      return json == null ? null : decodeArg(p, json)
    }
  }

  ** Decode one arg's JSON text against its declared param spec
  private Obj? decodeArg(Spec p, Str json)
  {
    try
      return cx.ns.io.readJeto(json.in, p)
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
    cx.ns.io.writeJeto(out, result)
    out.close
  }
}

