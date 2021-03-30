//
// Copyright (c) 2019, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   9 Jan 2019  Brian Frank  Creation
//

using haystack

**
** CSymbol
**
const class CSymbol
{
  ** CSymbolFactory
  internal new make(Symbol val, CSymbol[] parts)
  {
    this.val = val
    this.parts = parts
  }

  ** Haystack value we wrap
  const Symbol val

  ** Symbol type
  SymbolType type() { val.type }

  ** Parts based on type:
  **   - tag: '[,]'
  **   - conjunct: '[foo, bar]'
  **   - compose: '[parent, child]'
  **   - key: '[feature, name]'
  const CSymbol[] parts

  ** Simple name
  Str name() { val.name }

  override Int hash() { toStr.hash }

  override Bool equals(Obj? that) { that is CSymbol && toStr == that.toStr }

  override Str toStr() { val.toStr }
}

**************************************************************************
** CSymbolFactory
**************************************************************************

internal class CSymbolFactory
{
  new make(InternFactory intern) { this.intern = intern }

  ** Create from Str value, raise ParseErr if invalid
  CSymbol parse(Str str)
  {
    symbol := cache[str]
    if (symbol != null) return symbol
    cache[str] = symbol = norm(Symbol(intern.makeId(str)))
    return symbol
  }

  ** Create from Symbol val, raise ParseErr if invalid
  CSymbol norm(Symbol val)
  {
    symbol := cache[val.toStr]
    if (symbol != null) return symbol
    cache[val.toStr] = symbol = doNorm(val)
    return symbol
  }

  private CSymbol doNorm(Symbol val)
  {
    switch (val.type)
    {
      case SymbolType.tag:      return CSymbol(val, CSymbol#.emptyList)
      case SymbolType.conjunct: return parseConjunct(val)
      case SymbolType.key:      return parseKey(val)
      default:                  throw ParseErr(val.toStr)
    }
  }

  private CSymbol parseKey(Symbol val)
  {
    CSymbol(val, [parseName(val.part(0)), parseName(val.part(1))])
  }

  private CSymbol parseTerm(Str val)
  {
    symbol := parse(val.toStr)
    if (symbol.type.isTerm) return symbol
    throw ParseErr("Invalid term $val.toStr.toCode within symbol")
  }

  private CSymbol parseConjunct(Symbol val)
  {
    parts := CSymbol[,]
    parts.capacity = val.size
    for (i := 0; i<val.size; ++i)
      parts.add(parseName(val.part(i)))
    return CSymbol(val, parts)
  }

  private CSymbol parseName(Str str)
  {
    if (!Etc.isTagName(str)) throw ParseErr("Invalid name $str.toCode within symbol")
    return parse(str)
  }

  private InternFactory intern
  private Str:CSymbol cache := [:]
}

