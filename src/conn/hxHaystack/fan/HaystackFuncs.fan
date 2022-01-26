//
// Copyright (c) 2012, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   10 Jan 2012  Brian Frank  Creation
//   22 Jun 2021  Brian Frank  Redesign for Haxall
//

using concurrent
using haystack
using axon
using hx
using hxConn

**
** Haystack connector functions
**
const class HaystackFuncs
{
  ** Deprecated - use `connPing()`
  @Deprecated @Axon { admin = true }
  static Future haystackPing(Obj conn)
  {
    ConnFwFuncs.connPing(conn)
  }

  ** Deprecated - use `connLearn()`
  @Deprecated @Axon { admin = true }
  static Obj? haystackLearn(Obj conn, Obj? arg := null)
  {
    ConnFwFuncs.connLearn(conn, arg)
  }

  ** Deprecated - use `connSyncCur()`
  @Deprecated @Axon { admin = true }
  static Future[] haystackSyncCur(Obj points)
  {
    ConnFwFuncs.connSyncCur(points)
  }

  ** Deprecated - use `connSyncHis()`
  @Deprecated @Axon { admin = true }
  static Future[] haystackSyncHis(Obj points, Obj? span := null)
  {
    ConnFwFuncs.connSyncHis(points, span)
  }

  ** Perform Haystack HTTP API call to given Str op name and with
  ** given request grid (can be anything acceptable `toGrid`).  If
  ** the checked flag is true and server returns an error grid, then
  ** raise `haystack::CallErr`, otherwise return the grid itself.
  ** Result is returned as Grid.  Also see `haystack::Client.call`.
  @Axon { admin = true }
  static Grid haystackCall(Obj conn, Str op, Obj? req := null, Bool checked := true)
  {
    dispatch(curContext, conn, HxMsg("call", op, Unsafe(Etc.toGrid(req)), checked))
  }

  ** Perform Haystack HTTP API call to read a record by its unique
  ** identifier.  Return result as dict.  If the record is not found, then
  ** return null or raise UnknownRecErr based on checked flag.  Also
  ** see `haystack::Client.readById`.
  @Axon { admin = true }
  static Dict? haystackReadById(Obj conn, Obj id, Bool checked := true)
  {
    dispatch(curContext, conn, HxMsg("readById", id, checked))
  }

  ** Perform Haystack HTTP API call to read a list of records by their
  ** identifiers.  Return a grid where each row of the grid maps to the
  ** respective id list (indexes line up).  If checked is true and any one
  ** of the ids cannot be resolved then raise UnknownRecErr for first id not
  ** resolved.  If checked is false, then each id not found has a row
  ** where every cell is null.  Also see `haystack::Client.readByIds`.
  @Axon { admin = true }
  static Grid haystackReadByIds(Obj conn, Obj[] ids, Bool checked := true)
  {
    dispatch(curContext, conn, HxMsg("readByIds", ids, checked))
  }

  ** Perform Haystack REST API call to read single entity with filter.
  ** The filter is an expression like `readAll`.  Return result as dict.
  ** If the record is not found, then return null or raise UnknownRecErr
  ** based on checked flag.  Also see `haystack::Client.read`.
  @Axon { admin = true }
  static Dict? haystackRead(Expr conn, Expr filterExpr, Expr checked := Literal.trueVal)
  {
    cx     := curContext
    c      := conn.eval(cx)
    filter := filterExpr.evalToFilter(cx)
    check  := checked.eval(cx)
    return dispatch(cx, c, HxMsg("read", filter.toStr, check))
  }

  ** Perform Haystack REST API call to read all entities with filter.
  ** The filter is an expression like `readAll`.  Return results
  ** as grid.  Also see `haystack::Client.readAll`.
  @Axon { admin = true }
  static Grid haystackReadAll(Expr conn, Expr filterExpr)
  {
    cx := curContext
    c  := conn.eval(cx)
    filter := filterExpr.evalToFilter(cx)
    return dispatch(cx, c, HxMsg("readAll", filter.toStr))
  }

  ** Invoke a remote action on the given Haystack connector
  ** and remote entity.  The id must be a Ref of the remote entity's
  ** identifier and action is a Str action name.  If args are
  ** specified, then they should be a Dict keyed by parameter
  ** name.
  @Axon { admin = true }
  static Obj? haystackInvokeAction(Obj conn, Obj id, Str action, Dict? args := null)
  {
    dispatch(curContext, conn, HxMsg("invokeAction", id, action, args ?: Etc.emptyDict))
  }

  **
  ** Evaluate an Axon expression in a remote server over
  ** a haystack connector.  The remote server must be a SkySpark
  ** server which supports the "eval" REST op with an Axon
  ** expression.  This function blocks while the network request is
  ** made.  The result is always returned as a Grid using the same
  ** rules as `haystack::Etc.toGrid`.
  **
  ** The expression to evaluate in the remote server may capture
  ** variables from the local scope.  If these variables are atomic types,
  ** then they are captured as defined by local scope and serialized
  ** to the remote server.  Pass '{debug}' for opts to dump to stdout
  ** the actual expr with serialized scope.
  **
  ** Options:
  **   - 'debug': dumps full expr with seralized scope to stdout
  **   - 'evalTimeout': duration number to override remote project's
  **     default [evalTimeout]`docSkySpark::Tuning#folio`
  **
  ** Examples:
  **   read(haystackConn).haystackEval(3 + 4)
  **   read(haystackConn).haystackEval(readAll(site))
  **   read(haystackConn).haystackEval(readAll(kw).hisRead(yesterday))
  **
  @Axon { admin = true }
  static Obj? haystackEval(Expr conn, Expr expr, Expr opts := Literal.nullVal)
  {
    // evaluate arguments options
    cx := curContext
    c := conn.eval(cx)
    options := opts.eval(cx) as Dict ?: Etc.emptyDict

    // build do block with serialized vars in scope and expr itself
    exprStr := expr.toStr
    sb := StrBuf()
    sb.add("do\n")
    vars := cx.varsInScope
    vars.each |v, n|
    {
      if (!varInExpr(exprStr, n)) return
      ser := serializeVar(cx, v)
      if (ser === cannotSerialze) sb.add("  // $n: cannot serialize $v.typeof\n")
      else sb.add("  $n: $ser\n")
    }
    sb.add("  ").add(exprStr).add("\n")
    sb.add("end\n")
    s := sb.toStr

    // check for debug
    if (options.has("debug"))
    {
      echo("### haystackEval($conn)")
      echo(s)
    }

    // make the call
    return dispatch(cx, c, HxMsg("eval", s, options))
  }

  ** Quick and dirty way to tell if variable used in expression
  private static Bool varInExpr(Str expr, Str var)
  {
    i := expr.index(var)
    if (i == null) return false
    if (i > 0 && expr[i-1].isAlphaNum) return false
    if (i+var.size < expr.size)
    {
      after := expr[i+var.size]
      if (after.isAlphaNum || after == '(') return false
    }
    return true
  }


  private static Str serializeVar(HxContext cx, Obj? val)
  {
    try
    {
      if (val == null) return "null"
      if (val is Fn && ((Fn)val).requiredArity == 0) return serializeVar(cx, ((Fn)val).call(cx, Obj?[,]))
      if (val is DateSpan) return ((DateSpan)val).toCode
      if (val is Bool) return val.toStr
      if (val is Number) return val.toStr
      if (val is Str) return ((Str)val).toCode
      if (val is Uri) return ((Uri)val).toCode
      if (val is Date) return val.toStr
      if (val is Time) return val.toStr
    }
    catch (Err e) {}
    return cannotSerialze
  }

  private static const Str cannotSerialze := "_no_ser_"

  ** Dispatch a message to the given connector and return result
  private static Obj? dispatch(HxContext cx, Obj conn, HxMsg msg)
  {
    lib := (HaystackLib)cx.rt.lib("haystack")
    r := lib.conn(Etc.toId(conn)).sendSync(msg)
    if (r is Unsafe) return ((Unsafe)r).val
    return r
  }

  ** Current context
  private static HxContext curContext() { HxContext.curHx }

}