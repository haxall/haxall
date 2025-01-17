//
// Copyright (c) 2009, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   3 Jan 2009  Brian Frank  Creation
//   9 Jun 2009  Brian Frank  Refactor for new tag design
//  24 Aug 2009  Brian Frank  Rename Query => Filter
//   4 Oct 2009  Brian Frank  Integrate into Axon
//  19 Feb 2016  Brian Frank  Move to haystack, remove Axon dependency
//

**
** Filter models a declarative predicate for selecting dicts.
** See `docHaystack::Filters` for details.
**
@Js
const abstract class Filter
{

//////////////////////////////////////////////////////////////////////////
// Factories
//////////////////////////////////////////////////////////////////////////

  ** Match records which have the specified path defined.
  @NoDoc static Filter has(Obj path) { FilterHas(FilterPath.fromObj(path)) }

  ** Match records which do not define the specified path.
  @NoDoc static Filter missing(Obj path) { FilterMissing(FilterPath.fromObj(path)) }

  ** Match records which have a tag equal to the specified value.
  ** If the path is not defined then it is unmatched.
  @NoDoc static Filter eq(Obj path, Obj val) { FilterEq(FilterPath.fromObj(path), val) }

  ** Match records which have a tag not equal to the specified value.
  ** If the path is not defined then it is unmatched.
  @NoDoc static Filter ne(Obj path, Obj val) { FilterNe(FilterPath.fromObj(path), val) }

  ** Match records which have tags less than the specified value.
  ** If the path is not defined then it is unmatched.
  @NoDoc static Filter lt(Obj path, Obj val) { FilterLt(FilterPath.fromObj(path), val) }

  ** Match records which have tags less than or equals to specified value.
  ** If the path is not defined then it is unmatched.
  @NoDoc static Filter le(Obj path, Obj val) { FilterLe(FilterPath.fromObj(path), val) }

  ** Match records which have tags greater than specified value.
  ** If the path is not defined then it is unmatched.
  @NoDoc static Filter gt(Obj path, Obj val) { FilterGt(FilterPath.fromObj(path), val) }

  ** Match records which have tags greater than or equal to specified value.
  ** If the path is not defined then it is unmatched.
  @NoDoc static Filter ge(Obj path, Obj val) { FilterGe(FilterPath.fromObj(path), val) }

  ** Return a query which is the logical-and of this and that query.
  @NoDoc Filter and(Filter that) { logic(this, FilterType.and, that) |a,b| { FilterAnd(a,b) } }

  ** Return a query which is the logical-or of this and that query.
  @NoDoc Filter or(Filter that) { logic(this, FilterType.or, that) |a,b| { FilterOr(a,b) } }

  ** Match records which nominally is an instance of the given spec name
  @NoDoc static Filter isSpec(Str spec) { FilterIsSpec(spec) }

  ** Match records which define the symbol terms or subtypes the given definition
  @NoDoc static Filter isSymbol(Symbol symbol) { FilterIsSymbol(symbol) }

  ** This factory method is used for and/or to ensure that we
  ** normalize all the logical query parts consistently by order.
  private static Filter logic(Filter a, FilterType op, Filter b, |Filter,Filter->Filter| f)
  {
    // if not a deep and/or, then sort a/b and return
    if (a.type !== op && b.type !== op)
    {
      if (a > b) { temp := a; a = b; b = temp }
      return f(a, b)
    }

    // gather all the and/or parts with a deep recursion,
    // and sort them so we have a normalized order
    parts := Filter[,]
    logicFind(parts, op, a)
    logicFind(parts, op, b)
    parts.sort

    // rebuild the and/or tree
    q := parts[0]
    for (i:=1; i<parts.size; ++i) q = f(q, parts[i])
    return q
  }

  private static Void logicFind(Filter[] parts, FilterType op, Filter x)
  {
    if (x.type !== op) { parts.add(x); return }
    logicFind(parts, op, x.argA)
    logicFind(parts, op, x.argB)
  }

  ** Create a search filter (not specified by Haystack):
  **   - "re:xxx": search using regex
  **   - "f:xxx": search as filter
  **   - "xxx": case insensitive glob with ? and * wildcards
  @NoDoc static Filter search(Str pattern)
  {
    try
    {
      if (pattern.startsWith("re:")) return RegexSearchFilter(pattern)
      if (pattern.startsWith("f:"))  return FilterSearchFilter(pattern)
    }
    catch (Err e) {}
    return GlobSearchFilter(pattern)
  }

  ** Create search filter from the standard 'search' option.
  @NoDoc static Filter? searchFromOpts(Dict? opts)
  {
    pattern := (opts?.get("search") as Str ?: "").trim
    if (pattern.isEmpty) return null
    return search(pattern)
  }

//////////////////////////////////////////////////////////////////////////
// Parse
//////////////////////////////////////////////////////////////////////////

  ** Parse a query from string - see `docHaystack::Filters` for format.
  ** If the query cannot be parsed then return null or throw
  ** ParseErr with location of error.
  static new fromStr(Str s, Bool checked := true)
  {
    try
    {
      return FilterParser(s).parse
    }
    catch (ParseErr e)
    {
      if (checked) throw e
      return null
    }
    catch (Err e)
    {
      if (checked) throw ParseErr(s, e)
      return null
    }
  }

//////////////////////////////////////////////////////////////////////////
// Identity
//////////////////////////////////////////////////////////////////////////

  ** Deprecated - use `matches`
  @Deprecated { msg = "Use matches" }
  Bool include(Dict r, |Ref->Dict?|? pather)
  {
    doMatches(r, pather == null ? HaystackContext.nil : PatherContext(pather))
  }

  ** Return if the specified record matches this filter.
  ** Pass a context object to enable def aware features and to path
  ** through refs via the '->' operator.
  Bool matches(Dict r, HaystackContext? cx := null)
  {
    doMatches(r, cx ?: HaystackContext.nil)
  }

  ** Subclass hook
  @NoDoc internal abstract Bool doMatches(Dict r, HaystackContext cx)

  ** Get this query as a pattern String with variable values replaced
  ** with "?".  Pattern serves as a hash key for keeping track of
  ** which queries are being executed for dynamic query optimization.
  @NoDoc abstract Str pattern()

  ** Iterate each tag used by the filter.  No guarantee is made that
  ** the function isn't called with same tag name multiple times.  For
  ** paths, only the first tag name is taken into account.
  @NoDoc abstract Void eachTag(|Str tag| f)

  ** Iterate each literal value used by the filter.  No guarantee is
  ** made that the function isn't called with same value multiple times.
  @NoDoc abstract Void eachVal(|Obj? val, FilterPath path| f)

//////////////////////////////////////////////////////////////////////////
// AST
//////////////////////////////////////////////////////////////////////////

  ** Get the filter type.
  @NoDoc abstract FilterType type()

  ** Get the 'a' argument of the AST node type - see `FilterType`.
  @NoDoc virtual Obj? argA() { return null }

  ** Get the 'b' argument of the AST node type - see `FilterType`.
  @NoDoc virtual Obj? argB() { return null }

  ** Return if this is a compound query with a logical 'and' or 'or' parts.
  @NoDoc virtual Bool isCompound() { return false }

//////////////////////////////////////////////////////////////////////////
// Obj
//////////////////////////////////////////////////////////////////////////

  ** Equality is based on the normalized string.
  override Bool equals(Obj? that) { that is Filter && toStr == that.toStr }

  ** Hash is based on 'toStr'.
  override Int hash() { toStr.hash }

  ** Ordering is based on operator type, LHS, then RHS
  @NoDoc override Int compare(Obj that)
  {
    x := (Filter)that
    cmp := type <=> x.type; if (cmp != 0) return cmp
    cmp  = argA <=> x.argA; if (cmp != 0) return cmp
    return argB <=> x.argB
  }

  ** Return the normalized string of the filter
  abstract override Str toStr()
}

