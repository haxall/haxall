//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   19 Oct 2021  Matthew Giannini  Creation
//   15 Jul 2025  Matthew Giannini  Refactor for Haxall 4.0
//

using concurrent
using util
using docker
using xeto
using haystack
using hx

**
** DockerMgr provides primary interface for working with Docker.
**
final const class DockerMgr : Actor
{

//////////////////////////////////////////////////////////////////////////
// Constructor
//////////////////////////////////////////////////////////////////////////

  new make(DockerExt ext) : super(ext.proj.exts.actorPool)
  {
    this.ext = ext
  }

  const DockerExt ext

  private Log log() { ext.log }

  private const AtomicBool running := AtomicBool(true)
  private const ConcurrentMap containers := ConcurrentMap()

  ** Convenience to get current container ids
  private Str[] ids() { containers.keys(Str#) }

//////////////////////////////////////////////////////////////////////////
// Mgr
//////////////////////////////////////////////////////////////////////////

  ** Run a Docker iamge using the given container configuration. Returns
  ** the `DockerContainer` that was created.
  DockerContainer run(Str image, Obj config) { runAsync(image, config).get }

  ** Async version of `run`.  Returns a Future that is completed
  ** with the container once it is started.
  Future runAsync(Str image, Obj config)
  {
    send(HxMsg("run", image, config))
  }

  ** Kill the container with the given id and then remove it.
  Dict deleteContainer(Str id)
  {
    res := send(HxMsg("deleteContainer", id)).get
    return resToDict(Ref(id), res)
  }

//////////////////////////////////////////////////////////////////////////
// DockerMgrActor
//////////////////////////////////////////////////////////////////////////

  Grid listImages()
  {
    onListImages
  }

  Grid listContainers()
  {
    onListContainers
  }

  StatusRes stopContainer(Str id)
  {
    send(HxMsg("stopContainer", id)).get
  }

  Void shutdown()
  {
    send(HxMsg("shutdown")).get
  }

  protected override Obj? receive(Obj? obj)
  {
    msg := (HxMsg)obj
    switch (msg.id)
    {
      case "run":              return onRun(msg.a, msg.b)
      // case "endpointSettings": return onEndpointSettings(msg.a, msg.b)
      case "stopContainer":    return onStopContainer(msg.a)
      case "deleteContainer":  return onDeleteContainer(msg.a)
      case "shutdown":         return onShutdown
      default: throw Err("Unrecognized msg: $msg")
    }
  }

//////////////////////////////////////////////////////////////////////////
// Run
//////////////////////////////////////////////////////////////////////////

  private DockerContainer onRun(Str image, Obj config)
  {
    // TODO:SECURITY: check image is accessible

    // decode config into CreateContainerCmd and execute it
    cmd := createContainer(config).withImage(image)
    id  := cmd.exec.id

    // add container to set of created containers
    containers.add(id, Unsafe(cmd))

    // start the container
    try
    {
      client.startContainer(id).exec.throwIfErr
    }
    catch (Err err)
    {
      throw Err("Failed to start container for image ${image}", err)
    }

    // return the container
    container := client.listContainers
      .withFilters(Filters().withFilter("id", [id]).build)
      .exec.first

    return container
  }

  ** Decodes json into CreateContainerCmd. It overwrites any volume binds
  ** so that only the `io/` directory is bound.
  private CreateContainerCmd createContainer(Obj config)
  {
    CreateContainerCmd cmd := decodeCmd(config, CreateContainerCmd#)

    // force single bind for io/ directory
    ioDir := ext.proj.dir.plus(`io/`)
    if (ext.settings.ioDirMount?.trimToNull != null)
    {
      // handle custom configuration
      ioDir = ext.settings.ioDirMount.toUri.plusSlash.toFile
    }
    // overwrite any binds (noughty-noughty) and only expose io/
    cmd.hostConfig.withBinds([
      Bind
      {
        it.src  = ioDir.normalize.osPath
        it.dest = "/io"
      }
    ])

    return cmd
  }

//////////////////////////////////////////////////////////////////////////
// Endpoint Settings
//////////////////////////////////////////////////////////////////////////

  // private HxDockerEndpoint? onEndpointSettings(Str id, Str network)
  // {
  //   containers := client.listContainers
  //     .withFilters(Filters().withFilter("id", [checkManaged(id)]).build)
  //     .exec
  //   if (containers.isEmpty) throw Err("No container with id $id")
  //   if (containers.size > 1) throw Err("Multiple containers with id $id: ${containers.size}")

  //   endpoint := containers.first.network(network)
  //   if (endpoint == null) return null

  //   return MHxDockerEndpoint(endpoint)
  // }

//////////////////////////////////////////////////////////////////////////
// List Images
//////////////////////////////////////////////////////////////////////////

  private Grid onListImages()
  {
    arr := client.listImages.exec

    gb := GridBuilder()
      .addCol("id")
      .addCol("repoTags")
      .addCol("created")
      .addCol("size")
      .addCol("dockerImage")
      .addCol("labels", ["hidden": Marker.val])
      .addCol("json", ["hidden": Marker.val])

    arr.each |image|
    {
      gb.addDictRow(Etc.makeDict([
        "id":           Ref(image.id, idDis(image.id)),
        "dockerImage":  Marker.val,
        "repoTags":     image.repoTags,
        "created":      image.createdAt,
        "size":         Number(image.size, Unit("byte")),
        "labels":       labelsToDict(image.labels),
        "json":         JsonOutStream.writeJsonToStr(image.rawJson),
      ]))
    }

    return gb.toGrid
  }

  private static Dict labelsToDict(Str:Str labels)
  {
    acc := Str:Str[:]
    labels.each |v, k| { acc[Etc.toTagName(k)] = v }
    return Etc.makeDict(acc)
  }

//////////////////////////////////////////////////////////////////////////
// List Containers
//////////////////////////////////////////////////////////////////////////

  private Grid onListContainers()
  {
    arr := client.listContainers
      .withShowAll(true)
      .withFilters(Filters().withFilter("id", ids).build)
      .exec

    gb := GridBuilder()
      .addCol("id")
      .addCol("dockerState")
      .addCol("dockerStatus")
      .addCol("names")
      .addCol("image")
      .addCol("command")
      .addCol("created")
      .addCol("dockerContainer")
      .addCol("json", ["hidden":Marker.val])

    // arr.sort |a,b->Int|
    // {
    //   aState := a.state
    //   bState := b.state
    //   tsCompare := -(a.createdAt <=> b.createdAt)
    //   if (aState == "running")
    //   {
    //     return bState == "running" ? tsCompare : -1
    //   }
    //   else if (bState == "running")
    //   {
    //     return -1
    //   }
    //   return tsCompare
    // }

    // only show containers that the mgr started
    arr
      .findAll |c| { containers.containsKey(c.id) }
      .each |c|
      {
        gb.addDictRow(Etc.makeDict([
          "id":              Ref(c.id, idDis(c.id)),
          "dockerContainer": Marker.val,
          "dockerState":     c.state,
          "dockerStatus":    c.status,
          "names":           c.names,
          "image":           c.image,
          "command":         c.command,
          "created":         c.createdAt,
          "json":            JsonOutStream.writeJsonToStr(c.rawJson),
        ]))
      }

    return gb.toGrid
  }

//////////////////////////////////////////////////////////////////////////
// StopContainer
//////////////////////////////////////////////////////////////////////////

  StatusRes onStopContainer(Str id)
  {
    client.stopContainer(checkManaged(id)).withWait(1sec).exec
  }

//////////////////////////////////////////////////////////////////////////
// DeleteContainer
//////////////////////////////////////////////////////////////////////////

  private StatusRes onDeleteContainer(Str id)
  {
    // forcefully kill the container and remove it
    res := client.removeContainer(checkManaged(id)).withForce(true).exec

    // remove from managed containers
    // 404 - no such container
    if (res.isOk || res.statusCode == 404)
    {
      containers.remove(id)
    }

    return res
  }

//////////////////////////////////////////////////////////////////////////
// Shutdown
//////////////////////////////////////////////////////////////////////////

  private Str[] onShutdown()
  {
    try
    {
      acc := Str[,]
      containers.each |json, id|
      {
        try
        {
          onDeleteContainer(id).throwIfErr
          acc.add(id)
        }
        catch (Err err)
        {
          log.err("Failed to kill container ${id}", err)
        }
      }
      return acc
    }
    finally
    {
      running.val = false
    }
  }

//////////////////////////////////////////////////////////////////////////
// Util
//////////////////////////////////////////////////////////////////////////

  internal DockerClient client() { DockerClient(dockerConfig) }

  internal DockerConfig dockerConfig()
  {
    if (!running.val) throw Err("The Docker service is stopped")

    // check if docker daemon is specified in the settings
    host := ext.settings.dockerDaemon?.trimToNull

    return DockerConfig
    {
      if (host != null) it.daemonHost = host
    }
  }

  private Str checkManaged(Str id)
  {
    obj := containers.get(id)
    if (obj == null) throw ArgErr("No managed container with id: $id")
    return id
  }

  private static Dict resToDict(Ref id, StatusRes res)
  {
    m := Str:Obj?[
      "id":         id,
      "statusCode": res.statusCode,
      "msg":        res.msg,
    ]
    if (res.isErr) m["err"] = Marker.val
    return Etc.makeDict(m)
  }

  private static Str idDis(Str id)
  {
    parts := id.split(':')
    hash  := parts.getSafe(1, parts[0])
    return hash[0..<12]
  }

//////////////////////////////////////////////////////////////////////////
// Decoding
//////////////////////////////////////////////////////////////////////////

  private DockerHttpCmd decodeCmd(Obj obj, Type type)
  {
    DockerHttpCmd? cmd
    if (obj.typeof.fits(type)) cmd = obj
    else
    {

      Map? json := null
      if (obj is Map)       json = (Map)obj
      else if (obj is Str)  json = (Map)JsonInStream(((Str)obj).in).readJson
      else if (obj is Dict) json = dictToMap(obj)
      else throw ArgErr("Cannot decode $obj.typeof as $type: $obj")
      cmd = DockerJsonDecoder().decodeVal(json, type) as DockerHttpCmd
    }
    return cmd.withClient(this.client)
  }

  ** Deeply convert a Dict to a Map. Unlike Etc.dictToMap, this handles
  ** nested Dicts.
  private static Str:Obj? dictToMap(Dict d) { convertDictVal(d) }

  private static Obj? convertDictVal(Obj? val)
  {
    if (val is Dict)
    {
      acc := Str:Obj?[:]
      ((Dict)val).each |v, k|
      {
        if (k isnot Str) throw ArgErr("Key is not Str $k ($k.typeof) in $val")
        acc[k] = convertDictVal(v)
      }
      return acc
    }
    else if (val is List)
    {
      return ((List)val).map |item->Obj?| { convertDictVal(item) }
    }
    else return val
  }
}

