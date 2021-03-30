//
// Copyright (c) 2019, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   9 Jan 2019  Brian Frank  Creation
//

**
** Symbol is a name to a def in the meta-model namespace
**
@Js
abstract const class Symbol
{

  ** Return if given type is one my subclasses
  internal static Bool fits(Type type)
  {
    type === TagSymbol# ||
    type === ConjunctSymbol# ||
    type === KeySymbol#
  }

  ** Construct from string
  static new fromStr(Str s, Bool checked := true)
  {
    if (checked) return parse(s)

    try
      return parse(s)
    catch (Err e)
      return null
  }

  ** Internal parse factory
  internal static new parse(Str s)
  {
    if (s.isEmpty) throw ParseErr("empty str")
    if (!s[0].isLower) throw ParseErr("invalid start char: $s")
    colon := -1
    dot := -1
    dash := -1
    for (i := 0; i<s.size; ++i)
    {
      c := s[i]
      if (c == ':') { if (colon >= 0) throw ParseErr("too many colons: $s"); colon = i }
      else if (c == '.') { if (dot >= 0) throw ParseErr("too many dots: $s"); dot = i }
      else if (c == '-') { dash = i }
      else if (!isTagChar(c)) { throw ParseErr("invalid char " + c.toChar.toCode('\'') + ": " + s) }
    }
    if (dot > 0) throw ParseErr("compose symbols deprecated: " + s)
    if (colon > 0) return KeySymbol(s, substr(s, 0..<colon), substr(s, colon+1..-1))
    if (dash > 0) return ConjunctSymbol(s, s.split('-'))
    return TagSymbol(s)
  }

  private static Str substr(Str str, Range r)
  {
    sub := str[r]
    if (!sub[0].isLower || !isTagChar(sub[-1])) throw ParseErr("invalid name part: $str")
    return str[r]
  }

  private static Bool isTagChar(Int c) { c.isAlphaNum || c == '_' }

  ** Constructor for subclasses
  internal new make(Str str) { this.str = str }

  ** Simple name
  abstract Str name()

  ** Symbol type
  @NoDoc abstract SymbolType type()

  ** Return number of parts
  @NoDoc abstract Int size()

  ** Parts based on type:
  **   - tag: '[,]'
  **   - conjunct: '[hot, water, plant]'
  **   - compose: '[parent, child]'
  **   - key: '[feature, name]'
  @NoDoc abstract Str part(Int index)

  ** Iterate the parts based on type - see `part`
  @NoDoc abstract Void eachPart(|Str| f)

  ** Return if this is a term which contains the given simple tag name
  @NoDoc abstract Bool hasTermName(Str name)

  ** Return if this is a term and given dict implements all my part names.
  @NoDoc abstract Bool hasTerm(Dict dict)

  ** Hash code is based on string representation
  override Int hash() { str.hash }

  ** Equality is based on string representation
  override Bool equals(Obj? that) { that is Symbol && toStr == that.toStr }

  ** String representation
  override Str toStr() { str }

  ** Code representation with leading "^" caret.
  Str toCode() { StrBuf(1+str.size).addChar('^').add(str).toStr }

  ** Convert value to list of Symbols
  @NoDoc static Symbol[] toList(Obj? val)
  {
    if (val == null) return Symbol#.emptyList
    if (val is List) return val
    if (val is Symbol) return Symbol[val]
    throw ArgErr("Cannot convert to Symbol[]: $val.typeof")
  }

  ** Str representation
  internal const Str str
}

**************************************************************************
** SymbolType
**************************************************************************

** Symbol type
@NoDoc @Js
enum class SymbolType
{
  tag,
  conjunct,
  key

  ** Simple name like "water"
  Bool isTag() { this === tag }

  ** Compound name like "hot-water"
  Bool isConjunct() { this === conjunct }

  ** Tag or conjunct term
  Bool isTerm() { isTag || isConjunct }

  ** Feature key as "feature:name"
  Bool isKey() { this === key }
}

**************************************************************************
** TagSymbol
**************************************************************************

@Js
internal const class TagSymbol : Symbol
{
  new make(Str str) : super(str) {}

  override SymbolType type() { SymbolType.tag }

  override Str name() { str }

  override Int size() { 0 }

  override Str part(Int i) { throw UnsupportedErr(toStr) }

  override Void eachPart(|Str| f) {}

  override Bool hasTermName(Str name) { this.name == name }

  override Bool hasTerm(Dict dict) { dict.has(name) }
}

**************************************************************************
** ConjunctSymbol
**************************************************************************

@Js
internal const class ConjunctSymbol : Symbol
{
  new make(Str str, Str[] parts) : super(str)
  {
    for (i := 0; i<parts.size; ++i)
    {
      part := parts[i]
      if (part.isEmpty) throw ParseErr("empty conjunct name: $str")
      if (!part[0].isLower) throw ParseErr("invalid conjunct name: $str")
    }
    this.parts = parts
  }

  const Str[] parts

  override SymbolType type() { SymbolType.conjunct }

  override Str name() { str }

  override Int size() { parts.size }

  override Str part(Int i) { parts[i] }

  override Void eachPart(|Str| f) { parts.each(f) }

  override Bool hasTermName(Str name) { parts.contains(name) }

  override Bool hasTerm(Dict dict) { parts.all |p| { dict.has(p) } }

}

**************************************************************************
** KeySymbol
**************************************************************************

@Js
internal const class KeySymbol : Symbol
{
  new make(Str str, Str feature, Str name) : super(str)
  {
    this.feature = feature
    this.name = name
  }

  override SymbolType type() { SymbolType.key }

  const Str feature

  override const Str name

  override Int size() { 2 }

  override Str part(Int i)
  {
    if (i == 0) return feature
    if (i == 1) return name
    throw IndexErr("part($i): $this")
  }

  override Void eachPart(|Str| f)
  {
    f(feature)
    f(name)
  }

  override Bool hasTermName(Str name) { false }

  override Bool hasTerm(Dict dict) { false }
}