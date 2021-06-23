//
// Copyright (c) 2012, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   14 May 2012  Brian Frank  Creation
//   22 Jun 2021  Brian Frank  Redesign for Haxall
//

using haystack
using hx

@Js
const final class ConnModel
{

  ** Construct with extension pod
  @NoDoc new make(Namespace ns, Lib lib)
  {
    this.name = lib.name
    prefix := name.startsWith("hx") ? name[2..-1].decapitalize : name

    // check tag/func defs
    this.connTag       = def(ns, lib, "${prefix}Conn")
    this.connRefTag    = def(ns, lib, "${prefix}ConnRef")
    this.curTag        = def(ns, lib, "${prefix}Cur", false)
    this.writeTag      = def(ns, lib, "${prefix}Write", false)
    this.writeLevelTag = def(ns, lib, "${prefix}WriteLevel", false)
    this.hisTag        = def(ns, lib, "${prefix}His", false)
    this.pingFunc      = def(ns, lib, "func:${prefix}Ping")
    this.discoverFunc  = def(ns, lib, "func:${prefix}Discover", false)
    this.learnFunc     = def(ns, lib, "func:${prefix}Learn", false)
    this.syncCurFunc   = def(ns, lib, "func:${prefix}SyncCur", false)
    this.syncHisFunc   = def(ns, lib, "func:${prefix}SyncHis", false)

    // dict for misc
    misc := Str:Obj[:]
    misc["name"] = name
    if (hasCur)   misc["cur"]   = Marker.val
    if (hasHis)   misc["his"]   = Marker.val
    if (hasWrite) misc["write"] = Marker.val
    if (hasLearn) misc["learn"] = Marker.val
    this.misc = Etc.makeDict(misc)
  }

  private static Str? def(Namespace ns, Lib lib, Str symbol, Bool checked := true)
  {
    def := ns.def(symbol, false)
    if (def == null)
    {
      if (checked) throw Err("Missing required def: $symbol")
      return null
    }
    if (def.lib !== lib) throw Err("Def in wrong lib: $symbol [$def.lib != $lib]")
    return def.name
  }

//////////////////////////////////////////////////////////////////////////
// Identity
//////////////////////////////////////////////////////////////////////////

  ** Name of the connector such as "foo"
  const Str name

  ** Tag name of the connector such as "fooConn"
  const Str connTag

  ** Tag name of the connector reference such as "fooConnRef"
  const Str connRefTag

  ** Tag name of point's current address such as "fooCur"
  const Str? curTag

  ** Tag name of point's write address such as "fooWrite"
  const Str? writeTag

  ** Tag name if connector requires level for pushing write to remote system (bacnet, haystack)
  const Str? writeLevelTag

  ** Tag name of point's history address such as "fooHis"
  const Str? hisTag

  ** Func name of ping such as "fooPing"
  const Str pingFunc

  ** Func name of connecotry discovery such as "fooDiscover"
  const Str? discoverFunc

  ** Func name of point learn such as "fooLearn"
  const Str? learnFunc

  ** Func name to perform one-time current sync
  const Str? syncCurFunc

  ** Func name to perform history sync
  const Str? syncHisFunc

  ** Polling strategy to use
  const PollingMode pollingMode := PollingMode.disabled

  ** Encoding for SysNamespace misc entry
  @NoDoc const Dict misc

//////////////////////////////////////////////////////////////////////////
// Support
//////////////////////////////////////////////////////////////////////////

  ** Does this connector support connector/device discovery such as "fooDiscover"
  Bool hasDiscover() { discoverFunc != null }

  ** Does this connector support learn such as "fooLearn"
  Bool hasLearn() { learnFunc != null }

  ** Does this connector support current value subscription
  Bool hasCur() { curTag != null }

  ** Does this connector support writable points
  Bool hasWrite() { writeTag != null }

  ** Does this connector support history synchronization
  Bool hasHis() { hisTag != null }
}

**************************************************************************
** PollingMode
**************************************************************************

**
** The polling modes supported by the connector framework
**
@Js
enum class PollingMode
{
  ** Disable polling
  disabled,

  ** The connector implementation must handle all polling logic
  manual,

  ** The connector framework handles the polling logic and utilizes
  ** a "poll buckets" strategy.
  buckets

  ** Return 'true' if the mode is not `disabled`.
  Bool isPollingEnabled() { this !== disabled }
}


