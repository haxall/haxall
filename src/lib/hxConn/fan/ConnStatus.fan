//
// Copyright (c) 2012, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   14 May 12  Brian Frank  Creation
//

using inet
using haystack

**
** ConnStatus enumeration.  This is a unified status value
** that incorporates `connStatus`, `curStatus`, `writeStatus`
** and `hisStatus`.  We do not model hisStatus pending/syncing.
**
enum class ConnStatus
{
  unknown,
  ok,
  stale,
  down,
  fault,
  disabled,
  remoteUnknown,
  remoteDown,
  remoteFault,
  remoteDisabled

  ** Is the `unknown` instance
  Bool isUnknown() { this === unknown }

  ** Is the `ok` instance
  Bool isOk() { this === ok }

  ** Is the `disabled` instance
  Bool isDisabled() { this === disabled }

  ** Return if this is not `isRemote`
  Bool isLocal() { remoteToLocal == null }

  ** Is this is a remote status
  Bool isRemote() { remoteToLocal != null }

  ** Convert remoteFault -> fault
  @NoDoc ConnStatus? remoteToLocal()
  {
    switch (this)
    {
      case remoteUnknown:  return unknown
      case remoteDown:     return down
      case remoteFault:    return fault
      case remoteDisabled: return disabled
      default:             return null
    }
  }

  ** Convert fault -> remoteFault
  @NoDoc ConnStatus? localToRemote()
  {
    switch (this)
    {
      case unknown:  return remoteUnknown
      case down:     return remoteDown
      case fault:    return remoteFault
      case disabled: return remoteDisabled
      default:       return null
    }
  }

  internal static ConnStatus fromErr(Err e)
  {
    if (e is IOErr)
    {
      if (e.msg.contains("Connection refused") ||
          e.msg.contains("timed out"))
        return down
    }
    else if (e is RemoteStatusErr)
    {
      s := ((RemoteStatusErr)e).status
      if (s.isRemote) return s
      return s.localToRemote ?: remoteUnknown
    }
    return e is DownErr ? down : fault
  }

  internal static Str toErrStr(Err err)
  {
    if (err is FaultErr) return err.msg
    if (err is DownErr) return err.msg
    if (err is RemoteStatusErr) return "Remote status err: $err.msg"
    if (err is UnknownHostErr) return "Unknown host: $err.msg"
    if (err.msg.startsWith("java.net.UnknownHostException:")) return "Unknown host" + err.msg[err.msg.index(":")..-1]
    return err.toStr
  }

}

