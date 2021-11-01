//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   11 Oct 2021  Matthew Giannini  Creation
//

using util

**************************************************************************
** DockerHttpCmd
**************************************************************************

abstract class DockerHttpCmd
{
  new make(|This|? f := null) { f?.call(this) }

  ** The `DockerClient` to use for sending requests to the Docker daemon
  @JsonIgnore
  protected DockerClient? client { internal set }
  This withClient(DockerClient client) { this.client = client; return this }

  protected DockerConfig? dockerConfig() { client?.config }

  ** Sends the command to the docker daemon and handles the response.
  **
  ** The `DockerHttpRes` is guaranteed to be closed when this method completes.
  Obj? send(|DockerHttpRes res->Obj?| f)
  {
    if (client == null) throw DockerErr("DockerClient not set")
    res := client.write(httpReq.build)
    try
    {
      return f(res)
    }
    finally
    {
      res.close
    }
  }

  ** Get the HTTP request builder for this command. By default, the builder
  ** is initialized to do a 'POST' for the command `apiPath`.
  protected virtual DockerHttpReqBuilder httpReq()
  {
    DockerHttpReq.builder.withMethod("POST").withPath(verApiPath)
  }

  ** Get the unversioned URI for this command.
  **
  ** Example: `/containers/list`
  protected abstract Uri apiPath()

  ** Get the versioned command URI path.
  ** The veresion specified in the `DockerConfig` is used.
  private Uri verApiPath()
  {
    `/v${dockerConfig.apiVer}/`.plus(apiPath.relTo(`/`))
  }

  protected static DockerHttpRes checkRes(DockerHttpRes res)
  {
    if (res.isErr) throw DockerResErr(res)
    return res
  }

  ** Execute the command. By default, the request is sent to Docker
  ** and the *closed* `DockerHttpRes` is returned.
  virtual Obj exec()
  {
    send |DockerHttpRes res->DockerHttpRes| { res }
  }
}

**************************************************************************
** DockerCmd
**************************************************************************

abstract class DockerJsonCmd : DockerHttpCmd
{
  new make(|This|? f := null) : super(f)
  {
  }

  protected override DockerHttpReqBuilder httpReq()
  {
    super.httpReq
      .withHeader("Content-Type", "application/json")
      .withContent(toJsonContent)
  }

  private Buf toJsonContent()
  {
    buf := Buf()
    JsonOutStream(buf.out).writeJson(DockerJsonEncoder.encode(this))
    buf.seek(0)
// echo(buf.readAllStr)
    return buf.seek(0)
  }

  override Obj exec()
  {
    send |DockerHttpRes res->Obj|
    {
      DockerJsonDecoder().decodeVal(checkRes(res).readJson, resType)
    }
  }

  ** Get the command return type
  protected virtual Type resType()
  {
    // Reflect the exec() method to get the return type
    typeof.method("exec").returns
  }
}

