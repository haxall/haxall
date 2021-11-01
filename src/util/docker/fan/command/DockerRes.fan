//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   12 Oct 2021  Matthew Giannini  Creation
//

using util

**************************************************************************
** StatusRes
**************************************************************************

**
** A Docker status code response
**

const class StatusRes
{
  static const StatusRes noErr := StatusRes(204, "no error")

  internal new makeHttpRes(DockerHttpRes res, Str? msg := null)
    : this.make(res.statusCode, msg ?: res.statusMsg)
  {
  }

  internal new make(Int statusCode, Str msg)
  {
    this.statusCode = statusCode
    this.msg = msg
  }

  const Int statusCode

  const Str msg

  Bool isOk() { !isErr }

  Bool isErr() { statusCode >= 400 && statusCode <= 599 }

  This throwIfErr()
  {
    if (isErr) throw DockerResErr(statusCode, msg)
    return this
  }

  override Bool equals(Obj? obj)
  {
    if (this === obj) return true
    that := obj as StatusRes
    if (that == null) return false
    if (statusCode != that.statusCode) return false
    // msg is not considered
    return true
  }

  override Int hash()
  {
    res := 31 + statusCode
    return res
  }

  override Str toStr()
  {
    "${statusCode}: ${msg}"
  }
}

**************************************************************************
** DockerRes
**************************************************************************

**
** Base class for all Docker response objects decoded from JSON
**
const abstract class DockerObj
{
  new make(|This| f)
  {
    f(this)
  }

  ** The raw JSON string returned in HTTP response
  const Map rawJson

  override Str toStr() { JsonOutStream.writeJsonToStr(rawJson) }
}