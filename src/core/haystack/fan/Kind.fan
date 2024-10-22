//
// Copyright (c) 2009, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   23 Jan 2009  Brian Frank  Creation
//   06 Jun 2009  Brian Frank  Rewrite Prop into Tag
//   19 Jun 2009  Brian Frank  Rename to Kind
//   15 Jan 2016  Brian Frank  Enhance for full 3.0 data model
//

using concurrent

**
** Kind provides a type signature for a Haystack data value
**
@Js
const abstract class Kind
{

//////////////////////////////////////////////////////////////////////////
// Predefined
//////////////////////////////////////////////////////////////////////////

  @NoDoc const static Kind obj      := ObjKind()
  @NoDoc const static Kind bin      := BinKind()
  @NoDoc const static Kind bool     := BoolKind()
  @NoDoc const static Kind coord    := CoordKind()
  @NoDoc const static Kind date     := DateKind()
  @NoDoc const static Kind dateTime := DateTimeKind()
  @NoDoc const static Kind dict     := DictKind()
  @NoDoc const static Kind grid     := GridKind()
  @NoDoc const static Kind list     := ListKind(obj)
  @NoDoc const static Kind marker   := MarkerKind()
  @NoDoc const static Kind na       := NAKind()
  @NoDoc const static Kind number   := NumberKind()
  @NoDoc const static Kind ref      := RefKind()
  @NoDoc const static Kind remove   := RemoveKind()
  @NoDoc const static Kind span     := SpanKind()
  @NoDoc const static Kind str      := StrKind()
  @NoDoc const static Kind symbol   := SymbolKind()
  @NoDoc const static Kind time     := TimeKind()
  @NoDoc const static Kind uri      := UriKind()
  @NoDoc const static Kind xstr     := XStrKind()

  @NoDoc const static Kind[] listing

  private static const Str:Kind fromStrMap
  private static const Str:Kind fromDefMap
  static
  {
    map := Str:Kind[:]
    defs := Str:Kind[:]
    Kind#.fields.each |f|
    {
      if (f.isStatic && f.type == Kind#)
      {
        kind := (Kind)f.get
        map[kind.name] = kind
        defs[kind.name.decapitalize] = kind
      }
    }
    fromStrMap = map
    fromDefMap = defs
    listing = map.vals.sort
  }

  internal new make(Str name, Type type, Str signature := name)
  {
    this.name = name
    this.type = type
    this.signature = signature
    this.defSymbol = Symbol.parse(name.decapitalize)
  }

//////////////////////////////////////////////////////////////////////////
// Lookup
//////////////////////////////////////////////////////////////////////////

  ** Lookup Kind for a Fantom type
  static Kind? fromType(Type? type, Bool checked := true)
  {
    if (type != null)
    {
      // ignore nullability
      type = type.toNonNullable

      // fixed final types
      kind := fromFixedType(type)
      if (kind != null) return kind

      // handle collection types
      if (type.fits(List#))  return fromListTypeOf(type.params["V"])
      if (type.fits(Dict#))  return dict
      if (type.fits(Grid#))  return grid
    }

    // non-Haystack type
    if (checked) throw Err("Not Haystack type: ${type}")
    return null
  }

  ** Lookup Kind for a Fantom object
  static Kind? fromVal(Obj? val, Bool checked := true)
  {
    if (val != null)
    {
      // fixed final types
      kind := fromFixedType(val.typeof)
      if (kind != null) return kind

      // from collection types
      if (val is List) return fromListTypeOf(((List)val).of)
      if (val is Dict) return dict
      if (val is Grid) return grid
    }

    // non-Haystack type
    if (checked) throw NotHaystackErr("${val?.typeof}")
    return null
  }

  private static Kind? fromFixedType(Type type)
  {
    if (type === Number#)    return number
    if (type === Marker#)    return marker
    if (type === Str#)       return str
    if (type === Ref#)       return ref
    if (type === DateTime#)  return dateTime
    if (Symbol.fits(type))   return symbol
    if (type === Bool#)      return bool
    if (type === NA#)        return na
    if (type === Coord#)     return coord
    if (type === Uri#)       return uri
    if (type === Span#)      return span
    if (type === Date#)      return date
    if (type === Time#)      return time
    if (type === Bin#)       return bin
    if (type === Remove#)    return remove
    if (type === XStr#)      return xstr
    return null
  }

  private static Kind fromListTypeOf(Type? t)
  {
    if (t == null) return obj.toListOf
    of := fromType(t.toNonNullable, false) ?: obj
    return of.toListOf
  }

  ** Given a list, map to immutable list typed using
  ** haystack kind type inference
  @NoDoc static List toInferredList(Obj?[] acc)
  {
    // handle empty list
    if (acc.isEmpty) return Obj#.toNullable.emptyList

    // walk the values
    Type? best := null
    nulls := false
    sysPod := Str#.pod
    for (i := 0; i<acc.size; ++i)
    {
      // skip but keep track of nulls
      val := acc[i]
      if (val == null) { nulls = true; continue }

      // get value as normalized Kind type
      type := val.typeof
      if (type.pod !== sysPod)
      {
        if (val is Dict) type = Dict#
        else if (val is Grid) type = Grid#
        else if (val is Symbol) type = Symbol#
      }

      // check if first, same, or different from best kind
      if (best == null) best = type
      else if (best !== type) { best = null; break }
    }

    // normalize based on best/nulls
    if (best == null) return acc.toImmutable
    if (nulls) best = best.toNullable
    return List(best, acc.size).addAll(acc).toImmutable
  }

  ** Lookup Kind from its lower case def name
  static Kind? fromDefName(Str name, Bool checked := true)
  {
    kind := fromDefMap[name]
    if (kind != null) return kind
    if (checked) throw UnknownKindErr(name)
    return null
  }

//////////////////////////////////////////////////////////////////////////
// Parsing
//////////////////////////////////////////////////////////////////////////

  ** Parse a signature to its Kind representation.  If it cannot be
  ** parsed to a known kind, then return null or raise an exception.
  static new fromStr(Str signature, Bool checked := true)
  {
    // handle predefined
    r := fromStrMap[signature]
    if (r != null) return r

    // foo[]
    if (signature.size > 3 && signature.endsWith("[]"))
      return fromStr(signature[0..-3], checked)?.toListOf

    // foo<tag>
    if (signature.size > 4 && signature[-1] == '>')
    {
      try
      {
        open := signature.index("<")
        base := Kind.fromStr(signature[0..<open])
        tag := signature[open+1..-2]
        if (tag.isEmpty) throw Err()
        return base.toTagOf(tag)
      }
      catch (Err e) {} // fall thru
    }

    if (checked) throw UnknownKindErr(signature)
    return null
  }

//////////////////////////////////////////////////////////////////////////
// Identity
//////////////////////////////////////////////////////////////////////////

  ** Name of kind: Bool, Number, List, etc
  const Str name

  ** Fantom type for the kind
  const Type type

  ** Def symbol
  @NoDoc const Symbol defSymbol

  ** Component kind of a List; otherwise null
  @NoDoc virtual Kind? of() { null }

  ** Tag name if parameterized Ref, Dict; otherwise null
  @NoDoc virtual Str? tag() { null }
  @NoDoc Str? paramName() { tag }

  ** Full signature of this kind
  @NoDoc const Str signature

  ** Hash is based signature
  override Int hash() { signature.hash }

  ** Equality is based signature
  override Bool equals(Obj? that)
  {
    that is Kind && signature == ((Kind)that).signature
  }

  ** Return signature
  override Str toStr() { signature }

  ** Return if this is Number
  @NoDoc virtual Bool isNumber() { false }

  ** Return if this is Ref
  @NoDoc virtual Bool isRef() { false }

  ** Return if this is Dict
  @NoDoc virtual Bool isDict() { false }

  ** Return List of this kind
  @NoDoc virtual Kind toListOf()
  {
    list := listOfRef.val as Kind
    if (list == null) listOfRef.val = list = ListKind(this)
    return list
  }
  private const AtomicRef listOfRef := AtomicRef()

  ** Return if this an atomic (not collection) kind
  @NoDoc Bool isScalar() { !isCollection }

  ** Return if this an singleton type (marker, NA, remove)
  @NoDoc virtual Bool isSingleton() { false }

  ** Return if this kind is encoded as XStr
  @NoDoc virtual Bool isXStr() { false }

  ** Return if this List, Dict, or Grid kind
  @NoDoc virtual Bool isCollection() { false }

  ** Return if this List
  @NoDoc virtual Bool isList() { false }

  ** Return if this a List of given component kind
  @NoDoc virtual Bool isListOf(Kind of) { false }

  ** Return if this a Ref[] or Ref<foo>[]
  @NoDoc virtual Bool isListOfRef() { isListOf(ref) }

  ** Return if this is Grid
  @NoDoc virtual Bool isGrid() { false }

  ** Return this kind parameterized with given tag
  @NoDoc virtual Kind toTagOf(Str tag)
  {
    throw UnsupportedErr(signature)
  }

  ** Default value for this kind
  @NoDoc virtual Obj defVal() { type.make }

  ** Icon alias name to use for this kind's values
  @NoDoc Str icon() { defSymbol.name }

  ** Return if this kind can be stored in the Folio database as tag value
  @NoDoc virtual Bool canStore() { true }

//////////////////////////////////////////////////////////////////////////
// Encoding
//////////////////////////////////////////////////////////////////////////

  ** Convert value to string
  @NoDoc virtual Str valToStr(Obj val) { val.toStr }

  ** Convert value to zinc string encoding
  @NoDoc virtual Str valToZinc(Obj val) { valToStr(val) }

  ** Convert value to JSON string encoding
  @NoDoc virtual Str valToJson(Obj val) { val.toStr.toCode }

  ** Convert value to Axon code string
  @NoDoc virtual Str valToAxon(Obj val) { valToStr(val) }

  ** Convert value to display string
  @NoDoc virtual Str valToDis(Obj val, Dict meta := Etc.emptyDict) { val.toStr }

}

**************************************************************************
** Kind Subclasses
**************************************************************************

@Js
internal const final class ObjKind : Kind
{
  new make() : super("Obj", Obj#) {}
  override Obj defVal() { "" }
  override Kind toListOf() { list }
}

@Js
internal const final class MarkerKind : Kind
{
  new make() : super("Marker", Marker#) {}
  override Bool isSingleton() { true }
  override Str valToZinc(Obj val) { "M" }
  override Str valToJson(Obj val) { "m:" }
  override Str valToDis(Obj val, Dict meta := Etc.emptyDict) { "\u2713" }
  override Str valToAxon(Obj val) { "marker()" }
  override Obj defVal() { Marker.val }
}

@Js
internal const final class NAKind : Kind
{
  new make() : super("NA", NA#) {}
  override Bool isSingleton() { true }
  override Str valToZinc(Obj val) { "NA" }
  override Str valToJson(Obj val) { "z:" }
  override Str valToDis(Obj val, Dict meta := Etc.emptyDict) { "NA" }
  override Str valToAxon(Obj val) { "na()" }
  override Obj defVal() { NA.val }
  override Bool canStore() { false }
}

@Js
internal const final class RemoveKind : Kind
{
  new make() : super("Remove", Remove#) {}
  override Bool isSingleton() { true }
  override Str valToZinc(Obj val) { "R" }
  override Str valToJson(Obj val) { "-:" }
  override Str valToDis(Obj val, Dict meta := Etc.emptyDict) { "\u2716" }
  override Str valToAxon(Obj val) { "removeMarker()" }
  override Obj defVal() { Remove.val }
}

@Js
internal const final class BoolKind : Kind
{
  new make() : super("Bool", Bool#) {}
  override Str valToZinc(Obj val) { val ? "T" : "F" }
  override Str valToJson(Obj val) { throw UnsupportedErr() }
  override Str valToDis(Obj val, Dict meta := Etc.emptyDict)
  {
    bool := (Bool)val
    enum := meta["enum"] as Str
    if (enum != null)
    {
      toks := enum.split(',')
      if (toks.size == 2) return bool ? toks[1] : toks[0]
    }
    return bool.toStr
  }
}

@Js
internal const final class NumberKind : Kind
{
  new make() : super("Number", Number#) {}
  override Bool isNumber() { true }
  override Str valToDis(Obj val, Dict meta := Etc.emptyDict) { ((Number)val).toLocale(meta["format"]) }
  override Str valToJson(Obj val) { ((Number)val).toJson }
  override Str valToAxon(Obj val)
  {
    f := ((Number)val).toFloat
    if (f.isNaN) return "nan()"
    if (f == Float.posInf) return "posInf()"
    if (f == Float.negInf) return "negInf()"
    return val.toStr
  }
}

@Js
internal const final class RefKind : Kind
{
  new make() : super("Ref", Ref#) {}

  new makeTag(Str? tag) : super.make("Ref", Ref#, "Ref<$tag>") { this.tag = tag }
  override const Str? tag
  override Kind toTagOf(Str tag) { makeTag(tag) }
  override Bool isRef() { true }

  override Str valToStr(Obj val) { ((Ref)val).toCode }
  override Str valToDis(Obj val, Dict meta := Etc.emptyDict) { ((Ref)val).dis }
  override Str valToZinc(Obj val) { ((Ref)val).toZinc }
  override Str valToJson(Obj val) { ((Ref)val).toJson }
  override Str valToAxon(Obj val) { ((Ref)val).toCode }
}

@Js
internal const final class SymbolKind : Kind
{
  new make() : super("Symbol", Symbol#) {}

  override Obj defVal() { Symbol.fromStr("marker") }
  override Str valToStr(Obj val) { ((Symbol)val).toCode }
  override Str valToZinc(Obj val) { ((Symbol)val).toCode }
  override Str valToJson(Obj val) { "y:"+val }
  override Str valToAxon(Obj val) { ((Symbol)val).toCode }
}

@Js
internal const final class StrKind : Kind
{
  new make() : super("Str", Str#) {}
  override Str valToStr(Obj val) { ((Str)val).toCode }
  override Str valToDis(Obj val, Dict meta := Etc.emptyDict)
  {
    s := (Str)val
    if (s.size < 62) return s
    return s[0..60] + "..."
  }
  override Str valToAxon(Obj val) { ((Str)val).toCode }
  override Str valToJson(Obj val) { ((Str)val).contains(":") ? "s:"+val : val }
}

@Js
internal const final class UriKind : Kind
{
  new make() : super("Uri", Uri#) {}
  override Str valToStr(Obj val) { ((Uri)val).toCode }
  override Str valToJson(Obj val) { "u:" + val }
  override Str valToAxon(Obj val) { ((Uri)val).toCode }
  override Str valToDis(Obj val, Dict meta := Etc.emptyDict)
  {
    format := meta["format"] as Str
    if (format != null) return format
    return val.toStr
  }
}

@Js
internal const final class DateTimeKind : Kind
{
  new make() : super("DateTime", DateTime#) {}
  override Str valToStr(Obj val)
  {
    dt := (DateTime)val
    if (dt.tz === TimeZone.utc)
      return dt.toIso
    else
      return dt.toStr
  }
  override Str valToDis(Obj val, Dict meta := Etc.emptyDict) { ((DateTime)val).toLocale(meta["format"]) }
  override Str valToJson(Obj val) { "t:" + val }
  override Str valToAxon(Obj val) { "parseDateTime($val.toStr.toCode)" }
}

@Js
internal const final class DateKind : Kind
{
  new make() : super("Date", Date#) {}
  override Obj defVal() { Date.today }
  override Str valToDis(Obj val, Dict meta := Etc.emptyDict) { ((Date)val).toLocale(meta["format"]) }
  override Str valToJson(Obj val) { "d:" + val }
}

@Js
internal const final class TimeKind : Kind
{
  new make() : super("Time", Time#) {}
  override Str valToDis(Obj val, Dict meta := Etc.emptyDict) { ((Time)val).toLocale(meta["format"]) }
  override Str valToJson(Obj val) { "h:" + val }
}

@Js
internal const final class CoordKind : Kind
{
  new make() : super("Coord", Coord#) {}
  override Str valToJson(Obj val) { "c:" + ((Coord)val).toLatLgnStr }
  override Str valToAxon(Obj val) { "coord(" + ((Coord)val).toLatLgnStr + ")" }
}

**************************************************************************
** XStr Kinds
**************************************************************************

@Js
internal const final class XStrKind : Kind
{
  new make() : super("XStr", XStr#) {}
  override Bool isXStr() { true }
  override Str valToJson(Obj val) { x := (XStr)val; return "x:$x.type:$x.val" }
  override Str valToAxon(Obj val) { x := (XStr)val; return "xstr($x.type.toCode, $x.val.toCode)" }
  override Bool canStore() { false }
}

@Js
internal const final class BinKind : Kind
{
  new make() : super("Bin", Bin#) {}
  override Bool isXStr() { true }
  override Str valToZinc(Obj val) { "Bin(" + ((Bin)val).mime.toStr.toCode + ")" } // 3.0 version
  override Str valToJson(Obj val) { "b:" + ((Bin)val).mime.toStr }
  override Str valToAxon(Obj val) { Str<|xstr("Bin",|> + ((Bin)val).mime.toStr.toCode + ")" }
}

@Js
internal const final class SpanKind : Kind
{
  new make() : super("Span", Span#) {}
  override Bool isXStr() { true }
  override Str valToZinc(Obj val) { "Span($val.toStr.toCode)" }
  override Str valToJson(Obj val) { "x:Span:$val" }
  override Str valToAxon(Obj val) { ((Span)val).toCode }
  override Str valToDis(Obj val, Dict meta := Etc.emptyDict)  { ((Span)val).dis }
  override Bool canStore() { false }
}

**************************************************************************
** Collection Kinds
**************************************************************************

@Js
internal const final class ListKind : Kind
{
  new make(Kind of) : super("List", List#, of.signature + "[]") { this.of = of }
  override const Kind? of
  override Bool isCollection() { true }
  override Bool isList() { true }
  override Bool isListOf(Kind of)
  {
    if (this.of == null) return false
    if (of.name != this.of.name) return false
    if (of.tag != null && of.tag != this.of.tag) return false
    return true
  }
  override Obj defVal() { Obj?[,] }
  override Str valToAxon(Obj v) { "[" + ((List)v).join(", ") |x| { Etc.toAxon(x) }  + "]" }
  override Str valToZinc(Obj v) { "[" + ((List)v).join(", ") |x| { ZincWriter.valToStr(x) }  + "]" }
  override Str valToDis(Obj val, Dict meta := Etc.emptyDict)
  {
    list := (List)val
    if (list.isEmpty) return ""
    if (list.size == 1) return itemToDis(list[0], meta)
    s := StrBuf()
    for (i := 0; i<list.size; ++i)
    {
      x := itemToDis(list[i], meta)
      if (s.size + x.size < 250)
        { s.join(x, ", ") }
      else
        { s.add(" (${list.size-i} $<more>)");  break }

    }
    return s.toStr
  }
  private Str itemToDis(Obj? item, Dict meta)
  {
    if (item == null) return ""
    kind := of ?: Kind.fromVal(item, false)
    if (kind != null) return kind.valToDis(item, meta)
    return item.toStr
  }
}

@Js
internal const final class DictKind : Kind
{
  new make() : super("Dict", Dict#) {}
  new makeTag(Str? tag) : super.make("Dict", Dict#, "Dict<$tag>") { this.tag = tag }
  override const Str? tag
  override Kind toTagOf(Str tag) { makeTag(tag) }
  override Bool isCollection() { true }
  override Bool isDict() { true }
  override Obj defVal() { Etc.emptyDict }
  override Str valToAxon(Obj val)
  {
    s := StrBuf().add("{")
    ((Dict)val).each |v, n|
    {
      if (s.size > 1) s.add(", ")
      s.add(Etc.isTagName(n) ? n : n.toCode)
      if (v != Marker.val) s.add(":").add(Etc.toAxon(v))
    }
    return s.add("}").toStr
  }
}

@Js
internal const final class GridKind : Kind
{
  new make() : super("Grid", Grid#) {}
  new makeTag(Str? tag) : super.make("Grid", Grid#, "Grid<$tag>") { this.tag = tag }
  override const Str? tag
  override Kind toTagOf(Str tag) { makeTag(tag) }
  override Bool isCollection() { true }
  override Bool isGrid() { true }
  override Obj defVal() { Etc.makeEmptyGrid }
  override Str valToDis(Obj val, Dict meta := Etc.emptyDict) { "<<Nested Grid>>" }
  override Str valToAxon(Obj val) { throw UnsupportedErr("Cannot format grid to Axon") }
}

