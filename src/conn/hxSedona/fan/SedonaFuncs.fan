//
// Copyright (c) 2012, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   14 May 2012  Brian Frank  Creation
//

using concurrent
using web
using xml
using haystack
using axon
using hx
using hxConn

**
** Sedona library functions.
**
const class SedonaFuncs
{
  ** Deprecated - use `connPing()`
  @Deprecated @Axon { admin = true }
  static Future sedonaPing(Obj conn)
  {
    ConnFwFuncs.connPing(conn)
  }

  ** Deprecated - use `connSyncCur()`
  @Deprecated @Axon { admin = true }
  static Future[] sedonaSyncCur(Obj points)
  {
    ConnFwFuncs.connSyncCur(points)
  }

  ** Deprecated - use `connLearn()`
  @NoDoc @Axon { admin = true }
  static Grid sedonaLearn(Obj conn, Obj? arg := null)
  {
    ConnFwFuncs.connLearn(conn, arg).get(1min)
  }

  ** Synchronously read the current state of the component
  ** identified by the given component identifier.
  @Axon { admin = true }
  static Obj? sedonaReadComp(Obj conn, Number compId)
  {
    dispatch(curContext, conn, HxMsg("readComp", compId))
  }

  ** Synchronously write a property
  @Axon { admin = true }
  static Obj? sedonaWrite(Obj conn, Str addr, Obj? val)
  {
    dispatch(curContext, conn, HxMsg("writeCompProperty", addr, val))
    return "ok"
  }

  ** Discover function for sedona.
  @NoDoc @Axon { admin = true }
  static Grid sedonaDiscover()
  {
    dicts := Dict[,]
    SedonaScheme.schemes.each |s|
    {
      grid := s.discover
      grid.each |r| { dicts.add(r) }
    }
    return Etc.makeDictsGrid(null, dicts)
  }

//////////////////////////////////////////////////////////////////////////
// Manifest Management
//////////////////////////////////////////////////////////////////////////

  ** List installed kit manifests
  @NoDoc @Axon { admin = true }
  static Grid sedonaKitManifests()
  {
    lib := curContext.rt.lib("sedona")

    cols := [
      "hasNatives", "doc", "version",
      "vendor", "description", "buildHost", "buildTime"
    ]

    b := GridBuilder()
    b.addCol("id", Etc.dict1("hidden", Marker.val))
    b.addCol("name")
    b.addCol("checksum")
    b.addColNames(cols)

    m := sedonaHome + `manifests/`
    if (m.exists)
    {
      m.listDirs.each |d|
      {
        d.listFiles.each |f|
        {
          if (f.ext != "xml") return

          try
          {
            elem     := xmlParse(f)
            name     := xmlToName(elem)
            checksum := xmlToChecksum(elem)
            id       := xmlToId(name, checksum)

            row  := Obj?[id, name, checksum]
            cols.each |c| { row.add(elem.attr(c, false)?.val) }
            b.addRow(row)
          }
          catch (Err err)
          {
            lib.log.err("Cannot parse manifest: $f.osPath", err)
          }
        }
      }
    }

    return b.toGrid.sortCol("name")
  }

  ** Upload kit manifests as list of URIs to io/upload/ directory
  @NoDoc @Axon { admin = true }
  static Void sedonaKitManifestUpload(Uri[] uris)
  {
    uris.each |uri|
    {
      file := curContext.rt.file.resolve(uri)
      try
      {
        elem     := xmlParse(file)
        name     := xmlToName(elem)
        checksum := xmlToChecksum(elem)
        id       := xmlToId(name, checksum)

        dest := idToFile(id, false)
        if (dest.exists) dest.delete
        // cannot use file.moveTo(dest) because of FileMount security checks
        // {sedonaHome} is not mounted so you can't move from FileMount to non-mount
        out := dest.out
        try
        {
          file.in.pipe(out)
          file.delete
        }
        finally
          out.close
      }
      catch (Err e)
      {
        throw Err("File is not a valid sedona manifest XML file: $file.name", e)
      }
    }
  }

  ** Display kit manifest file
  @NoDoc @Axon { admin = true }
  static Grid sedonaKitManifestView(Obj id)
  {
    xml := idToFile(id).readAllStr
    return Etc.makeMapGrid(["view":"text"], ["val":xml])
  }

  ** Delete given kit manifests.
  @NoDoc @Axon { admin = true }
  static Void sedonaDeleteKitManifests(Obj[] ids)
  {
    ids.each |id| { idToFile(id).delete }
  }

//////////////////////////////////////////////////////////////////////////
// Manifest Utils
//////////////////////////////////////////////////////////////////////////

  private static XElem xmlParse(File file)
  {
    XParser(file.in).parseDoc.root
  }

  private static Str xmlToName(XElem elem)
  {
    elem.attr("name").val
  }

  private static Str xmlToChecksum(XElem elem)
  {
    elem.attr("checksum").val.padl(8, '0')
  }

  private static Ref xmlToId(Str name, Str checksum)
  {
    Ref("$name-$checksum")
  }

  private static File idToFile(Obj id, Bool mustExist := true)
  {
    kit := id.toStr
    if (kit.contains(".")) throw Err("Invalid manifest: $id")
    dash := kit.index("-")
    name := kit[0..<dash]
    sum  := kit[dash+1..-1]
    path := `manifests/$name/${name}-${sum}.xml`
    file :=  sedonaHome + path
    if (!file.exists && mustExist) throw Err("Manifest not found: {var}/etc/sedona/$path")
    return file
  }

  static const File sedonaHome := Env.cur.workDir.plus(`etc/sedona/`)

//////////////////////////////////////////////////////////////////////////
// Helper Utils
//////////////////////////////////////////////////////////////////////////

  ** Dispatch a message to the given connector and return result
  private static Obj? dispatch(HxContext cx, Obj conn, HxMsg msg)
  {
    lib := (SedonaLib)cx.rt.lib("sedona")
    r := lib.conn(Etc.toId(conn)).sendSync(msg)
    return r
  }

  ** Current context
  private static HxContext curContext() { HxContext.curHx }

}

