//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   12 Jun 2026  Matthew Giannini  Creation
//

using concurrent
using xeto
using hx

**
** Data structrue for mapping user sessions by various keys
**
internal const class SessionMap
{
  new make()
  {
  }

  ** Lock to make session management atomic
  private const Lock sessionLock := Lock.makeReentrant

  ** Sessions mapped by Ref id
  private const ConcurrentMap byId := ConcurrentMap()

  ** Sessions mapped by session key
  private const ConcurrentMap byKey := ConcurrentMap()

  ** The number of sessions (Int) open for a user (keyed by username)
  private const ConcurrentMap userCounts := ConcurrentMap()

  UserSession add(UserSession session)
  {
    username := session.username
    return sessionLock.withLock |->Obj?| {
      try
      {
        userCounts.set(username, userCount(username)+1)
        byId.add(session.id, session)
        byKey.add(session.key, session)
        return session
      }
      catch (Err err)
      {
        remove(session)
        throw err
      }
    }
  }

  ServerSession? get(Str key, Bool checked := true)
  {
    s := byKey.get(key)
    if (s != null) return s
    if (checked) throw UnknownNameErr(key)
    return null
  }

  ServerSession? getById(Ref id, Bool checked := true)
  {
    s := byId.get(id)
    if (s != null) return s
    if (checked) throw UnknownNameErr("$id")
    return null
  }

  ServerSession[] list()  { byKey.vals(ServerSession#) }

  Void remove(UserSession session)
  {
    username := session.username
    sessionLock.withLock |->Obj?| {
      byId.remove(session.id)
      byKey.remove(session.key)
      userCounts.set(username, userCount(username)-1)
      return null
    }
  }

  ** The total number of sessions that are mapped
  Int size() { byKey.size }

  ** Get the number of sessions opened with this username
  Int userCount(Str username) { userCounts.get(username) ?: 0 }

  ** Iterate user count map
  Void userCountEach(|Str username, Int count| f)
  {
    userCounts.each |Int i, Str u| { f(u, i) }
  }
}
