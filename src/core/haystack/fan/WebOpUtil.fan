//
// Copyright (c) 2017, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   28 Feb 2017  Brian Frank  Creation
//   27 Jul 2026  Brian Frank  Remove defs/Filetype dependency
//

using web
using xeto

**
** WebOpUtil implements the standard logic for reading requests and
** writing responses for legacy Haystack ops using HTTP content negotiation.
** It is used only for Haystack API when `Xeto-Version` is undefined or
** less than "5".
**
** Only the four Haystack grid formats are supported: zinc, trio, json,
** and csv.  Formats such as pdf/svg/excel are export-only and never
** flow thru this API.
**
@NoDoc const mixin WebOpUtil
{

//////////////////////////////////////////////////////////////////////////
// Request
//////////////////////////////////////////////////////////////////////////

  ** Read a Haystack request grid as GET query params or POST body.
  ** If there is any errors then send HTTP error code and return null
  Grid? doReadReq(WebReq req, WebRes res)
  {
    if (req.isGet) return doReadReqGet(req, res)
    if (req.isPost) return doReadReqPost(req, res)
    res.sendErr(501, "$req.method.upper")
    return null
  }

  private Grid? doReadReqGet(WebReq req, WebRes res)
  {
    tags := Str:Obj[:]
    req.uri.query.each |valStr, key|
    {
      Obj? val := null
      try
        val = ZincReader(valStr.in).readVal
      catch
        val = valStr
      tags[key] = val
    }
    return Etc.makeMapGrid(null, tags)
  }

  private Grid? doReadReqPost(WebReq req, WebRes res)
  {
    // find reader to use for MIME type
    mime := MimeType(req.headers["Content-Type"] ?: "", false)
    if (mime == null) { res.sendErr(415, "Content-Type not specified"); return null }

    filetype := Filetype.byMime(mime, false)
    if (filetype == null || !filetype.hasReader) { res.sendErr(415, "Unsupported Content-Type: $mime"); return null }

    // read content is as string
    reqStr := req.in.readAllStr

    // try to parse
    Err? err := null
    try
    {
      return filetype.reader(reqStr.in, ioOpts(mime)).readGrid
    }
    catch (Err e)
    {
      err = e
    }

    echo("ERROR: Invalid $mime format for request:\n$err\n$reqStr")
    res.sendErr(400, "Cannot parse $mime request: $err")
    return null
  }

//////////////////////////////////////////////////////////////////////////
// Response
//////////////////////////////////////////////////////////////////////////

  ** Write a Haystack response grid using content negotiation.
  Void doWriteRes(WebReq req, WebRes res, Grid result)
  {
    // parse Accept header to find requested mime type
    mime := acceptMimeType(req)
    if (mime == null) return res.sendErr(406, "Invalid Accept header")

    // find GridWriter to use for mime type
    filetype := Filetype.byMime(mime, false)
    if (filetype == null || !filetype.hasWriter) return res.sendErr(406, "Unsupported Accept type: $mime")

    // accept-encoding
    gzip := acceptGzip(req)

    // standard headers
    res.statusCode = 200
    res.headers["Content-Type"] = mime.toStr
    res.headers["Cache-Control"] = "no-cache, no-store"
    if (gzip) res.headers["Content-Encoding"] = "gzip"

    // write result
    OutStream out := res.out
    if (gzip) out = Zip.gzipOutStream(out)
    filetype.writer(out, ioOpts(mime)).writeGrid(result)
    out.close
  }

  ** Does the request accept gzip
  static Bool acceptGzip(WebReq req)
  {
    (req.headers["Accept-Encoding"] ?: "").contains("gzip")
  }

  private MimeType? acceptMimeType(WebReq req)
  {
    // check for filetype in query string for easy testing
    queryFiletype := req.uri.query["filetype"] ?: req.uri.query["format"]
    if (queryFiletype != null) return Filetype.byName(queryFiletype).mimeType

    // if not specified or anything accepted default to text/plain (Zinc)
    accept := req.headers["Accept"]
    if (accept == null || accept.contains("*/*")) return mimeZinc

    // parse first mime type
    toks := accept.split(',')
    mime := MimeType.fromStr(toks.first, false)
    if (mime == null) return null
    return mime
  }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  ** JSON v3 is only reachable via an explicit ";version=3" mime param
  private static Dict ioOpts(MimeType mime)
  {
    mime.params["version"] == "3" ? Etc.dict1("v3", Marker.val) : Etc.dict0
  }

  private static const MimeType mimeZinc := MimeType("text/zinc; charset=utf-8")
}

