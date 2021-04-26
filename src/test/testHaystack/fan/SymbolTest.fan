//
// Copyright (c) 2019, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   16 Jan 2019  Brian Frank  Creation
//

using haystack

**
** SymbolTest
**
@Js
class SymbolTest : HaystackTest
{
  Void testBasics()
  {
    tag      := SymbolType.tag
    conjunct := SymbolType.conjunct
    key      := SymbolType.key

    // tag
    verifySymbol("a",       "a",       tag,      Str[,])
    verifySymbol("foo",     "foo",     tag,      Str[,])
    verifySymbol("foo_bar", "foo_bar", tag,      Str[,])

    // conjunct
    verifySymbol("a-b",          "a-b",         conjunct, ["a", "b"])
    verifySymbol("a-b-c-d",      "a-b-c-d",     conjunct, ["a", "b", "c", "d"])
    verifySymbol("foo-bar-baz",  "foo-bar-baz", conjunct, ["foo", "bar", "baz"])
    verifySymbol("foo-x-baz",    "foo-x-baz",   conjunct, ["foo", "x", "baz"])
    verifySymbol("foo1-bar2",    "foo1-bar2",   conjunct, ["foo1", "bar2"])
    verifySymbol("foo_1-bar_2",  "foo_1-bar_2", conjunct, ["foo_1", "bar_2"])

    // key
    verifySymbol("a:b",    "b",  key, ["a", "b"])
    verifySymbol("lib:ph", "ph", key, ["lib", "ph"])

    // bad ones
    verifySymbolErr("",               "empty str")
    verifySymbolErr("a.b",            "compose symbols deprecated: _")
    verifySymbolErr("a-b.c",          "compose symbols deprecated: _")
    verifySymbolErr("lib:foo.bar_4",  "compose symbols deprecated: _")
    verifySymbolErr("a.Foo",          "compose symbols deprecated: _")
    verifySymbolErr("B",              "invalid start char: _")
    verifySymbolErr("Quick",          "invalid start char: _")
    verifySymbolErr("2a",             "invalid start char: _")
    verifySymbolErr("a b",            "invalid char ' ': _")
    verifySymbolErr("a/b",            "invalid char '/': _")
    verifySymbolErr("foo ",           "invalid char ' ': _")
    verifySymbolErr("a.b.c.",         "too many dots: _")
    verifySymbolErr("a:b:c.",         "too many colons: _")
    verifySymbolErr("a-b#",           "invalid char '#': _")
    verifySymbolErr("a--b",           "empty conjunct name: _")
    verifySymbolErr("a-7b",           "invalid conjunct name: _")
    verifySymbolErr("a-Boo",          "invalid conjunct name: _")
    verifySymbolErr("a:-b",           "invalid name part: _")
    verifySymbolErr("a-:b",           "invalid name part: _")
    verifySymbolErr("a:3b",           "invalid name part: _")
    verifySymbolErr("a:Foo",          "invalid name part: _")
  }

  Void verifySymbol(Str str, Str name, SymbolType type, Str[] parts)
  {
    x := Symbol(str)
    verifyEq(x, Symbol(str))
    verifyNotEq(x, Symbol(str+"foo"))
    verifyEq(x.name, name)
    verifySame(x.type, type)

    verifyEq(x.size, parts.size)
    parts.each |p, i| { verifyEq(x.part(i), p) }

    each := Str[,]
    x.eachPart |s| { each.add(s) }
    verifyEq(each, parts)

    parts.each |p|
    {
      verifyEq(x.hasTermName(p), x.type.isTerm)
    }
  }

  Void verifySymbolErr(Str str, Str msg)
  {
    if (msg[-1] == '_') msg = msg[0..-2] + str
    verifyEq(Symbol(str, false), null)
    verifyErrMsg(ParseErr#, msg) { x := Symbol(str) }
    verifyErrMsg(ParseErr#, msg) { x := Symbol(str, true) }
  }

}