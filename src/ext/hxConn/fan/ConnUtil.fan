//
// Copyright (c) 2022, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   14 Jan 2022  Brian Frank  Creation
//

using xeto
using haystack
using hx

**
** Connector framework utilities
**
@NoDoc
const final class ConnUtil
{
  ** Convert ext name such as "hx.haystack" to model name "haystack"
  static Str modelName(Ext ext)
  {
    if (ext.name == "hx.test.conn") return "connTest"
    if (ext.name == "hx.energystar") return "energyStar"
    return ext.name.split('.').last
  }

  ** Fast intern level integer to number
  static Number levelToNumber(Int level) { levels[level] }
  private static const Number[] levels
  static
  {
    acc := Number[,]
    18.times |i| { acc.add(Number(i)) }
    levels = acc
  }

  ** Given list of point ids, group them by conn invoke callback function.
  ** Note this method does not filter out duplictes if the same id is passed.
  static Void eachConnInPointIds(Proj rt, ConnPoint[] points, |Conn, ConnPoint[]| f)
  {
    if (points.isEmpty) return

    // check if the same conn (common case)
    sameConn := true
    points.each |pt|
    {
      if (points.first.conn !== pt.conn) sameConn = false
    }

    // if all the points have same conn, then invoke callback and we are done
    if (sameConn)
    {
      f(points.first.conn, points)
      return
    }

    // need to do it the hard way
    connsById := Ref:Conn[:]
    points.each |pt| { connsById[pt.conn.id] = pt.conn }
    connsById.each |conn|
    {
      pointsForConn := points.findAll |pt| { pt.conn === conn }
      f(pointsForConn.first.conn, pointsForConn)
    }
  }
}

