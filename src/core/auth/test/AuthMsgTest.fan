//
// Copyright (c) 2016, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   26 Apr 16  Brian Frank  Creation
//

using web

**
** AuthMsgTest
**
class AuthMsgTest : Test
{

//////////////////////////////////////////////////////////////////////////
// Encode/Decode
//////////////////////////////////////////////////////////////////////////

  Void testEncoding()
  {
    // basic identity
    verifyEq(AuthMsg("foo"), AuthMsg("foo"))
    verifyEq(AuthMsg("a x=y"), AuthMsg("a x=y"))
    verifyEq(AuthMsg("a i=j, x=y"), AuthMsg("a i=j, x=y"))
    verifyEq(AuthMsg("a i=j, x=y"), AuthMsg("a x=y ,i=j"))
    verifyNotEq(AuthMsg("foo"), AuthMsg("bar"))
    verifyNotEq(AuthMsg("foo"), AuthMsg("foo k=v"))

    // basics on fromStr
    q := AuthMsg("foo alpha=beta, gamma=delta")
    verifyEq(q.scheme, "foo")
    verifyEq(q.param("alpha"), "beta")
    verifyEq(q.param("Alpha"), "beta")
    verifyEq(q.param("ALPHA"), "beta")
    verifyEq(q.param("Gamma"), "delta")

    // fromStr parsing
    verifyEq(AuthMsg("foo alpha \t = \t beta"), AuthMsg("foo", ["alpha":"beta"]))
    verifyEq(AuthMsg("foo a=b, c = d, e=f, g=h"), AuthMsg("foo", ["a":"b", "c":"d", "e":"f", "g":"h"]))
    verifyEq(AuthMsg("foo a=b, c = d, e=f, g=h"), AuthMsg("foo", ["g":"h", "e":"f", "c":"d", "a":"b"]))
    verifyEq(AuthMsg("foo g=h, c = d, e=f,  a = b").toStr, "foo a=b, c=d, e=f, g=h")

    // test some various chars
    verifyEncoding(["salt":"abc012", "hash":"sha-1"])
    verifyEncoding(["salt":"azAZ09!#\$%&'*+-.^_`~", "hash":"sha-1", "foo":"bar"])

    // errors
    verifyErr(Err#) { x := AuthMsg("hmac", ["salt":"a=b", "hash":"sha-1"]) }
    verifyErr(Err#) { x := AuthMsg("hmac", ["salt":"abc", "hash":"sha-1", "bad/key":"val"]) }
    verifyErr(Err#) { x := AuthMsg("(bad)", Str:Str[:]) }
    verifyErr(Err#) { x := AuthMsg("ok", ["key":"val not good"]) }
    verifyErr(Err#) { x := AuthMsg("ok", ["key not good":"val"]) }
    verifyErr(ParseErr#) { x := AuthMsg.fromStr("(bad)") }
    verifyErr(ParseErr#) { x := AuthMsg.fromStr("hmac foo") }
    verifyErr(ParseErr#) { x := AuthMsg.fromStr("hmac foo=bar xxx") }
  }

  Void verifyEncoding(Str:Str params)
  {
    a := AuthMsg("hmac", params)
    verifyEq(a.scheme, "hmac")
    verifyEq(a.params, params)
    verifySame(a.toStr, a.toStr)

    b := AuthMsg.fromStr(a.toStr)
    verifyEq(b.scheme, "hmac")
    verifyEq(b.params, params)
    verifyEq(a, b)
  }

//////////////////////////////////////////////////////////////////////////
// Split List
//////////////////////////////////////////////////////////////////////////

  Void testSplitList()
  {
    verifySplitList("a,b", ["a", "b"])
    verifySplitList("a \t,  b", ["a", "b"])
    verifySplitList("a, b, c", ["a", "b", "c"])
    verifySplitList("a b=c", ["a b=c"])
    verifySplitList("a b=c, d=e", ["a b=c,d=e"])
    verifySplitList("a b=c, d=e \t,\t f=g", ["a b=c,d=e,f=g"])
    verifySplitList("a b=c, d=e, f g=h", ["a b=c,d=e", "f g=h"])
    verifySplitList("a b=c, d=e, f, g h=i,j=k", ["a b=c,d=e", "f", "g h=i,j=k"])
  }

  Void verifySplitList(Str s, Str[] expected)
  {
    verifyEq(AuthMsg.splitList(s), expected)
    msgs := AuthMsg.listFromStr(s)
    verifyEq(msgs.size, expected.size)
  }

//////////////////////////////////////////////////////////////////////////
// ListFromStr
//////////////////////////////////////////////////////////////////////////

  Void testListFromStr()
  {
    a := AuthMsg("hmac", HmacScheme.gen)
    b := AuthMsg("hmac", HmacScheme.gen)
    c := AuthMsg("hmac", HmacScheme.gen)
    verifyNotEq(a, b)
    verifyNotEq(a, c)

    verifyListFromStr("$a", [a])
    verifyListFromStr("$a,$b", [a, b])
    verifyListFromStr("$a , $b \t,\t $c", [a, b, c])
  }

  Void verifyListFromStr(Str s, AuthMsg[] expected)
  {
    actual := AuthMsg.listFromStr(s)
    verifyEq(actual.size, expected.size)
    actual.each |a, i|
    {
      verifyEq(a, expected[i])
    }

  }

}