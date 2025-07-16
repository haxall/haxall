//
// Copyright (c) 2024, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   16 Jul 2025  Brian Frank  Creation
//

using xeto
using haystack
using hx

**
** WatchTest
**
class UtilTest : HxTest
{

  Void testProjName()
  {
    badTag := "Project name not valid tag name"
    tooShort := "Project name too short"
    tooLong  := "Project name too long"
    reserved := "Project name reserved"

    verifyProjName("",        tooShort)
    verifyProjName("a",       tooShort)
    verifyProjName("ab",      tooShort)
    verifyProjName("abc",     tooShort)
    verifyProjName("abcd",    null)
    verifyProjName("fooBar4", null)
    verifyProjName("x"*62,    null)
    verifyProjName("x"*63,    tooLong)

    verifyProjName("abCd", null)
    verifyProjName("-acd", badTag)
    verifyProjName("acd-", badTag)
    verifyProjName("3bcd", badTag)
    verifyProjName("Abcd", badTag)
    verifyProjName("abcD", null)
    verifyProjName("a3b4", null)
    verifyProjName("ab d", badTag)
    verifyProjName("ab:d", badTag)

    verifyProjName("folio", reserved)
    verifyProjName("skyspark", reserved)
  }

  Void verifyProjName(Str n, Str? expect)
  {
    msg := HxUtil.checkProjNameErr(n)
    // echo("-- $n | $msg")
    verifyEq(msg, expect)
    if (expect == null) HxUtil.checkProjName(n)
    else verifyErr(ArgErr#) { HxUtil.checkProjName(n) }
  }
}

