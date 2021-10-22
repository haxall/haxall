//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   19 Oct 2021  Matthew Giannini  Creation
//

using haystack
using hx
using axon

**
** Docker lib Axon functions
**
const class DockerFuncs
{
  ** Current context
  private static HxContext curHx() { HxContext.curHx }

  ** Lookup DockerLib for context
  private static DockerLib lib(HxContext cx := curHx) { cx.rt.lib("docker") }

//////////////////////////////////////////////////////////////////////////
// Views
//////////////////////////////////////////////////////////////////////////

  @Axon { admin=true }
  static Grid dockerListImages()
  {
    lib.dockerMgr.listImages
  }

  @Axon { admin=true }
  static Grid dockerListContainers()
  {
    meta := Str:Obj?[:]
    if (curHx.feedIsEnabled) curHx.feedAdd(DockerContainerFeed(), meta)
    return lib.dockerMgr.listContainers.setMeta(meta)
  }

  // @Axon { admin=true }
  // static Grid dockerStopContainers(Obj arg)
  // {
  //   Ref[] ids := [,]
  //   if (arg is List)
  //   {
  //     ids = ((List)arg).map |x->Ref| {
  //       if (x is Ref) return x
  //       if (x is Str) return Ref.fromStr(x)
  //       throw ArgErr("Invalid container id: ${x}")
  //     }
  //   }
  //   else if (arg is Ref) ids.add(arg)
  //   else if (arg is Str) ids.add(Ref.fromStr(arg))
  //   else throw ArgErr("$arg ($arg.typeof)")

  //   gb := GridBuilder()
  //     .addCol("id")
  //     .addCol("statusCode")
  //     .addCol("msg")
  //     .addCol("err")
  //     .addCol("errMsg")
  //     .addCol("errTrace")
  //   ids.each |ref|
  //   {
  //     try
  //     {
  //       res := lib.dockerMgr.stopContainer(ref.id)
  //       gb.addDictRow(Etc.makeDict([
  //         "id":         ref,
  //         "statusCode": res.statusCode,
  //         "msg":        res.msg,
  //       ]))
  //     }
  //     catch (Err err)
  //     {
  //       gb.addDictRow(Etc.makeDict([
  //         "id":       ref,
  //         "err":      Marker.val,
  //         "errMsg":   err.msg,
  //         "errTrace": err.traceToStr,
  //       ]))
  //     }
  //   }
  //   return gb.toGrid
  // }

  ** Kill and remove a container.
  @Axon { admin=true }
  static Dict dockerDeleteContainer(Obj id)
  {
    lib.dockerMgr.deleteContainer(toRef(id).id)
  }

//////////////////////////////////////////////////////////////////////////
// Service Funcs
//////////////////////////////////////////////////////////////////////////

  @Axon { admin=true }
  static Str dockerRun(Str image, Obj config := Etc.emptyDict)
  {
    lib.dockerMgr.run(image, config)
  }

//////////////////////////////////////////////////////////////////////////
// Util
//////////////////////////////////////////////////////////////////////////

  private static Ref toRef(Obj arg)
  {
    if (arg is Ref) return arg
    if (arg is Str) return Ref.fromStr(arg)
    throw ArgErr("Cannot convert to Ref: $arg ($arg.typeof)")
  }
}

**************************************************************************
** DockerContainerFeed
**************************************************************************

internal const class DockerContainerFeed : HxFeed
{
  override Grid onPoll() { DockerFuncs.dockerListContainers }
}
