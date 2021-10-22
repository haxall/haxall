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

  new makeConfig(DockerConfig? dockerConfig)
  {
    this.dockerConfig = dockerConfig
  }

  ** Docker config
  @JsonIgnore
  protected DockerConfig? dockerConfig { internal set }
  This withDockerConfig(DockerConfig dockerConfig) { this.dockerConfig = dockerConfig; return this }

  ** Sends the command to the docker daemon and handles the response.
  **
  // ** If the response is successful, the callback is invoked with the response and this
  // ** method returns the value returned by the callback.
  // **
  // ** Throws an IOErr if the response indicates an error.
  **
  ** The `HttpRes` is guaranteed to be closed when this method completes.
  Obj? send(|HttpRes res->Obj?| f)
  {
    if (dockerConfig == null) throw DockerErr("DockerConfig not set")
    res := DockerHttpClient(dockerConfig).write(httpReq.build)
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
  protected virtual HttpReqBuilder httpReq()
  {
    HttpReq.builder.withMethod("POST").withPath(verApiPath)
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

  protected static HttpRes checkRes(HttpRes res)
  {
    if (res.isErr) throw DockerResErr(res)
    return res
  }

  ** Execute the command. By default, the request is sent to Docker
  ** and the *closed* `HttpRes` is returned.
  virtual Obj exec()
  {
    send |HttpRes res->HttpRes| { res }
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

  new makeConfig(DockerConfig dockerConfig) : super(dockerConfig)
  {
  }

  protected override HttpReqBuilder httpReq()
  {
    super.httpReq
      .withHeader("Content-Type", "application/json")
      .withContent(toJsonContent)
  }

  private Buf toJsonContent()
  {
    buf := Buf()
    JsonOutStream(buf.out).writeJson(JsonEncoder.encode(this))
    buf.seek(0)
// echo(buf.readAllStr)
    return buf.seek(0)
  }

  override Obj exec()
  {
    send |HttpRes res->Obj|
    {
      JsonDecoder().decodeVal(checkRes(res).readJson, resType)
    }
  }

  ** Get the command return type
  protected virtual Type resType()
  {
    // Reflect the exec() method to get the return type
    typeof.method("exec").returns
  }
}

