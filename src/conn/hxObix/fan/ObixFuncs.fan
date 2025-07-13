//
// Copyright (c) 2010, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   1 Mar 2010  Brian Frank  Creation
//   3 Feb 2022  Brian Frank  Redesign for Haxall
//

using concurrent
using xml
using obix
using haystack
using axon
using hx
using hxConn

**
** Obix connector Axon functions
**
const class ObixFuncs
{
  ** Deprecated - use `connPing()`
  @Deprecated @Axon { admin = true }
  static Future obixPing(Obj conn)
  {
    ConnFwFuncs.connPing(conn)
  }

  ** Deprecated - use `connSyncCur()`
  @Deprecated @Axon { admin = true }
  static Future[] obixSyncCur(Obj points)
  {
    ConnFwFuncs.connSyncCur(points)
  }

  ** Deprecated - use `connSyncHis()`
  @Deprecated @Axon { admin = true }
  static Obj? obixSyncHis(Obj points, Obj? span := null)
  {
    ConnFwFuncs.connSyncHis(points, span)
  }

  ** Deprecated - use `connLearn()`
  @NoDoc @Axon { admin = true }
  static Grid obixLearn(Obj conn, Obj? arg := null)
  {
    ConnFwFuncs.connLearn(conn, arg).get(1min)
  }

  **
  ** Read one Uri from an obixConn.  The object is returned
  ** as a grid with the object's meta-data returned via grid.meta
  ** and each immediate child returned as a row in the grid.  The
  ** tags used for grid meta and the columns are:
  **
  **  - href: meta.href is absolute uri of object, the href col
  **    is child's uri relative to meta.href
  **  - name: obix 'name' attribute
  **  - dis: obix 'displayName' attribute
  **  - val: obix 'val' attribute unless 'null' attribute is true
  **  - is: contract list
  **  - icon: uri relative to meta.href of icon
  **
  ** You can read the icon via the tunnel URI:
  **    {api}/obix/icon/{id}/{uri}
  **
  ** Side effects:
  **   - performs blocking network IO
  **
  @Axon { admin = true }
  static Grid obixReadObj(Obj conn, Uri uri)
  {
    dispatch(curContext, conn, HxMsg("readObj", uri))
  }

  ** Synchronously query a 'obix::History' for its timestamp/value pairs.
  ** Range may be any valid object used with 'his' queries.
  @Axon { admin = true }
  static Grid obixReadHis(Obj conn, Uri uri, Obj? span)
  {
    // map to Span based on timezone of connector
    cx := curContext
    rec := Etc.toRec(conn)
    if (rec.missing("tz")) throw Err("obixConn missing 'tz' tag")
    tz := TimeZone.fromStr(rec->tz)
    s := Etc.toSpan(span, tz, cx)

    // delegate hisRead call to connector
    return dispatch(cx, rec, HxMsg("readHis", uri, s))
  }

  **
  ** Write an object as identified by given uri.  The following
  ** arg values are supported:
  **
  **   arg         oBIX
  **   ---         -----
  **   null        <obj null='true'/>
  **   "foo"       <str val='foo'/>
  **   true        <bool val='true'/>
  **   123         <real val='123.0'/>
  **   123m        <real val='123.0' unit='obix:units/meter'/>
  **   `foo.txt`   <uri val='foo.txt'/>
  **   2012-03-06  <date val='2012-03-06'/>
  **   23:15       <time val='23:15:00'/>
  **   DateTime    <abstime val='...' tz='...'/>
  **   XML Str     pass thru
  **
  ** Result object is transformed using same rules as `obixReadObj`.
  **
  @Axon { admin = true }
  static Grid obixWriteObj(Obj conn, Obj uri, Obj? arg)
  {
    dispatch(curContext, conn, HxMsg("writeObj", uri, arg))
  }

  **
  ** Invoke an 'obix:op' operation as identified by given uri.
  ** See `obixWriteObj` for supported arg values and `obixReadObj`
  ** for result object.
  **
  @Axon { admin = true }
  static Grid obixInvoke(Obj conn, Obj uri, Obj? arg)
  {
    dispatch(curContext, conn, HxMsg("invoke", uri, arg))
  }

  ** Ancient function left around just in case anybody ever used it
  @NoDoc @Axon { admin = true }
  static Obj? obixSyncHisGroup(Str group, Obj? range := null)
  {
    ConnFwFuncs.connSyncHis(curContext.db.readAllList(Filter.eq("obixSyncHisGroup", group.toCode)), range)
  }

  **
  ** Hook to read point list of obix::History tree
  **
/*
  @NoDoc @Axon { admin = true }
  static Grid obixPointList(Obj conn, Uri uri)
  {
    // get connector
    c := toConn(conn)

    // recurse to build grid
    cols := ["dis", "kind", "unit", "tz", "hisStart", "hisEnd", "obixUri"]
    rows := Obj[,]
    doObixPointList(c, uri, rows)
    grid := Etc.makeListsGrid(null, cols, null, rows)

    // save grid as zinc file in io directory
    name := uri.name
    name = name.replace("\\",   "")
    name = name.replace("\$35", "5")
    name = name.replace("\$3a", "-")
    name = name.replace("\$20", "-")
    saveUri := `io/points-${name}.zinc`
    echo("Save grid `$saveUri`")
    ZincWriter(c.rt.dir.plus(saveUri).out).writeGrid(grid).close

    return grid
  }

  private static Void doObixPointList(ObixConnX c, Uri uri, Obj[] rows)
  {
    // read object
    obj := c.client.read(uri)
    dis := c.toDis(obj)
    echo("-- obixPointList: $dis [$uri]")

    // if not history then recurse
    isHis := obj.contract.uris.contains(`obix:History`)
    if (!isHis)
    {
      obj.list.each |kid|
      {
        if (kid.href != null) doObixPointList(c, uri+kid.href, rows)
      }
      return
    }

    // read last history item to get tz, kind, unit
    tags := c.readHisTags(obj)

    // map to row
    hisStart := (obj.get("start")?.val as DateTime)?.date
    hisEnd   := (obj.get("end")?.val as DateTime)?.date
    rows.add([dis, tags["kind"], tags["unit"], tags["tz"], hisStart, hisEnd, uri.toStr])
  }
  */

  internal static Obj? dispatch(HxContext cx, Obj conn, HxMsg msg)
  {
    ext := (ObixExt)cx.rt.ext("hx.obix")
    return ext.conn(Etc.toId(conn)).sendSync(msg)
  }

  private static HxContext curContext() { HxContext.curHx }

}

