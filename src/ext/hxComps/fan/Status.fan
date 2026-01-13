//
// Copyright (c) 2024, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   9 Sep 2024  Brian Frank  Creation
//

using xeto
using haystack

**
** Status flags
**
const mixin Status : Dict
{

//////////////////////////////////////////////////////////////////////////
// Construction
//////////////////////////////////////////////////////////////////////////

  ** Get the ok status with no flags set
  static Status ok() { MStatus.empty }

  ** Instance with alarm flag set
  static Status alarm() { MStatus.make(MStatus.flagAlarm) }

  ** Instance with disabled flag set
  static Status disabled() { MStatus.make(MStatus.flagDisabled) }

  ** Instance with down flag set
  static Status down() { MStatus.make(MStatus.flagDown) }

  ** Instance with fault flag set
  static Status fault() { MStatus.make(MStatus.flagFault) }

  ** Instance with overridden flag set
  static Status overridden() { MStatus.make(MStatus.flagOverridden) }

  ** Instance with stale flag set
  static Status stale() { MStatus.make(MStatus.flagStale) }

  ** Instance with  flag set
  static Status unacked() { MStatus.make(MStatus.flagUnacked) }

  ** Get an instance by name
  static Status? fromName(Str name, Bool checked := true)
  {
    s := MStatus.byName[name]
    if (s != null) return s
    if (checked) throw UnknownNameErr("Status: $name")
    return null
  }

  ** Map curStatus tags to status flags
  static Status fromCurStatus(Str? curStatus)
  {
    MStatus.byCurStatus[curStatus ?: "fault"] ?: fault
  }

  ** Parse a comma-separated list of status flags
  static Status fromStr(Str flags)
  {
    status := Status.ok
    if (flags.trim.isEmpty) return status
    flags.split(',').each |flag|
    {
      if (flag == "ok") return
      status = status.merge(Status.fromName(flag))
    }
    return status
  }

//////////////////////////////////////////////////////////////////////////
// Flags
//////////////////////////////////////////////////////////////////////////

  ** In the ok state with no other flags set
  abstract Bool isOk()

  ** In an alarm state
  abstract Bool isAlarm()

  ** Disabled state
  abstract Bool isDisabled()

  ** Network or communication error state
  abstract Bool isDown()

  ** Configuration or hardware error state
  abstract Bool isFault()

  **  Manual override state
  abstract Bool isOverridden()

  ** Data is not fresh
  abstract Bool isStale()

  ** Alarm has not been acknowledged
  abstract Bool isUnacked()

  ** Return true if none of the following status flags are set:
  **   disabled,down,fault,stale
  abstract Bool isValid()

//////////////////////////////////////////////////////////////////////////
// Mutation
//////////////////////////////////////////////////////////////////////////

  ** Merge all this instance flags with the given instances flags.
  Status set(Status that) { MStatus.make(this.flags.or(that.flags)) }

  ** Clear this instance flags with the given instances flags
  Status clear(Status that) {MStatus.make(this.flags.and(that.flags.not)) }

  ** Merge flags together for combination operations. If 'that' is null,
  ** return 'this'
  Status merge(Status? that) { MStatus.doMerge(this, that) }

  ** Get a new status where only the given flags are set
  Status only(Status that) { MStatus.make(this.flags.and(that.flags)) }

  ** Bitmask flags
  internal abstract Int flags()
}

**************************************************************************
** MStatus
**************************************************************************

