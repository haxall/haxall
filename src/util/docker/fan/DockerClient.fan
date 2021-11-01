//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   11 Oct 2021  Matthew Giannini  Creation
//

using web
using util

**
** DockerClient provides conveniences for creating commands to
** communicate with the Docker daemon. All commands are initially
** configured based on the `DockerConfig` used to construct the client.
**
class DockerClient
{

//////////////////////////////////////////////////////////////////////////
// Constructor
//////////////////////////////////////////////////////////////////////////

  new make(DockerConfig config)
  {
    this.config = config
  }

  ** Docker config
  const DockerConfig config

//////////////////////////////////////////////////////////////////////////
// DockerClient
//////////////////////////////////////////////////////////////////////////

  Bool ping()
  {
    PingCmd().withClient(this).exec.statusCode == 200
  }

  PullImageCmd pullImage(Str repo)
  {
    prepare(PullImageCmd(repo))
  }

  ListImagesCmd listImages()
  {
    prepare(ListImagesCmd())
  }

  CreateContainerCmd createContainer(Str image)
  {
    prepare(CreateContainerCmd().withImage(image))
  }

  StartContainerCmd startContainer(Str id)
  {
    prepare(StartContainerCmd(id).withId(id))
  }

  StopContainerCmd stopContainer(Str id)
  {
    prepare(StopContainerCmd(id))
  }

  ListContainersCmd listContainers()
  {
    prepare(ListContainersCmd())
  }

  RemoveContainerCmd removeContainer(Str id)
  {
    prepare(RemoveContainerCmd(id))
  }

  private DockerHttpCmd prepare(DockerHttpCmd cmd)
  {
    cmd.withClient(this)
  }

//////////////////////////////////////////////////////////////////////////
// Http
//////////////////////////////////////////////////////////////////////////

  DockerHttpRes write(DockerHttpReq req)
  {
    transport := DockerTransport.open(config)
    try
    {
      // write request line and headers
      out := transport.out
      out.print(httpMethod(req)).print(" ").print(req.path.encode).print(" HTTP/1.1\r\n")
         .print("Host: $httpHost\r\n")
      WebUtil.writeHeaders(out, req.headers)
      out.print("\r\n").flush

      // write content
      if (req.content != null)
      {
        out.writeBuf(req.content).flush
      }

      return DockerHttpRes(transport)
    }
    catch (Err err)
    {
      transport.close
      throw err
    }
  }

//////////////////////////////////////////////////////////////////////////
// Util
//////////////////////////////////////////////////////////////////////////

  private Str httpHost()
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

  private static Str httpMethod(DockerHttpReq req)
  {
    m := req.method.upper
    switch(m)
    {
      case "GET":
      case "POST":
      case "PUT":
      case "DELETE":
      case "OPTIONS":
      case "PATCH":
      case "HEAD":
        // fall-through
        return m
    }
    throw ArgErr("Invalid HTTP Method: ${req.method}")
  }
}

**************************************************************************
** DockerHttpReq
**************************************************************************

const class DockerHttpReq
{
  static DockerHttpReqBuilder builder() { DockerHttpReqBuilder() }

  static DockerHttpReq get(Uri path, Str:Str headers := [:])
  {
    DockerHttpReq.builder.withMethod("GET").withPath(path).withHeaders(headers).build
  }

  new make(|This| f)
  {
    f(this)
  }

  const Str method

  const Uri path

  const Str:Str headers := [:]

  const Buf? content
}

**************************************************************************
** DockerHttpReqBuilder
**************************************************************************

class DockerHttpReqBuilder
{
  new make()
  {
  }

  private Str? method

  private Uri? path

  private Str:Str headers := Str:Str[:] { caseInsensitive = true }

  private Buf? content

  This withMethod(Str method) { this.method = method.upper; return this }

  This withPath(Uri path) { this.path = path; return this }

  This withHeader(Str name, Str val) { headers[name] = val; return this }

  This withHeaders(Str:Str headers) { headers.setAll(headers); return this }

  This withContent(Buf buf) { this.content = buf; return this }

  DockerHttpReq build()
  {
    checkRequired
    finishHeaders
    return DockerHttpReq
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
    if (method == "POST")
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
** DockerHttpRes
**************************************************************************

class DockerHttpRes
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