**************************************************************************
** FilterType
**************************************************************************

**
** FilterType is the enumeration for the various node types in
** a parsed fitler AST (abstract syntax tree).  Filter engines can
** use the type to optimize a query or compile it into alternate
** forms such as SQL:
**
** Filter Types:
**    Enum     Syntax     Arguments
**    ----     ------     ---------
**    has      a          argA=FilterPath
**    missing  not a      argA=FilterPath
**    eq       a == b     argA=FilterPath, argB=Obj
**    ne       a != b     argA=FilterPath, argB=Obj
**    gt       a > b      argA=FilterPath, argB=Obj
**    ge       a >= b     argA=FilterPath, argB=Obj
**    lt       a < b      argA=FilterPath, argB=Obj
**    le       a <= b     argA=FilterPath, argB=Obj
**    and      a and b    argA=Filter, argB=Filter
**    or       a or b     argA=Filter, argB=Filter
**    isSpec   a          argA=Str
**    isSymbol ^a         argA=Symbol
**    search   special
**
@Js @NoDoc
enum class FilterType
{
  has,
  missing,
  eq,
  ne,
  gt,
  ge,
  lt,
  le,
  and,
  or,
  isSymbol,
  isSpec,
  search
}

**************************************************************************
** SimpleFilter
**************************************************************************

