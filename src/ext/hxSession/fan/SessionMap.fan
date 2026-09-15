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

  ** Add the session to the map. The check function is invoked while
  ** holding the lock and may throw to reject the session before it is
  ** mapped, which makes the limit checks atomic with the add.
  UserSession add(UserSession session, |->| check)
  {
    username := session.username
    return sessionLock.withLock |->Obj?| {
      check()

      // map by key first since it is the only key that can collide; a
      // collision throws with other state untouched
      byKey.add(session.key, session)
      byId.add(session.id, session)
      userCounts.set(username, userCount(username)+1)
      return session
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

  ** Remove the session from the map. Return false if this session is not
  ** mapped, which means it was already closed.
  Bool remove(UserSession session)
  {
    username := session.username
    return sessionLock.withLock |->Obj?| {
      // only unmap and decrement if this exact session is still mapped
      if (byId.get(session.id) !== session) return false
      byId.remove(session.id)
      byKey.remove(session.key)

      // drop the count entry once the user has no sessions
      count := userCount(username) - 1
      if (count > 0) userCounts.set(username, count)
      else userCounts.remove(username)
      return true
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
