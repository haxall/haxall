//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   07 Oct 2021  Matthew Giannini  Creation
//

using concurrent
using web
using util

**************************************************************************
** DockerHttpClient
**************************************************************************

**
** DockerHttpClient provides low-level HTTP access to the docker daemon.
**
class DockerHttpClient
{

//////////////////////////////////////////////////////////////////////////
// Constructor
//////////////////////////////////////////////////////////////////////////

  new make(DockerConfig config)
  {
    this.config = config
    this.host   = toHost(config)
  }

  const DockerConfig config

  private const Str host

  private static Str toHost(DockerConfig config)
  {
    switch (config.hostScheme)
    {
      case "npipe":
      case "unix":
        return "localhost:2375"
      case "tcp":
        h := config.daemonHost.toUri.host
        p := config.daemonHost.toUri.port
        return p == null ? h : "${h}:${p}"
      default:
        throw ArgErr("Unsupported host scheme: ${config.daemonHost}")
    }
  }

//////////////////////////////////////////////////////////////////////////
// DockerHttpClient
//////////////////////////////////////////////////////////////////////////

  HttpRes write(HttpReq req)
  {
    transport := DockerTransport.open(config)
    try
    {
      // write request line and headers
      out := transport.out
      out.print(req.method.name).print(" ").print(req.path.encode).print(" HTTP/1.1\r\n")
         .print("Host: $host\r\n")
      WebUtil.writeHeaders(out, req.headers)
      out.print("\r\n").flush

      // write content
      if (req.content != null)
      {
        out.writeBuf(req.content).flush
      }

      return HttpRes(transport)
    }
    catch (Err err)
    {
      transport.close
      throw err
    }
  }
}

**************************************************************************
** HttpMethod
**************************************************************************

enum class HttpMethod
{
  GET,
  POST,
  PUT,
  DELETE,
  OPTIONS,
  PATCH,
  HEAD
}

**************************************************************************
** HttpReq
**************************************************************************

const class HttpReq
{
  static HttpReqBuilder builder() { HttpReqBuilder() }

  static HttpReq get(Uri path, Str:Str headers := [:])
  {
    HttpReq.builder.withMethod("GET").withPath(path).withHeaders(headers).build
  }

  new make(|This| f) { f(this) }

  const HttpMethod method

  const Uri path

  const Str:Str headers := [:]

  const Buf? content
}

**************************************************************************
** HttpReqBuilder
**************************************************************************

class HttpReqBuilder
{
  new make()
  {
  }

  private HttpMethod? method

  private Uri? path

  private Str:Str headers := Str:Str[:] { caseInsensitive = true }

  private Buf? content

  This withMethod(Str method) { this.method = HttpMethod.fromStr(method); return this }

  This withPath(Uri path) { this.path = path; return this }

  This withHeader(Str name, Str val) { headers[name] = val; return this }

  This withHeaders(Str:Str headers) { headers.setAll(headers); return this }

  This withContent(Buf buf) { this.content = buf; return this }

  HttpReq build()
  {
    checkRequired
    finishHeaders
    return HttpReq
    {
      it.method  = this.method
      it.path    = this.path
      it.headers = this.headers
      it.content = this.content
    }
  }

  private Void checkRequired()
  {
    missing := Str[,]
    if (method == null) missing.add("method")
    if (path == null) missing.add("path")
    if (!missing.isEmpty) throw ArgErr("Cannot build HTTP request, fields not set: ${missing}")
  }

  private Void finishHeaders()
  {
    if (method === HttpMethod.POST)
    {
      // set Content-Length if there is content
      if (content != null)
      {
        headers["Content-Length"] = content.size.toStr
      }
    }
  }
}

**************************************************************************
** HttpRes
**************************************************************************

class HttpRes
{
  internal new make(DockerTransport transport)
  {
    this.transport = transport

    // read response status and headers

    // status line
    in  := transport.in
    res := WebUtil.readLine(in)
    httpVer := "Not an HTTP response: $res"
    if (res.startsWith("HTTP/1.1")) httpVer = "1.1"
    else if (res.startsWith("HTTP/1.0")) httpVer = "1.0"
    else throw IOErr(httpVer)
    this.statusCode = res[9..11].toInt
    this.statusMsg  = res[13..-1]

    // response headers
    // docker doesn't use cookies so we won't save those
    this.headers = WebUtil.parseHeaders(in)

    // if there is response content, then wrap the raw
    // input stream with the appropriate chunked input stream
    this.content = WebUtil.makeContentInStream(headers, in)
  }

  private DockerTransport transport

  const Int statusCode

  const Str statusMsg

  const Str:Str headers

  InStream? content

  Bool isErr()
  {
    statusCode >= 400 && statusCode <= 599
  }

  private InStream resIn()
  {
    if (content == null) throw IOErr("No input stream for response $statusCode")
    return content
  }

  ** Read the body of the response as a Str and close the connection.
  Str readStr()
  {
    try { return resIn.readAllStr } finally { this.close }
  }

  ** Read the body of the response as JSON and close the connection.
  Obj readJson()
  {
    try { return JsonInStream(resIn).readJson } finally { this.close }
  }

  ** Close the connection and return this.
  This close()
  {
    transport.close
    return this
  }

  override Str toStr() { "$statusCode: $statusMsg" }
}