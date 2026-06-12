//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   08 Jun 2026  Matthew Giannini  Creation
//

using concurrent
using util
using web
using auth
using xeto
using haystack
using hx

**
** An authenticated user session
**
const class ServerSession : UserSession
{

//////////////////////////////////////////////////////////////////////////
// Constructor
//////////////////////////////////////////////////////////////////////////

  new make(SessionExt ext, User user, Dict meta)
  {
    this.extRef = ext
    this.created = DateTime.now
    this.id = meta.id
    this.key = meta["key"] ?: throw ArgErr("Session 'key' not specified")
    this.attestKey = meta["attestKey"] ?: throw ArgErr("Session 'attestKey' not specified")
    this.meta = normalize(meta)
    userRef.val = user
    touch(null)
  }

  private Dict normalize(Dict meta)
  {
    return meta
  }

  virtual SessionExt ext() { extRef }
  private const SessionExt extRef

//////////////////////////////////////////////////////////////////////////
// ServerSession
//////////////////////////////////////////////////////////////////////////

  override User user() { userRef.val }
  private const AtomicRef userRef := AtomicRef()

  override const Ref id

  override const Str key

  override const Str attestKey

  override const Dict meta

  override const DateTime created

  override Int touched() { touchedRef.val }

  override Void touch(User? user)
  {
    touchedRef.val = Duration.nowTicks
    if (user == null) return
    if (user.username != this.username)
      throw AuthErr("Cannot change session username from ${this.username} to ${user.username}")
    userRef.val = user
  }
  private const AtomicInt touchedRef := AtomicInt(0)

  override Duration lease()
  {
    val := meta["lease"]
    if (val is Duration) return val
    if (val is Number) return ((Number)val).toDuration
    return ext.lease(this)
  }

  override Bool isExpired(Duration now)
  {
    basis := this.touched
    if (meta.has("fixedLease")) basis = created.ticks
    return now.ticks - basis > this.lease.ticks
  }

//////////////////////////////////////////////////////////////////////////
// Util
//////////////////////////////////////////////////////////////////////////

  Bool isCluster() { meta.has("cluster") }
  Bool isWeb() { meta.has("web") }
}