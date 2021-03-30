//
// Copyright (c) 2019, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   9 Jan 2019 Brian Frank  Creation
//

using haystack

**
** SymbolTest
**
class SymbolTest : Test
{
  internal CSymbolFactory? factory

  Void test()
  {
    Str? err := null
    f := CSymbolFactory(InternFactory())
    this.factory = f

    // foo
    foo := f.parse("foo")
    verifyName(foo, "foo")

    // bar
    bar := f.parse("bar")
    verifyName(bar, "bar")

    // foo-bar
    fooBar := f.parse("foo-bar")
    verifyConjunct(fooBar, "foo-bar", [foo, bar])

    // foo-bar-baz
    fooBarBaz := parse("foo-bar-baz")
    baz := parse("baz")
    verifyName(baz, "baz")
    verifyConjunct(fooBarBaz, "foo-bar-baz", [foo, bar, baz])

    // func:now
    funcNow := parse("func:now")
    func := parse("func")
    now := parse("now")
    verifyName(func, "func")
    verifyName(now, "now")
    verifyKey(funcNow, "func:now", [func, now])


    // elec-meter.import
    elec := parse("elec")
    meter := parse("meter")
    import := parse("import")
    elecMeter := parse("elec-meter")
    verifyName(elec, "elec")
    verifyName(meter, "meter")
    verifyName(import, "import")
    verifyConjunct(elecMeter, "elec-meter", [elec, meter])

    // bad ones
    verifySymbolErr("foo ")
    verifySymbolErr("foo-bar:baz")
    verifySymbolErr("foo:bar-baz")
    //verifySymbolErr("foo:bar.baz-roo")
    verifySymbolErr("foo.bar.baz")
    verifySymbolErr("foo-bar%-baz")
  }

  Void verifyName(CSymbol symbol, Str str)
  {
    verifySymbol(symbol, SymbolType.tag, str, CSymbol[,])
  }

  Void verifyConjunct(CSymbol symbol, Str str, CSymbol[] parts)
  {
    verifySymbol(symbol, SymbolType.conjunct, str, parts)
  }

  Void verifyKey(CSymbol symbol, Str str, CSymbol[] parts)
  {
    verifySymbol(symbol, SymbolType.key, str, parts)
  }

  Void verifySymbol(CSymbol symbol, SymbolType type, Str str, CSymbol[] parts)
  {
    verifyEq(symbol.toStr, str)
    verifySame(symbol.type,type)
    verifySame(factory.parse(str), symbol)
    verifyEq(symbol.parts.size, parts.size)
    symbol.parts.each |p, i| { verifySame(p, parts[i]) }
  }

  Void verifySymbolErr(Str s)
  {
    verifyErr(ParseErr#) { factory.parse(s) }
  }

  CSymbol parse(Str s)
  {
    factory.parse(s)
  }
}