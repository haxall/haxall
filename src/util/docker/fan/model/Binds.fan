//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   13 Oct 2021  Matthew Giannini  Creation
//

**************************************************************************
** Bind
**************************************************************************

const class Bind
{
  static new fromStr(Str s, Bool checked := true)
  {
    Err? cause := null
    try
    {
      parts := regex.split(s)
      if (parts.size == 2)
      {
        return Bind { it.src = parts[0]; it.dest = parts[1] }
      }
      else if (parts.size == 3)
      {
        nocopy := false
        ro := false
        parts[2].split(',').each |flag|
        {
          if ("nocopy" == flag) nocopy = true
          else if ("ro" == flag) ro = true
          // TODO: other flags
        }
        return Bind
        {
          it.src = parts[0]
          it.dest = parts[1]
          it.nocopy = nocopy
          it.ro = ro
        }
      }
    }
    catch (Err x) { cause = x }
    if (checked) throw ArgErr("Cannot parse Bind: ${s}", cause)
    return null
  }

  new make(|This| f)
  {
    f(this)
  }

  ** Regex to split the str encoding of a bind by ':' but not ':\' (Windows)
  private static const Regex regex := Regex.fromStr(":(?!\\\\)")

  ** The host source path (for bind mounts) or volume name (for named volumes)
  const Str src

  ** The container destination.
  const Str dest

  ** If set to true, disables automatic copying of data from the container path
  ** to the volume. Only applies to named volumes.
  const Bool nocopy := false

  ** If true, moutns a volume as read-only. By default, volumes are mounted read-write.
  const Bool ro := false

  // TODO: SELinux label
  // TODO: mount propagation behavior

  Str toJson() { toStr }

  override Str toStr()
  {
    buf := StrBuf().add("${src}:${dest}:")
    buf.add(ro ? "ro" : "rw")
    if (nocopy) buf.add(",nocopy")
    return buf.toStr
  }
}