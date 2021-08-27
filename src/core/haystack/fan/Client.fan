//
// Copyright (c) 2009, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   22 Aug 2009  Brian Frank  Creation
//   30 Mar 2021  Brian Frank  Move back into haystack
//

using concurrent
using inet
using web

**
** Client manages a network connection to a haystack server.
**
class Client
{

//////////////////////////////////////////////////////////////////////////
// Construction
//////////////////////////////////////////////////////////////////////////

  ** Open with URI of project such as "http://host/api/myProj/".
  ** Throw IOErr for network/connection error or 'AuthErr' if
  ** credentials are not authenticated.
  static Client open(Uri uri, Str username, Str password, [Str:Obj]? opts := null)
  {
    // normalize URI
    if (uri.scheme != "http" && uri.scheme != "https") throw ArgErr("Only http/https: URIs supported: $uri")
    uri = uri.plusSlash

    // init options
    log     := opts?.get("log") as Log ?: Log.get("client")
    timeout := opts?.get("timeout", opts?.get("receiveTimeout")) as Duration ?: 1min

    // use reflection to delegate to auth::AuthClientContext
    socketConfig := SocketConfig.cur.setTimeouts(timeout)
    auth := Slot.findMethod("auth::AuthClientContext.open").call(uri+`about`, username, password, log, socketConfig)

    return make(uri, log, auth)
  }

  ** Private constructor
  private new make(Uri uri, Log log, HaystackClientAuth auth)
  {
    this.uri  = uri
    this.log  = log
    this.auth = auth
  }

//////////////////////////////////////////////////////////////////////////
// Identity
//////////////////////////////////////////////////////////////////////////

  ** URI of endpoint such as "http://host/api/myProj/".
  ** This URI always ends in a trailing slash.
  const Uri uri

  ** Return uri.toStr
  override Str toStr() { uri.toStr }

//////////////////////////////////////////////////////////////////////////
// Requests
//////////////////////////////////////////////////////////////////////////

  **
  ** Call "about" operation to query server summary info.
  **
  Dict about()
  {
    call("about", Etc.emptyGrid).first
  }

  **
  ** Call "read" operation to read a record by its identifier.  If the
  ** record is not found then return null or raise UnknownRecException
  ** based on checked flag.  Raise `haystack::CallErr` if server returns error grid.
  ** Also see [Rest API]`docSkySpark::Ops#read`.
  **
  Dict? readById(Obj id, Bool checked := true)
  {
    req := Etc.makeListGrid(null, "id", null, [id])
    res := call("read", req)
    if (!res.isEmpty && res.first.has("id")) return res.first
    if (checked) throw UnknownRecErr(id.toStr)
    return null
  }

  **
  ** Call "read" operation to read a list of records by their identifiers.
  ** Return a grid where each row of the grid maps to the respective
  ** id list (indexes line up).  If checked is true and any one of the
  ** ids cannot be resolved then raise UnknownRecErr for first id not
  ** resolved.  If checked is false, then each id not found has a row
  ** where every cell is null.  Raise `haystack::CallErr` if server returns error
  ** grid.  Also see [Rest API]`docSkySpark::Ops#read`.
  **
  Grid readByIds(Obj[] ids, Bool checked := true)
  {
    req := Etc.makeListGrid(null, "id", null, ids)
    res := call("read", req)
    if (checked) res.each |r, i| { if (r.missing("id")) throw UnknownRecErr(ids[i].toStr) }
    return res
  }

  **
  ** Call "read" operation to read a record that matches the given filter.
  ** If there is more than one record, then it is undefined which one is
  ** returned.  If there are no matches then return null or raise
  ** UnknownRecException based on checked flag.  Raise `haystack::CallErr` if server
  ** returns error grid.  Also see [Rest API]`docSkySpark::Ops#read`.
  **
  Dict? read(Str filter, Bool checked := true)
  {
    req := Etc.makeListsGrid(null, ["filter", "limit"], null, [[filter, Number.one]])
    res := call("read", req)
    if (!res.isEmpty) return res.first
    if (checked) throw UnknownRecErr(filter)
    return null
  }

  **
  ** Call "read" operation to read a record all recs which match the
  ** given filter.  Raise `haystack::CallErr` if server returns error grid.
  ** Also see [Rest API]`docSkySpark::Ops#read`.
  **
  Grid readAll(Str filter)
  {
    req := Etc.makeListGrid(null, "filter", null, [filter])
    return call("read", req)
  }

  **
  ** Evaluate an Axon expression and return results as Grid.
  ** Raise `haystack::CallErr` if server returns error grid.
  ** Also see [Rest API]`docSkySpark::Ops#eval`.
  **
  Grid eval(Str expr)
  {
    call("eval", Etc.makeListGrid(null, "expr", null, [expr]))
  }

