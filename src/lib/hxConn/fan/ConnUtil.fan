//
// Copyright (c) 2022, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   14 Jan 2022  Brian Frank  Creation
//

using haystack
using hx

**
** Connector framework utilities
**
@NoDoc
const final class ConnUtil
{
  ** Given list of point ids, group them by conn invoke callback function.
  ** Note this method does not filter out duplictes if the same id is passed.
  static Void eachConnInPointIds(HxRuntime rt, Ref[] pointIds, |Conn, ConnPoint[]| f)
  {
    service := rt.conn
    if (pointIds.isEmpty) return

    // map point ids to ConnPoint instances
    acc := ConnPoint[,]
    acc.capacity = pointIds.size
    sameConn := true
    pointIds.each |id|
    {
      pt := service.point(id)
      acc.add(pt)
      if (acc.first.conn !== pt.conn) sameConn = false
      return null
    }

    // if all the points have same conn, then invoke callback and we are done
    if (sameConn)
    {
      f(acc.first.conn, acc)
      return
    }

    // need to do it the hard way
    connsById := Ref:Conn[:]
    acc.each |pt| { connsById[pt.conn.id] = pt.conn }
    connsById.each |conn|
    {
      pointsForConn := acc.findAll |pt| { pt.conn === conn }
      f(pointsForConn.first.conn, pointsForConn)
    }
  }
}