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

  override ApiVersion version() { ApiVersion.v4 }

//////////////////////////////////////////////////////////////////////////
// Read Request
//////////////////////////////////////////////////////////////////////////

  override Obj?[] readReqGet()
  {
    tags := Str:Obj[:]
    req.uri.query.each |valStr, key|
    {
      if (ApiUtil.isControlParam(key)) return
      Obj? val := null
      try
        val = ZincReader(valStr.in).readVal
      catch
        val = valStr
      tags[key] = val
    }
    return mapGridArgs(Etc.makeMapGrid(null, tags), takesReqGrid)
  }

  override Obj?[] readReqPost()
  {
    // file typed params are a version 5 feature
    if (ApiUtil.fileParam(func) != null) throw ApiErr(400, "InvalidArgsErr", "File param op requires API version 5: $func.name")

    // every v4 post body is a grid; bare application/json is hayson
    return mapGridArgs(readReqGrid(reqFiletype), takesReqGrid)
  }

  ** Does this op take the whole version 4 request grid as its single
  ** argument?  Version 4 passed the grid to any func invoked as an op no
  ** matter what it declared - `hxApi::ApiPipeline.doResolveOpFunc` resolves
  ** any func in the namespace, not just those marked '<op>'.  So args are
  ** only mapped by name for an '<op>' which has modeled its params; the
  ** grid based ops receive the grid whole per `ApiUtil.isOpGrid`.
  virtual Bool takesReqGrid()
  {
    ApiUtil.takesReqGridV4(func)
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
  **
  ** This applies only when we are the one writing the response body.  An op
  ** which streams its own response, or returns a file for the dispatcher to
  ** serve, has no grid to put the error in: the client would read the err
  ** grid as the bytes it asked for, so the error is rethrown instead.
  override Obj? call(Obj?[] args)
  {
    try
      return super.call(args)
    catch (ApiErr e)
      throw e
    catch (Err e)
    {
      if (!writesGrid) throw e
      pipeline.writeErrGrid(e)
    }
    return null
  }

  ** Will this op's response body be a grid we encode?  Note a func may
  ** declare 'returns: None' and still get a grid: sys.api::close answers
  ** the empty grid.  What matters is whether the func writes the response
  ** itself, which is the '<opWebRes>' marker.
  private Bool writesGrid()
  {
    !pipeline.funcOwnsRes && !func.func.isFileReturn
  }

//////////////////////////////////////////////////////////////////////////
// Write Response
//////////////////////////////////////////////////////////////////////////

  override Void writeResVal(Obj? result)
  {
    // v4 answers every result as a grid; the Accept default is zinc
    // and bare application/json is hayson
    writeResGrid(acceptFiletype, result, acceptOpts)
  }
}