  **
  ** Evaluate a list of expressions.  The req parameter must be
  ** 'Str[]' of Axon expressions or a correctly formatted `haystack::Grid`
  ** with 'expr' column.
  **
  ** A separate grid is returned for each row in the request.  If checked
  ** is false, then this call does *not* automatically check for error
  ** grids - client code must individual check each grid for partial
  ** failures using `haystack::Grid.isErr`.  If checked is true and one of the
  ** requests failed, then raise `haystack::CallErr` for first failure.
  **
  ** Also see [Rest API]`docSkySpark::Ops#evalAll`.
  **
  ** NOTE: this should be used anymore
  **
  @NoDoc Grid[] evalAll(Obj req, Bool checked := true)
  {
    // construct grid request
    reqGrid := req as Grid
    if (reqGrid == null)
    {
      if (req isnot List) throw ArgErr("Expected Grid or Str[]")
      reqGrid = Etc.makeListGrid(null, "expr", null, req)
    }

    // make request and parse response
    reqStr := gridToStr(reqGrid)
    resStr := doCall("evalAll", reqStr)
    res := ZincReader(resStr.in).readGrids

    // check for errors
    if (checked) res.each |g| { if (g.isErr) throw CallErr(g) }
    return res
  }

  **
  ** Commit a set of diffs.  The req parameter must be a grid
  ** with a "commit" tag in the grid.meta.  The rows are the
  ** items to commit.  Return result as Grid or or raise `haystack::CallErr`
  ** if server returns error grid.
  **
  ** Also see [Rest API]`docSkySpark::Ops#commit`.
  **
  ** Examples:
  **   // add new record
  **   tags := ["site":Marker.val, "dis":"Example Site"])
  **   toCommit := Etc.makeDictGrid(["commit":"add"], tags)
  **   client.commit(toCommit)
  **
  **   // update dis tag
  **   changes := ["id": orig->id, "mod":orig->mod, "dis": "New dis"]
  **   toCommit := Etc.makeDictGrid(["commit":"update"], changes)
  **   client.commit(toCommit)
  **
  Grid commit(Grid req)
  {
    if (req.meta.missing("commit")) throw ArgErr("Must specified grid.meta commit tag")
    return call("commit", req)
  }

  **
  ** Call the given REST operation with its request grid and
  ** return the response grid.  If req is null, then an empty
  ** grid used for request.  If the checked flag is true and server
  ** returns an error grid, then raise `haystack::CallErr`, otherwise return
  ** the grid itself.
  **
  Grid call(Str op, Grid? req := null, Bool checked := true)
  {
    if (req == null) req = Etc.makeEmptyGrid
    Str reqStr := gridToStr(req)
    Str resStr := doCall(op, reqStr)
    Grid res   := ZincReader(resStr.in).readGrid
    if (checked && res.isErr) throw CallErr(res)
    return res
  }

  private Str doCall(Str op, Str req)
  {
    // write body to internal UTF-8 buffer to get content size
    body := Buf().print(req).flip

    // setup request
    c := toWebClient(op.toUri)
    c.reqMethod = "POST"
    c.reqHeaders["Content-Type"] = "text/zinc; charset=utf-8"
    c.reqHeaders["Content-Length"] = body.size.toStr
    debugCount := debugReq(log, c, req)

    // write request
    c.writeReq
    c.reqOut.writeBuf(body).close

    // read response
    c.readRes
    if (c.resCode == 100) c.readRes
    resOK := c.resCode == 200
    res := resOK ? c.resIn.readAllStr : null
    c.close
    if (!resOK) throw IOErr("Bad HTTP response $c.resCode $c.resPhrase")
    debugRes(log, debugCount, c, res)
    return res
  }

  @NoDoc WebClient toWebClient(Uri path)
  {
    auth.prepare(WebClient(this.uri + path))
  }

  @NoDoc static Int debugReq(Log? log, WebClient c, Str? req)
  {
    if (log == null || !log.isDebug) return 0
    count := debugCounter.getAndIncrement
    s := StrBuf()
    s.add("> [$count]\n")
    s.add("$c.reqMethod $c.reqUri\n")
    c.reqHeaders.each |v, n| { s.add("$n: $v\n") }
    if (req != null) s.add(req.trimEnd).add("\n")
    log.debug(s.toStr)
    return count
  }

  @NoDoc static Void debugRes(Log? log, Int count, WebClient c, Str? res)
  {
    if (log == null || !log.isDebug) return
    s := StrBuf()
    s.add("< [$count]\n")
    s.add("$c.resCode $c.resPhrase\n")
    c.resHeaders.each |v, n| { s.add("$n: $v\n") }
    if (res != null) s.add(res.trimEnd).add("\n")
    log.debug(s.toStr)
  }

  private Str gridToStr(Grid grid)
  {
    buf := StrBuf()
    out := ZincWriter(buf.out)
    out.ver = 2
    out.writeGrid(grid).flush
    return buf.toStr
  }

//////////////////////////////////////////////////////////////////////////
// Main
//////////////////////////////////////////////////////////////////////////

  // set ApiAuth.debug = true to dump authentication cycle
  @NoDoc static Void main(Str[] args)
  {
    if (args.size < 3) { echo("usage: <uri> <user> <pass>"); return }
    uri  := args[0].toUri.plusSlash
    user := args[1]
    pass := args[2]
    log  :=  Log.get("haystackClient") { level = LogLevel.debug }
    c := Client.open(uri, user, pass, ["log":log])
    a := c.about
    echo("\nPing successful: $c.uri\n")
    a.each |v, k| { echo("$k: $v") }
    echo
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  @NoDoc static const AtomicInt debugCounter := AtomicInt()

  @NoDoc const Log log
  @NoDoc HaystackClientAuth auth { private set }
}

**************************************************************************
** HaystackClientAuth
**************************************************************************

@NoDoc
mixin HaystackClientAuth
{
  ** Prepare a client with the appropiate authentication headers
  abstract WebClient prepare(WebClient client)
}