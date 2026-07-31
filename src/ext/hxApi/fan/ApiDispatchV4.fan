//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   29 Jul 2026  Brian Frank  Creation
//

using xeto
using haystack
using axon
using hx
using web

**
** ApiDispatchV4 for version 4 legacy pre-xeto protocol
**
class ApiDispatchV4 : ApiDispatch
{
  new make(ApiPipeline p) : super(p) {}

//////////////////////////////////////////////////////////////////////////
// Read Request
//////////////////////////////////////////////////////////////////////////

  override Obj?[] readReqGet()
  {
    tags := Str:Obj[:]
    req.uri.query.each |valStr, key|
    {
      if (isControlParam(key)) return
      Obj? val := null
      try
        val = ZincReader(valStr.in).readVal
      catch
        val = valStr
      tags[key] = val
    }
    grid := Etc.makeMapGrid(null, tags)
    return Obj?[grid]
  }

  override Obj?[] readReqPost()
  {
    // find reader to use for MIME type
    mime := MimeType(req.headers["Content-Type"] ?: "", false)
    if (mime == null) throw ApiErr.unsupportedMediaTypeErrMissing

    filetype := Filetype.byMime(mime, false)
    if (filetype == null || !filetype.hasReader) throw ApiErr.unsupportedMediaTypeErrReader(mime.toStr)

    // read content is as string
    reqStr := req.in.readAllStr

    // try to parse
    try
    {
      grid := filetype.reader(reqStr.in, ioOpts(mime)).readGrid
      return [grid]
    }
    catch (Err e)
    {
      throw ApiErr.invalidArgsErr(mime.toStr, e)
    }
  }

//////////////////////////////////////////////////////////////////////////
// Call
//////////////////////////////////////////////////////////////////////////

  ** Version 4 reports a failure raised by the op function itself as a 200
  ** response with an error grid.  This is the legacy wire contract:
  ** haystack::Client parses the grid to raise CallErr, so a real status
  ** code here would surface as IOErr instead.  ApiErr is a failure in the
  ** HTTP processing which never reached the function, so it is rethrown to
  ** be reported by ApiPipeline.writeErr with its status code.
  override Obj? call(Obj?[] args)
  {
    try
      return super.call(args)
    catch (ApiErr e)
      throw e
    catch (Err e)
      pipeline.writeErrGrid(e)
    return null
  }

//////////////////////////////////////////////////////////////////////////
// Write Response
//////////////////////////////////////////////////////////////////////////

  override Void writeRes(Obj? result)
  {
    // a func with no result encodes as the empty grid v4 clients expect;
    // Etc.toGrid would otherwise make a single row with a null val col
    grid := result == null ? Etc.emptyGrid : Etc.toGrid(result)

    // parse Accept header to find requested mime type
    mime := acceptMimeType(req, mimeZinc)
    if (mime == null) throw ApiErr.notAcceptableErrHeader

    // find GridWriter to use for mime type
    filetype := Filetype.byMime(mime, false)
    if (filetype == null || !filetype.hasWriter) throw ApiErr.notAcceptableErrWriter(mime.toStr)

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
    filetype.writer(out, ioOpts(mime)).writeGrid(grid)
    out.close
  }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  private static Dict ioOpts(MimeType mime)
  {
    // JSON v3 is only reachable via an explicit ";version=3" mime param
    mime.params["version"] == "3" ? Etc.dict1("v3", Marker.val) : Etc.dict0
  }

}

