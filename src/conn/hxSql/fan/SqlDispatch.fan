//
// Copyright (c) 2010, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   16 Apr 2010  Brian Frank  Creation
//   29 Dec 2021  Brian Frank  Redesign for Haxall
//

using concurrent
using xeto
using haystack
using axon
using hx
using hxConn
using sql::SqlConn as SqlClient
using sql::SqlErr

**
** Dispatch callbacks for the SQL connector
**
class SqlDispatch : ConnDispatch
{
  new make(Obj arg) : super(arg) {}

  override Void onOpen()
  {
    this.client = SqlExt.doOpen(conn)
  }

  override Void onClose()
  {
    client.close
    client = null
  }

  override Dict onPing()
  {
    meta := client.meta
    tags := Str:Obj[:]
    tags["productName"]    = meta.productName
    tags["productVersion"] = meta.productVersionStr
    tags["driverName"]     = meta.driverName
    tags["driverVersion"]  = meta.driverVersionStr
    return Etc.makeDict(tags)
  }

  override Obj? onSyncHis(ConnPoint point, Span span)
  {
    try
    {
      // get connections axon expression
      exprStr := rec["sqlSyncHisExpr"] as Str
      if (exprStr == null) throw FaultErr("'sqlConn' rec must define 'sqlSyncHisExpr': $point.dis")

      // execute expr
      result := evalSyncHisExpr(point, exprStr, span.start, span.end)

      // map results to HisItems
      items := HisItem[,]
      if (!result.isEmpty)
      {
        // check columns
        cols := result.cols
        if (cols.size != 2) throw Err("sqlSyncHisExpr result must have two columns")

        items.capacity = result.size
        result.each |row| { items.add(HisItem(row.val(cols[0]), row.val(cols[1]))) }
      }

      // success!
      return point.updateHisOk(items, span)
    }
    catch (Err e) return point.updateHisErr(e)
  }

  private Grid evalSyncHisExpr(ConnPoint point, Str exprStr, DateTime start, DateTime end)
  {
    cx := ext.proj.newContext(evalUser)
    Actor.locals[ActorContext.actorLocalsKey] = cx
    try
    {
      // get expr as 3 parameter function
      fn := cx.evalToFunc(exprStr)

      // execute expr
      result := fn.call(cx, [rec, point.rec, ObjRange(start, end)])
      if (result isnot Grid) throw Err("sqlSyncHisExpr returned invalid result type: ${result?.typeof}")
      return result
    }
    finally Actor.locals.remove(ActorContext.actorLocalsKey)
  }

  once User evalUser()
  {
    proj.sys.user.makeSyntheticUser("sqlHisSync", ["projAccessFilter":"name==${proj.name.toCode}"])
  }

  private SqlClient? client
}