@Js
internal const abstract class SimpleFilter : Filter
{
  new make(FilterPath p) { path = p }

  override final Void eachTag(|Str| f) { f(path.get(0)) }

  override Void eachVal(|Obj?,FilterPath| f) {}

  override final Obj? argA() { path }

  override final Bool doMatches(Dict r, HaystackContext cx)
  {
    matchesAt(r.get(path.get(0)), 0, cx)
  }

  private Bool matchesAt(Obj? val, Int level, HaystackContext cx)
  {
    // handle list of refs by checking each downstream path individually;
    // if no matches, then fall down to rest of logic
    if (val is List)
    {
      list := (Obj?[])val
      for (i:=0; i<list.size; ++i)
      {
        ref := list[i] as Ref
        if (ref != null && matchesAt(ref, level, cx))
          return true
      }
    }

    // if we are not at end of path, then work our way down path
    if (level+1 < path.size)
    {
      // if value at current level is Ref try to path thru via pather function
      if (val is Ref)
        val = cx.deref(val)

      // if value is dict, then recurse to next level
      dict := val as Dict
      if (dict != null)
        return matchesAt(dict.get(path.get(level+1)), level+1, cx)

      // use ->date/->time to path into a DateTime
      if (val is DateTime)
      {
        switch (path.get(level+1))
        {
          case "date": return matchesAt(((DateTime)val).date, level+1, cx)
          case "time": return matchesAt(((DateTime)val).time, level+1, cx)
          case "tz":   return matchesAt(((DateTime)val).tz.name, level+1, cx)
        }
      }

      // if list then it must have been list of refs checked above
      if (val is List) return false

      // use null as the match value (not found)
      val = null
    }

    // route to subclass implementation
    return doMatchesVal(val)
  }

  abstract Bool doMatchesVal(Obj? val)

  const FilterPath path
}

**************************************************************************
** FilterHas
**************************************************************************

@Js
internal const final class FilterHas : SimpleFilter
{
  new make(FilterPath p) : super(p) {}
  override Bool doMatchesVal(Obj? v) { v != null }
  override Str pattern() { toStr }
  override FilterType type() { FilterType.has }
  override Str toStr() { path.toStr }
}

**************************************************************************
** FilterMissing
**************************************************************************

