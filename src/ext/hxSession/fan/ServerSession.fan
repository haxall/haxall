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

  new make(SessionExt ext, User user, Str key, Str attestKey, Dict meta)
  {
    this.extRef    = ext
    userRef.val    = user
    this.id        = Ref.gen
    this.key       = key
    this.attestKey = attestKey
    this.meta      = normalize(meta)
    this.created   = DateTime.now
    touch(null)
  }

  private Dict normalize(Dict meta)
  {
    if (meta.has("key")) throw ArgErr("Session 'key' must not be in meta")
    if (meta.has("attestKey")) throw ArgErr("Session 'attestKey' must not be in meta")
    return meta
  }

  virtual SessionExt ext() { extRef }
  private const SessionExt extRef

//////////////////////////////////////////////////////////////////////////
// ServerSession
//////////////////////////////////////////////////////////////////////////

  override User user() { userRef.val }
  private const AtomicRef userRef := AtomicRef()

  override const Dict meta

  override const Ref id

  override const Str key

  override const Str attestKey

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
    basis := this.isFixedLease ? created.ticks : this.touched
    return now.ticks - basis > this.lease.ticks
  }
}