** Status implementation
@NoDoc
const final class MStatus : Status
{

//////////////////////////////////////////////////////////////////////////
// Factory
//////////////////////////////////////////////////////////////////////////

  static new fromDict(Dict d)
  {
    mask := 0
    d.each |v, n|
    {
      if (v === Marker.val)
      {
        s := byName[n]
        if (s != null) mask = mask.or(s.flags)
      }
    }
    return byMask[mask]
  }

//////////////////////////////////////////////////////////////////////////
// Status
//////////////////////////////////////////////////////////////////////////

  override Bool isOk()         { flags == 0 }
  override Bool isAlarm()      { flags.and(flagAlarm) != 0 }
  override Bool isDisabled()   { flags.and(flagDisabled) != 0 }
  override Bool isDown()       { flags.and(flagDown) != 0 }
  override Bool isFault()      { flags.and(flagFault) != 0 }
  override Bool isOverridden() { flags.and(flagOverridden) != 0 }
  override Bool isStale()      { flags.and(flagStale) != 0 }
  override Bool isUnacked()    { flags.and(flagUnacked) != 0 }
  override Bool isValid()      { flags.and(invalidMask) == 0 }

  const override Int flags

  static const Str[] names :=
    ["alarm", "disabled", "down", "fault", "overridden", "stale", "unacked"]

//////////////////////////////////////////////////////////////////////////
// Obj
//////////////////////////////////////////////////////////////////////////

  override Bool equals(Obj? that) { this === that }

  override Int hash() { flags }

  override Int compare(Obj that) { flags <=> ((MStatus)that).flags }

  override Str toStr()
  {
    if (isOk) return "ok"
    sb := StrBuf()
    if (isAlarm) sb.add("alarm,")
    if (isDisabled) sb.add("disabled,")
    if (isDown) sb.add("down,")
    if (isFault) sb.add("fault,")
    if (isOverridden) sb.add("overridden,")
    if (isStale) sb.add("stale,")
    if (isUnacked) sb.add("unacked,")
    return sb[0..<-1]
  }

//////////////////////////////////////////////////////////////////////////
// Dict
//////////////////////////////////////////////////////////////////////////

  override Bool isEmpty() { false }

  @Operator override Obj? get(Str name)
  {
    if (name == "spec")       return specRef
    if (name == "alarm")      return toMarker(isAlarm)
    if (name == "disabled")   return toMarker(isDisabled)
    if (name == "down")       return toMarker(isDown)
    if (name == "fault")      return toMarker(isFault)
    if (name == "overridden") return toMarker(isOverridden)
    if (name == "stale")      return toMarker(isStale)
    if (name == "unacked")    return toMarker(isUnacked)
    return null
  }

  static Obj? toMarker(Bool set) { set ? Marker.val : null }

  override Bool has(Str name)
  {
    get(name) != null
  }

  override Bool missing(Str name)
  {
    get(name) == null
  }

  override Void each(|Obj, Str| f)
  {
    if (isAlarm)      f(Marker.val, "alarm")
    if (isDisabled)   f(Marker.val, "disabled")
    if (isDown)       f(Marker.val, "down")
    if (isFault)      f(Marker.val, "fault")
    if (isOverridden) f(Marker.val, "overridden")
    if (isStale)      f(Marker.val, "stale")
    if (isUnacked)    f(Marker.val, "unacked")
    f(specRef, "spec")
  }

  override Obj? eachWhile(|Obj,Str->Obj?| f)
  {
    if (isAlarm)      { r := f(Marker.val, "alarm");      if (r != null) return r }
    if (isDown)       { r := f(Marker.val, "down");       if (r != null) return r }
    if (isDisabled)   { r := f(Marker.val, "disabled");   if (r != null) return r }
    if (isFault)      { r := f(Marker.val, "fault");      if (r != null) return r }
    if (isOverridden) { r := f(Marker.val, "overridden"); if (r != null) return r }
    if (isStale)      { r := f(Marker.val, "stale");      if (r != null) return r }
    if (isUnacked)    { r := f(Marker.val, "unacked");    if (r != null) return r }
    return f(specRef, "spec")
  }

  override Obj? trap(Str n, Obj?[]? a := null)
  {
    v := get(n)
    if (v != null) return v
    throw UnknownNameErr(n)
  }

//////////////////////////////////////////////////////////////////////////
// Merge
//////////////////////////////////////////////////////////////////////////

  static Status doMerge(Status a, Status? b) { b == null ? a : a.set(b) }

//////////////////////////////////////////////////////////////////////////
// Constants
//////////////////////////////////////////////////////////////////////////

  const static Ref specRef := Ref("hx.comps::Status")

  static const Int flagAlarm      := 0x01
  static const Int flagDisabled   := 0x02
  static const Int flagDown       := 0x04
  static const Int flagFault      := 0x08
  static const Int flagOverridden := 0x10
  static const Int flagStale      := 0x20
  static const Int flagUnacked    := 0x40

  ** If a status mask has any of these bits set, then the status
  ** is considered "invalid"
  private static const Int invalidMask :=
    flagDisabled.or(flagDown).or(flagFault).or(flagStale)

//////////////////////////////////////////////////////////////////////////
// Instances
//////////////////////////////////////////////////////////////////////////

  static new make(Int flags) { byMask[flags] }

  internal static const MStatus[] byMask
  internal static const MStatus empty
  static
  {
    acc := MStatus[,]
    (0x7F+1).times |flags|
    {
      acc.add(doMake(flags))
    }

    byMask = acc
    empty = acc[0]
  }

  internal static const Str:MStatus byName
  static
  {
    acc := Str:Status[:]
    acc["alarm"]      = byMask[flagAlarm]
    acc["disabled"]   = byMask[flagDisabled]
    acc["down"]       = byMask[flagDown]
    acc["fault"]      = byMask[flagFault]
    acc["overridden"] = byMask[flagOverridden]
    acc["stale"]      = byMask[flagStale]
    acc["unacked"]    = byMask[flagUnacked]
    byName = acc
  }

  internal static const Str:MStatus byCurStatus
  static
  {
    acc := Str:Status[:]
    acc["ok"]             = byMask[0]
    acc["disabled"]       = byMask[flagDisabled]
    acc["down"]           = byMask[flagDown]
    acc["unknown"]        = byMask[flagDown]
    acc["fault"]          = byMask[flagFault]
    acc["stale"]          = byMask[flagStale]
    acc["remoteDown"]     = byMask[flagDown]
    acc["remoteDisabled"] = byMask[flagDisabled]
    acc["remoteFault"]    = byMask[flagFault]
    acc["remoteUnknown"]  = byMask[flagDown]
    byCurStatus = acc
  }

  private new doMake(Int flags) { this.flags = flags }
}