@Js
internal const final class FilterMissing : SimpleFilter
{
  new make(FilterPath p) : super(p) { toStr = "not $p" }
  override Bool doMatchesVal(Obj? v) { v == null }
  override Str pattern() { toStr }
  override FilterType type() { FilterType.missing }
  override const Str toStr
}

**************************************************************************
** FilterEq
**************************************************************************

@Js
internal const final class FilterEq : SimpleFilter
{
  new make(FilterPath p, Obj v) : super(p) { val = v; toStr = "$p == ${Kind.fromVal(v).valToStr(v)}" }
  override Bool doMatchesVal(Obj? v) { v == val }
  override Void eachVal(|Obj?,FilterPath| f) { f(val, path) }
  override Str pattern() { "$path == ?" }
  override FilterType type() { FilterType.eq }
  override Obj? argB() { val }
  override const Str toStr
  private const Obj val
}

**************************************************************************
** FilterNe
**************************************************************************

@Js
internal const final class FilterNe : SimpleFilter
{
  new make(FilterPath p, Obj v) : super(p) { val = v; toStr = "$p != ${Kind.fromVal(v).valToStr(v)}" }
  override Bool doMatchesVal(Obj? v) { v != null && v != val }
  override Void eachVal(|Obj?, FilterPath| f) { f(val, path) }
  override Str pattern() { "$path != ?" }
  override FilterType type() { FilterType.ne }
  override Obj? argB() { val }
  override const Str toStr
  private const Obj val
}

**************************************************************************
** FilterCmp
**************************************************************************

@Js
internal abstract const class FilterCmp : SimpleFilter
{
  new make(FilterPath p, Obj v) : super(p)
  {
    this.val      = v
    this.valType  = v.typeof
    this.isNumber = valType === Number#
    this.toStr    = "$p $op ${Kind.fromVal(v).valToStr(v)}"
  }
  override Bool doMatchesVal(Obj? v)
  {
    if (v == null || v.typeof !== valType) return false // scalar types are final
    if (isNumber) return cmpNumber(v, val)
    return cmp(v, val)
  }
  override Void eachVal(|Obj?, FilterPath| f) { f(val, path) }
  override Str pattern() { "$path $op ?" }
  abstract Str op()
  abstract Bool cmp(Obj x, Obj val)
  Bool cmpNumber(Number a, Number b)
  {
    if (a.unit !== b.unit) return false
    return cmp(a.toFloat, b.toFloat)
  }
  override final Obj? argB() { val }
  override const Str toStr
  const Obj val
  const Type valType
  const Bool isNumber
}

@Js
internal const final class FilterLt : FilterCmp
{
  new make(FilterPath p, Obj v) : super(p, v) {}
  override Str op() { return "<" }
  override Bool cmp(Obj x, Obj val) { return x < val }
  override FilterType type() { return FilterType.lt }
}

@Js
internal const final class FilterLe : FilterCmp
{
  new make(FilterPath p, Obj v) : super(p, v) {}
  override Str op() { return "<=" }
  override Bool cmp(Obj x, Obj val) { return x <= val }
  override FilterType type() { return FilterType.le }
}

@Js
internal const final class FilterGt : FilterCmp
{
  new make(FilterPath p, Obj v) : super(p, v) {}
  override Str op() { return ">" }
  override Bool cmp(Obj x, Obj val) { return x > val }
  override FilterType type() { return FilterType.gt }
}

@Js
internal const final class FilterGe : FilterCmp
{
  new make(FilterPath p, Obj v) : super(p, v) {}
  override Str op() { return ">=" }
  override Bool cmp(Obj x, Obj val) { return x >= val }
  override FilterType type() { return FilterType.ge }
}

**************************************************************************
** FilterAnd
**************************************************************************

