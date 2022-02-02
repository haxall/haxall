//
// Copyright (c) 2012, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   22 Aug 2014  Andy Frank  Creation
//

using concurrent
using haystack
using hxConn
using [java]java.net
using [java]java.util
using [java]sedona.dasp

**
** SedonaScheme.
**
const abstract class SedonaScheme
{
  ** List available SedonaSchemes.
  static SedonaScheme[] schemes()
  {
    if (schemesRef.val == null)
    {
      types := Env.cur.index("hxSedona.scheme")
      schemesRef.val = types.map |t| { Type.find(t).make }.toImmutable
    }
    return schemesRef.val
  }

  ** URI scheme for this transport.
  abstract Str uriScheme()

  ** Get options or null for defaults.
  virtual Hashtable? options(Conn conn) { null }

  ** Create DaspSocket for this scheme.
  abstract DaspSocket createDaspSocket(Dict rec)

  ** Close DaspSocket for this scheme.
  abstract Void closeDaspSocket(DaspSocket s)

  ** Get Host InetAddress.
  abstract InetAddress inetAddress(Uri uri)

  ** Callback to perform a discovery.
  abstract Grid discover()

  private static const AtomicRef schemesRef := AtomicRef()
}

**************************************************************************
** DefaultSedonaScheme
**************************************************************************

internal const class DefaultSedonaScheme : SedonaScheme
{
  override const Str uriScheme := "sox"

  override DaspSocket createDaspSocket(Dict rec)
  {
    DaspSocket.open(-1, null, DaspSocket.SESSION_QUEUING)
  }

  override Void closeDaspSocket(DaspSocket s)
  {
    s.close
  }

  override InetAddress inetAddress(Uri uri)
  {
    InetAddress.getByName(uri.host)
  }

  override Grid discover()
  {
    Etc.makeEmptyGrid
  }
}