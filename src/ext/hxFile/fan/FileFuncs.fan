//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   13 Jul 2026  Matthew Giannini  Creation
//

using concurrent
using web
using axon
using xeto
using haystack
using hx
using folio

** File module Axon functions
@NoDoc
const class FileFuncs
{
  private static FileExt ext(Context cx := Context.cur) { cx.sys.ext("hx.file") }

  @NoDoc @Api @Axon { su = true }
  static Obj? fileMount(Uri path)
  {
    ext.spi.send(HxMsg("file.mount", Context.cur.user, toAbs(path))).get(10sec)
  }

  @NoDoc @Api @Axon { su = true }
  static Obj? fileUnmount(Uri path)
  {
    ext.spi.send(HxMsg("file.unmount", Context.cur.user, toAbs(path))).get(10sec)
  }

  @NoDoc @Api @Axon { su = true }
  static Obj? fileMountRemove(Uri path)
  {
    if (!isRemovable(path)) throw ArgErr("Not a removable mount: $path")
    return ext.spi.send(HxMsg("file.mountRem", Context.cur.user, toAbs(path))).get(10sec)
  }

//////////////////////////////////////////////////////////////////////////
// Views
//////////////////////////////////////////////////////////////////////////

  ** List all mounts recursively, but only show user-defined mounts
  @NoDoc @Api @Axon { su = true }
  static Grid fileMounts()
  {
    gb := GridBuilder()
    gb.addCol("id", ["hidden":Marker.val]).addCol("dis").addCol("name").addCol("mountPoint").addCol("localPath")
    listMounts.each |mount|
    {
      if (!isRemovable(mount.config)) return

      id := Ref(mount.mountPoint.toStr.toBuf.toBase64Uri)
      gb.addRow([id, mount.dis, mount.name, mount.mountPoint.toStr, mount.config.get("localPath")])
    }
    return gb.toGrid
  }

  ** New action
  @NoDoc @Api @Axon { su = true }
  static Grid fileMountNew(Obj fileMountDict)
  {
    config := Etc.toRec(fileMountDict)
    ext.spi.send(HxMsg("file.mountNew", Context.cur.user, config)).get(10sec)
    return Etc.makeDictGrid(null, config)
  }

  ** Delete action
  @NoDoc @Api @Axon { meta =
    Str<|disKey: "ui::delete"
         su
         select
         multi
         confirm: {icon:"warn" disKey:"ui::mountDeleteConfirm" detailsKey:"ui::mountDeleteConfirmDetails"}
         |> }
  static Grid fileMountDelete(Obj mountRefs)
  {
    refs := Etc.toIds(mountRefs)
    refs.each |ref|
    {
      path := Buf.fromBase64(ref.id).readAllStr.toUri
      ext.spi.send(HxMsg("file.mountRem", Context.cur.user, path)).get(10sec)
    }
    return Etc.makeEmptyGrid
  }

//////////////////////////////////////////////////////////////////////////
// Util
//////////////////////////////////////////////////////////////////////////

  static Mount[] listMounts()
  {
    acc := Mount[,]
    ext.root.mounts.each |mount|
    {
      acc.add(mount)
      if (mount is DynamicMount) acc.addAll((mount as DynamicMount).mounts)
    }
    return acc
  }

  ** Is this mount removable via Axon?
  static private Bool isRemovable(Obj arg)
  {
    Dict? config := null
    if (arg is Dict) config = (Dict)arg
    else if (arg is Uri) config = ext.mountConfigs(false)[arg] ?: Etc.emptyDict
    else if (arg is Mount) return isRemovable((arg as Mount).config)
    else throw ArgErr("$arg ($arg.typeof)")
    return config.missing("frozen")
  }

  ** If path is relative, make it absolute to the current context's project
  static private Uri toAbs(Uri path)
  {
    if (path.isPathAbs) return path
    return `/proj/${Context.cur.proj.name}/`.plus(path)
  }
}