@Js
internal const final class FilterAnd : Filter
{
  new make(Filter a, Filter b) // must be normalized such that a < b
  {
    this.a = a; this.b = b
    toStr = (a.isCompound && a.type !== FilterType.and ? "($a)" : a.toStr) +
            " and " +
            (b.isCompound && b.type !== FilterType.and ? "($b)" : b.toStr)
  }
  override Bool doMatches(Dict r, HaystackContext cx) { a.doMatches(r, cx) && b.doMatches(r, cx) }
  override Void eachVal(|Obj?,FilterPath| f) { a.eachVal(f); b.eachVal(f) }
  override Void eachTag(|Str| f) { a.eachTag(f); b.eachTag(f) }
  override Str pattern() { "($a.pattern) and ($b.pattern)" }
  override FilterType type() { FilterType.and }
  override Obj? argA() { a }
  override Obj? argB() { b }
  override Bool isCompound() { true }
  override const Str toStr
  private const Filter a
  private const Filter b
}

**************************************************************************
** FilterOr
**************************************************************************

@Js
internal const final class FilterOr : Filter
{
  new make(Filter a, Filter b) // must be normalized such that a < b
  {
    this.a = a; this.b = b
    toStr = (a.isCompound && a.type !== FilterType.or ? "($a)" : a.toStr) +
            " or " +
            (b.isCompound && b.type !== FilterType.or ? "($b)" : b.toStr)
  }
  override Bool doMatches(Dict r, HaystackContext cx) { a.doMatches(r, cx) || b.doMatches(r, cx) }
  override Str pattern() { "($a.pattern) or ($b.pattern)" }
  override Void eachVal(|Obj?,FilterPath| f) { a.eachVal(f); b.eachVal(f) }
  override Void eachTag(|Str| f) { a.eachTag(f); b.eachTag(f) }
  override FilterType type() { FilterType.or }
  override Obj? argA() { a }
  override Obj? argB() { b }
  override Bool isCompound() { true }
  override const Str toStr
  private const Filter a
  private const Filter b
}

**************************************************************************
** FilterIsSymbol
**************************************************************************

@Js
internal const final class FilterIsSymbol : Filter
{
  new make(Symbol symbol) { this.symbol = symbol; this.toStr = symbol.toCode }
  override Bool doMatches(Dict r, HaystackContext cx) { cx.inference.isA(r, symbol) }
  override Str pattern() { symbol.toCode }
  override Void eachVal(|Obj?,FilterPath| f) {}
  override Void eachTag(|Str| f) {}
  override FilterType type() { FilterType.isSymbol }
  override Obj? argA() { symbol }
  override const Str toStr
  private const Symbol symbol
}

**************************************************************************
** FilterIsSpec
**************************************************************************

@Js
internal const final class FilterIsSpec : Filter
{
  new make(Str spec) { this.spec = spec }
  override Bool doMatches(Dict r, HaystackContext cx) { cx.xetoIsSpec(spec, r) }
  override Str pattern() { spec }
  override Void eachVal(|Obj?,FilterPath| f) {}
  override Void eachTag(|Str| f) {}
  override FilterType type() { FilterType.isSpec }
  override Obj? argA() { spec }
  override Str toStr() { spec }
  private const Str spec
}

**************************************************************************
** FilterPath
**************************************************************************

