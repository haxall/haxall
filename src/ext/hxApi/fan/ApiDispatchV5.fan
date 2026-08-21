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

  override ApiVersion version() { ApiVersion.v5 }

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
      if (!ApiUtil.isControlParam(name)) args[name] = toJson(val)
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

  ** Read POST body args.  The named args formats - bare json and the
  ** xeto family - carry one object whose members are the named args; a
  ** haystack grid format carries the request grid exactly as version 4
  ** does.  An op declaring a single file typed param instead receives
  ** the raw body spooled to a temp file, making upload the mirror of
  ** the file download in `ApiDispatch.writeRes`.
  override Obj?[] readReqPost()
  {
    // a file typed param receives the post body itself
    p := ApiUtil.fileParam(func)
    if (p != null) return [readReqFile(p)]

    // resolve filetype per v5 rules: bare application/json is jeto
    filetype := reqFiletype

    // the xeto family carries one object whose members are the named
    // args: jeto as the JSON object and xeto as its xeto rendering
    if (filetype.isXetoIO)
      return filetype.name == "jeto" ? readReqJson : readReqXetoArgs(filetype)

    // a haystack grid format reads a grid: a grid based op receives it
    // whole per opGrid, otherwise the first row demux exactly as v4
    return mapGridArgs(readReqGrid(filetype), ApiUtil.isOpGrid(func))
  }

  ** The json post body is a JSON object whose members are the named args.
  ** Each member is decoded against its own param spec rather than the body
  ** being decoded whole, because JSON alone is lossy: a date is just a
  ** string until a spec says otherwise.
  private Obj?[] readReqJson()
  {
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

  ** A text/xeto body is one dict whose members are the named args - the
  ** xeto rendering of the JSON object.  Members are typed by their
  ** literal syntax; a Str member whose param type is a non-Str scalar
  ** decodes against it, the same rule grid cells use.
  private Obj?[] readReqXetoArgs(Filetype filetype)
  {
    // an op whose params all default may be posted with no body at all
    body := req.in.readAllStr
    args := Etc.dict0
    if (!body.isSpace)
    {
      try
      {
        val := filetype.apiDecode(cx.ns, body.in)
        args = val as Dict ?: throw Err("Expecting Xeto dict of args, not ${val?.typeof}")
      }
      catch (Err e)
        throw ApiErr.invalidArgsErr(filetype.name, e)
    }
    return mapArgs |p->Obj?| { coerceXetoArg(p, args[p.name]) }
  }

  ** Coerce a Str arg whose param type is a non-Str scalar via its binding
  private Obj? coerceXetoArg(Spec p, Obj? val)
  {
    str := val as Str
    if (str == null) return val
    et := p.type
    if (!et.isScalar || et.qname == "sys::Str") return val
    try
      return et.binding.decodeScalar(str, false) ?: throw Err("Invalid '$et.qname' value: $str.toCode")
    catch (Err e)
      throw ApiErr.invalidArgsErrParam(p.name, e)
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

  ** Write the result per the Accept header.  The named args formats -
  ** bare json and the xeto family - answer the bare result value with no
  ** envelope, so a func which returns nothing answers JSON null (an
  ** empty body for xeto).  A haystack grid format bridges the result
  ** through a grid exactly as version 4 does.  A file result never
  ** reaches here - `ApiDispatch.writeRes` serves it as a download
  ** regardless of version.
  override Void writeResVal(Obj? result)
  {
    // resolve filetype per v5 rules: jeto is default and bare application/json
    filetype := acceptFiletype
    opts := acceptOpts

    // always include version header
    res.headers["Xeto-Version"] = version.token

    // the xeto family answers the bare result value with no envelope;
    // everything else is enveloped as a grid
    if (filetype.isXetoIO)
      writeResBody(filetype, result, opts)
    else
      writeResGrid(filetype, result, opts)
  }

}