@Js @NoDoc const abstract class FilterPath
{
  ** Parse a path string.
  static FilterPath fromObj(Obj obj)
  {
    obj as FilterPath ?: fromStr(obj, true)
  }

  ** Parse a path string.
  static new fromStr(Str path, Bool checked := true)
  {
    try
    {
      dash := path.index("-", 0)
      if (dash == null) return FilterPath1(path)

      s := 0
      acc := Str[,]
      while (true)
      {
        n := path[s..<dash]
        if (n.isEmpty) throw Err()
        acc.add(n)
        if (path[dash+1] != '>') throw Err()
        s = dash+2
        dash = path.index("-", s)
        if (dash == null)
        {
          n = path[s..-1]
          if (n.isEmpty) throw Err()
          acc.add(n)
          break
        }
      }
      return FilterPathN(acc)
    }
    catch (Err e)
    {
      if (checked) throw ParseErr("Path: $path")
      return null
    }
  }

  ** Make a path with a single name.
  static FilterPath makeName(Str name) { FilterPath1(name) }

  ** Make a path with a list of names.
  static FilterPath makeNames(Str[] names)
  {
    names.size == 1 ? FilterPath1(names.first) : FilterPathN(names)
  }

  ** Get depth of path (number of tags)
  abstract Int size()

  ** Get tag at the given depth
  @Operator abstract Str get(Int i)

  ** Hash on string encoding
  override Int hash() { toStr.hash }

  ** Equality based on string encoding
  override Bool equals(Obj? that) { that is FilterPath && toStr == that.toStr }

  ** Return if this path contains the given tag name
  abstract Bool contains(Str n)

  ** Get list of tag names separated by "->"
  abstract override Str toStr()
}

@Js
internal const final class FilterPath1 : FilterPath
{
  new make(Str n) { this.name = n }
  override Int size() { 1 }
  override Str get(Int i) { if (i == 0) return name; throw IndexErr(i.toStr) }
  override Str toStr() { name }
  override Bool contains(Str n) { name == n }
  const Str name
}

@Js
internal const final class FilterPathN : FilterPath
{
  new make(Str[] n) { this.names = n; this.toStr = n.join("->") }
  override Int size() { names.size }
  override Str get(Int i) { names[i] }
  override Bool contains(Str n) { names.contains(n) }
  override const Str toStr
  const Str[] names
}

**************************************************************************
** FilterInference
**************************************************************************

@NoDoc @Js
mixin FilterInference
{
  ** No-op inference engine
  @NoDoc static FilterInference nil() { nilRef }
  private static const NilFilterInference nilRef := NilFilterInference()

  ** Return if record implements the given definition symbol.  If
  ** inference is supported return if record implements any of the def's
  ** subtypes. Or if inference is not supported return 'Symbol.hasTerm'.
  @NoDoc abstract Bool isA(Dict rec, Symbol symbol)
}

@NoDoc @Js
internal const class NilFilterInference : FilterInference
{
  override final Bool isA(Dict rec, Symbol symbol) { symbol.hasTerm(rec) }
}

**************************************************************************
** FilterParser
**************************************************************************

@Js
internal class FilterParser : HaystackParser
{

//////////////////////////////////////////////////////////////////////////
// API
//////////////////////////////////////////////////////////////////////////

  new make(Str s) : super(s) {}

  Filter parse()
  {
    f := condOr
    verify(HaystackToken.eof)
    return f
  }

//////////////////////////////////////////////////////////////////////////
// Parse
//////////////////////////////////////////////////////////////////////////

  private Filter condOr()
  {
    lhs := condAnd
    if (!isKeyword("or")) return lhs
    consume
    return lhs.or(condOr)
  }

  private Filter condAnd()
  {
    lhs := term
    if (!isKeyword("and")) return lhs
    consume
    return lhs.and(condAnd)
  }

  private Filter term()
  {
    if (cur === HaystackToken.lparen)
    {
      consume
      f := condOr
      consume(HaystackToken.rparen)
      return f
    }

    if (isKeyword("not") && peek === HaystackToken.id)
    {
      consume
      return FilterMissing(path)
    }

    if (cur === HaystackToken.symbol)
    {
      val := curVal
      consume
      return FilterIsSymbol(val)
    }

    if (cur === HaystackToken.id)
    {
      // FooBar
      if (curVal.toStr[0].isUpper) return FilterIsSpec(consumeId)

      // baz::FooBar
      if (peek === HaystackToken.colon2) return FilterIsSpec(specQName)

      // baz.qux::FooBar
      if (peek === HaystackToken.dot) return FilterIsSpec(specQName)
    }

    p := path
    switch (cur)
    {
      case HaystackToken.eq:    consume; return FilterEq(p, val)
      case HaystackToken.notEq: consume; return FilterNe(p, val)
      case HaystackToken.lt:    consume; return FilterLt(p, val)
      case HaystackToken.ltEq:  consume; return FilterLe(p, val)
      case HaystackToken.gt:    consume; return FilterGt(p, val)
      case HaystackToken.gtEq:  consume; return FilterGe(p, val)
    }

    return FilterHas(p)
  }

  private FilterPath path()
  {
    id := pathName
    if (cur !== HaystackToken.arrow)
      return FilterPath1.make(id)

    segments := [id]
    while (cur === HaystackToken.arrow)
    {
      consume
      segments.add(pathName)
    }
    return FilterPathN.make(segments)
  }

  private Str pathName()
  {
    if (cur !== HaystackToken.id) throw err("Expecting tag name, not $curToStr")
    id := curVal
    consume
    return id
  }

  private Obj? val()
  {
    if (cur.literal)
    {
      val := curVal
      consume
      return val
    }

    if (cur === HaystackToken.id)
    {
      if (curVal == "true") { consume; return true }
      if (curVal == "false") { consume; return false }
    }

    throw err("Expecting value literal, not $curToStr")
  }

  private Str specQName()
  {
    s := StrBuf()
    s.add(consumeId)
    while (cur === HaystackToken.dot)
    {
      consume
      s.addChar('.').add(consumeId)
    }
    if (cur !== HaystackToken.colon2) throw err("Expecting spec qname ::, not $curToStr")
    consume
    if (cur !== HaystackToken.id || !curVal.toStr[0].isUpper) throw err("Expecting spec capitalized name, not $curToStr")
    s.add("::").add(consumeId)
    return s.toStr
  }

  private Str consumeId()
  {
    if (cur !== HaystackToken.id) throw err("Expecting identifier, not $curToStr")
    id := curVal
    consume
    return id
  }

}

**************************************************************************
** SearchFilters
**************************************************************************

@Js
internal abstract const class SearchFilter : Filter
{
  new make(Str pattern) { this.pattern = pattern }

  override Bool doMatches(Dict r, HaystackContext cx)
  {
    // check Dict.dis
    if (includeVal(r.dis)) return true

    // check id if its long enough to avoid false positivies
    id := r["id"] as Ref
    if (id != null && pattern.size >= 8 && includeVal(id.id))  return true

    // check other key identifier tags
    if (checkTag(r, "name")) return true
    if (checkTag(r, "def"))  return true
    if (checkTag(r, "view")) return true
    if (checkTag(r, "app"))  return true

    return false
  }

  private Bool checkTag(Dict r, Str name)
  {
    val := r[name]
    return val != null && includeVal(val.toStr)
  }

  virtual Bool includeVal(Str dis) { false }

  const override Str pattern

  override Void eachTag(|Str tag| f) {}

  override Void eachVal(|Obj? val, FilterPath| f) {}

  override FilterType type() { FilterType.search }

  override Str toStr() { pattern }
}

@Js
internal const class GlobSearchFilter : SearchFilter
{
  new make(Str pattern) : super(pattern)
  {
    this.regex = Regex.glob("*" + pattern.lower + "*")
  }

  override Bool includeVal(Str s) { regex.matches(s.lower) }

  const Regex regex
}

@Js
internal const class RegexSearchFilter : SearchFilter
{
  new make(Str pattern) : super(pattern)
  {
    this.regex = Regex.fromStr(pattern[3..-1])
  }

  override Bool includeVal(Str s) { regex.matches(s) }

  const Regex regex
}

@Js
internal const class FilterSearchFilter : SearchFilter
{
  new make(Str pattern) : super(pattern)
  {
    this.filter = Filter.fromStr(pattern[2..-1])
  }

  override Bool doMatches(Dict r, HaystackContext cx)
  {
    filter.matches(r, cx)
  }

  const Filter filter
}

