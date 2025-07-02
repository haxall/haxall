//
// Copyright (c) 2013, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   23 Aug 2013  Brian Frank  Creation
//

using concurrent
using xeto
using haystack

**
** PointConvert runs an algorthm to convert raw values to normalized
** values during cur/his import or vise versa on write export.
**
@NoDoc
const abstract class PointConvert
{
  ** Parse a conversion.  On failure raise ParseErr
  ** or return null based on check flag.
  static new fromStr(Str s, Bool checked := true)
  {
    val := cache[s]
    if (val == null)
    {
      try
        val = ConvertParser(s).parse
      catch (ParseErr e)
        val = ParseErr("$s.toCode: $e.msg", e)
      catch (Err e)
        val = ParseErr(s, e)

      cache[s] = val
    }
    if (val is PointConvert) return val
    if (checked)
    {
      err := (Err)val
      throw ParseErr(err.msg, err.cause)
    }
    return null
  }

  private static const ConcurrentMap cache := ConcurrentMap()

  ** Perform the conversion
  abstract Obj? convert(PointLib lib, Dict rec, Obj? val)
}

**************************************************************************
** ConvertParser
**************************************************************************

internal class ConvertParser
{
  new make(Str s)
  {
    this.toks = tokenize(s)
    if (toks.isEmpty) throw ParseErr("Empty string")
    this.cur = toks.first
  }

//////////////////////////////////////////////////////////////////////////
// Parse
//////////////////////////////////////////////////////////////////////////

  PointConvert parse()
  {
    // simple expr
    expr := parseExpr
    if (curi >= toks.size) return expr

    // pipeline of expressions
    pipeline := [expr]
    while (curi < toks.size) pipeline.add(parseExpr)
    return PipelineConvert(pipeline)
  }

  private PointConvert parseExpr()
  {
    if (cur == "+")  return parseAdd
    if (cur == "-")  return parseSub
    if (cur == "*")  return parseMul
    if (cur == "/")  return parseDiv
    if (cur == "&")  return parseAnd
    if (cur == "|")  return parseOr
    if (cur == "^")  return parseXor
    if (cur == ">>") return parseShiftr
    if (cur == "<<") return parseShiftl
    if (cur == "?:") return parseElvis
    if (cur.startsWith("-")) return parseSubAtomic
    return parseFuncOrUnit
  }

  private PointConvert parseAdd() { consume("+"); return AddConvert(consumeFloat) }
  private PointConvert parseSub() { consume("-"); return SubConvert(consumeFloat) }
  private PointConvert parseMul() { consume("*"); return MulConvert(consumeFloat) }
  private PointConvert parseDiv() { consume("/"); return DivConvert(consumeFloat) }
  private PointConvert parseAnd() { consume("&"); return AndConvert(consumeInt) }
  private PointConvert parseOr()  { consume("|"); return OrConvert(consumeInt) }
  private PointConvert parseXor() { consume("^"); return XorConvert(consumeInt) }
  private PointConvert parseShiftr() { consume(">>"); return ShiftrConvert(consumeInt) }
  private PointConvert parseShiftl() { consume("<<"); return ShiftlConvert(consumeInt) }
  private PointConvert parseElvis() { consume("?:"); return ElvisConvert(consumeLiteral) }

  private PointConvert parseSubAtomic()
  {
    tok := consume(null)[1..-1]
    f := Float.fromStr(tok, false)
    if (f == null) throw ParseErr("Expecting float, not $tok")
    return SubConvert(f)
  }

  private PointConvert parseFuncOrUnit()
  {
    name := consume(null)
    if (cur == "=>")
      return parseUnit(name)
    else
      return parseFunc(name)
  }

  private PointConvert parseUnit(Str from)
  {
    consume("=>")
    to := consume(null)
    return UnitConvert(from, to)
  }

  private PointConvert parseFunc(Str name)
  {
    // parse name(args...)
    args := Str[,]
    consume("(")
    if (cur != ")")
    {
      while (true)
      {
        s := StrBuf()
        s.add(consume(null))
        while (cur != "," && cur != ")")
        {
          s.addChar(' ').add(consume(null))
        }
        args.add(s.toStr)
        if (cur == ")") break
        consume(",")
      }
    }
    consume(")")

    switch (name)
    {
      case "pow":             return PowConvert(args)
      case "min":             return MinConvert(args)
      case "max":             return MaxConvert(args)
      case "reset":           return ResetConvert(args)
      case "toStr":           return ToStrConvert(args)
      case "invert":          return InvertConvert(args)
      case "as":              return AsConvert(args)
      case "thermistor":      return ThermistorConvert(args)
      case "u2SwapEndian":    return U2SwapEndianConvert(args)
      case "u4SwapEndian":    return U4SwapEndianConvert(args)
      case "enumStrToNumber": return EnumStrToNumberConvert(args)
      case "enumNumberToStr": return EnumNumberToStrConvert(args)
      case "enumStrToBool":   return EnumStrToBoolConvert(args)
      case "enumBoolToStr":   return EnumBoolToStrConvert(args)
      case "numberToBool":    return NumberToBoolConvert(args)
      case "numberToStr":     return NumberToStrConvert(args)
      case "numberToHex":     return NumberToHexConvert(args)
      case "boolToNumber":    return BoolToNumberConvert(args)
      case "strToBool":       return StrToBoolConvert(args)
      case "strToNumber":     return StrToNumberConvert(args)
      case "hexToNumber":     return HexToNumberConvert(args)
      case "lower":           return LowerConvert(args)
      case "upper":           return UpperConvert(args)
      case "strReplace":      return StrReplaceConvert(args)
      default:                throw ParseErr("Unknown convert func: $name")
    }
  }

  private Obj? consumeLiteral()
  {
    tok := consume(null)
    if (tok.isEmpty) throw ParseErr("Expecting literal")
    num := Number.fromStr(tok, false)
    if (num != null) return num
    if (tok == "true") return true
    if (tok == "false") return false
    if (tok == "NA") return NA.val
    if (!tok[0].isAlpha) throw ParseErr("Expecting literal")
    return tok
  }

  private Float consumeFloat()
  {
    tok := consume(null)
    f := Float.fromStr(tok, false)
    if (f == null) throw ParseErr("Expecting float, not $tok")
    return f
  }

  private Int consumeInt()
  {
    tok := consume(null)
    i := tok.startsWith("0x") ?
         Int.fromStr(tok[2..-1], 16, false) :
         Int.fromStr(tok, 10, false)
    if (i == null) throw ParseErr("Expecting int, not $tok")
    return i
  }

  private Str consume(Str? expected)
  {
    if (cur == eof) throw Err("Unexpected end of string")
    old := cur
    if (expected != null && cur != expected)
      throw ParseErr("Expected $expected not $cur")
    cur = toks.getSafe(++curi) ?: eof
    return old
  }

//////////////////////////////////////////////////////////////////////////
// Tokenize
//////////////////////////////////////////////////////////////////////////

  internal static Str[] tokenize(Str s)
  {
    s = s.trim
    acc := Str[,]
    start := 0
    for (i:=0; i<s.size; ++i)
    {
      ch := s[i]
      if (ch < tokenSeps.size && tokenSeps[ch] == 'x')
      {
        next := i+1 < s.size ? s[i+1] : 0
        if (ch == '/' && next.isAlpha) continue // units with slash

        if (start < i) acc.add(s[start..<i])
        if (!ch.isSpace)
        {
          opStart := i
          if (ch == '<' && next == '<') ++i
          if (ch == '>' && next == '>') ++i
          if (ch == '=' && next == '>') ++i
          acc.add(s[opStart..i])
        }
        start = i + 1
      }
      else if (ch == '\'')
      {
        // single quoted string literal
        start = i + 1
        i++
        while (i < s.size && s.get(i) != '\'') i++
        if (i >= s.size) throw Err("Missing end quote")
        acc.add(s[start..<i])
        start = i+1
      }
    }
    if (start < s.size) acc.add(s[start..-1])
    return acc
  }


  ** String of spaces|x indexed by a char code
  private static const Str tokenSeps
  static
  {
    seps := " \t+*/&|^<>(,)="
    s := StrBuf()
    for (i:=0; i<128; ++i) s.addChar( seps.containsChar(i) ? 'x' : ' ' )
    tokenSeps = s.toStr
  }

  static Void main(Str[] args)
  {
    echo("0123456789_123456789")
    echo(args.first)
    echo("--------------")
    tokenize(args.first).each |tok|
    {
      echo(tok.toCode)
    }
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  private static const Str eof := "<end>"

  private Str[] toks
  private Str cur
  private Int curi
}

**************************************************************************
** Pipeline
**************************************************************************

internal const class PipelineConvert : PointConvert
{
  new make(PointConvert[] p) { this.pipeline = p }
  override Str toStr() { pipeline.join(" ") }
  override Obj? convert(PointLib lib, Dict rec, Obj? val)
  {
    for (i:=0; i<pipeline.size; ++i)
      val = pipeline[i].convert(lib, rec, val)
    return val
  }
  const PointConvert[] pipeline
}

**************************************************************************
** Math
**************************************************************************

internal abstract const class MathConvert : PointConvert
{
  new make(Float x) { this.x = x }
  const Float x
  abstract Str symbol()
  abstract Float doConvert(Float f)
  override Str toStr() { "$symbol $x" }
  override Obj? convert(PointLib lib, Dict rec, Obj? val)
  {
    if (val == null) return null
    num :=(Number)val
    return Number(doConvert(num.toFloat), num.unit)
  }
}

internal const class AddConvert : MathConvert
{
  new make(Float x) : super(x) {}
  override Str symbol() { "+" }
  override Float doConvert(Float f) { f + x }
}

internal const class SubConvert : MathConvert
{
  new make(Float x) : super(x) {}
  override Str symbol() { "-" }
  override Float doConvert(Float f) { f - x }
}

internal const class MulConvert : MathConvert
{
  new make(Float x) : super(x) {}
  override Str symbol() { "*" }
  override Float doConvert(Float f) { f * x }
}

internal const class DivConvert : MathConvert
{
  new make(Float x) : super(x) { if (x == 0f) throw ParseErr("/ zero") }
  override Str symbol() { "/" }
  override Float doConvert(Float f) { f / x }
}

**************************************************************************
** Bitwise
**************************************************************************

internal abstract const class BitConvert : PointConvert
{
  new make(Int x) { this.x = x }
  const Int x
  abstract Str symbol()
  abstract Int doConvert(Int i)
  override Str toStr() { "$symbol 0x$x.toHex" }
  override Obj? convert(PointLib lib, Dict rec, Obj? val)
  {
    if (val == null) return null
    num := (Number)val
    return Number(doConvert(num.toInt), num.unit)
  }
}

internal const class AndConvert : BitConvert
{
  new make(Int x) : super(x) {}
  override Str symbol() { "&" }
  override Int doConvert(Int v) { v.and(x) }
}

internal const class OrConvert : BitConvert
{
  new make(Int x) : super(x) {}
  override Str symbol() { "|" }
  override Int doConvert(Int v) { v.or(x) }
}

internal const class XorConvert : BitConvert
{
  new make(Int x) : super(x) {}
  override Str symbol() { "^" }
  override Int doConvert(Int v) { v.xor(x) }
}

internal const class ShiftrConvert : BitConvert
{
  new make(Int x) : super(x) {}
  override Str symbol() { ">>" }
  override Int doConvert(Int v) { v.shiftr(x) }
}

internal const class ShiftlConvert : BitConvert
{
  new make(Int x) : super(x) {}
  override Str symbol() { "<<" }
  override Int doConvert(Int v) { v.shiftl(x) }
}

**************************************************************************
** Misc Operators
**************************************************************************

internal const class ElvisConvert : PointConvert
{
  new make(Obj? x) { this.x = x }
  const Obj? x
  override Str toStr() { "?: $x" }
  override Obj? convert(PointLib lib, Dict rec, Obj? v) { v ?: x }
}

**************************************************************************
** UnitConvert
**************************************************************************

internal const class UnitConvert : PointConvert
{
  new make(Str from, Str to)
  {
    this.from = Unit(from, false) ?: throw ParseErr("Unknown unit: $from")
    this.to = Unit(to, false) ?: throw ParseErr("Unknown unit: $to")
  }

  const Unit from
  const Unit to

  override Str toStr() { "$from => $to" }

  override Obj? convert(PointLib lib, Dict rec, Obj? val)
  {
    if (val == null) return null
    num := (Number)val
    if (num.unit != null && num.unit != from) throw UnitErr("val unit != from unit: $num.unit != $from")
    return Number(from.convertTo(num.toFloat, to), to)
  }
}

**************************************************************************
** ToStrConvert
**************************************************************************

internal const class ToStrConvert : PointConvert
{
  new make(Str[] args)
  {
    if (args.size != 0) throw ParseErr("Invalid num args $args.size, expected 0")
  }

  override Str toStr() { "toStr()" }

  override Obj? convert(PointLib lib, Dict rec, Obj? val)
  {
    if (val == null) return "null"
    return val.toStr
  }
}

**************************************************************************
** AsConvert
**************************************************************************

internal const class AsConvert : PointConvert
{
  new make(Str[] args)
  {
    if (args.size != 1) throw ParseErr("Invalid num args: $args.size, expected 1")
    this.to = Unit(args.first, false) ?: throw ParseErr("Unknown unit: $args.first")
  }
  override Obj? convert(PointLib lib, Dict rec, Obj? val)
  {
    if (val == null) return null
    num := (Number)val
    return Number(num.toFloat, to)
  }
  const Unit to
}


**************************************************************************
** InvertConvert
**************************************************************************

internal const class InvertConvert : PointConvert
{
  new make(Str[] args)
  {
    if (args.size != 0) throw ParseErr("Invalid num args $args.size, expected 0")
  }

  override Str toStr() { "invert()" }

  override Obj? convert(PointLib lib, Dict rec, Obj? val)
  {
    if (val == null) return null
    return ((Bool)val).not
  }
}

**************************************************************************
** PowConvert
**************************************************************************

internal const class PowConvert : PointConvert
{
  new make(Str[] args)
  {
    if (args.size != 1) throw ParseErr("Invalid num args $args.size, expected 1")
    exp = args[0].toFloat
  }

  const Float exp

  override Str toStr() { "pow($exp)" }

  override Obj? convert(PointLib lib, Dict rec, Obj? val)
  {
    if (val == null) return null
    num := (Number)val
    in := num.toFloat
    out := in.pow(exp)
    return Number(out, num.unit)
  }
}

**************************************************************************
** MinConvert
**************************************************************************

internal const class MinConvert : PointConvert
{
  new make(Str[] args)
  {
    if (args.size != 1) throw ParseErr("Invalid num args $args.size, expected 1")
    limit = args[0].toFloat
  }

  const Float limit

  override Str toStr() { "min($limit)" }

  override Obj? convert(PointLib lib, Dict rec, Obj? val)
  {
    if (val == null) return null
    num := (Number)val
    in := num.toFloat
    if (in <= limit) return num
    return Number(limit, num.unit)
  }
}

**************************************************************************
** MaxConvert
**************************************************************************

internal const class MaxConvert : PointConvert
{
  new make(Str[] args)
  {
    if (args.size != 1) throw ParseErr("Invalid num args $args.size, expected 1")
    limit = args[0].toFloat
  }

  const Float limit

  override Str toStr() { "max($limit)" }

  override Obj? convert(PointLib lib, Dict rec, Obj? val)
  {
    if (val == null) return null
    num := (Number)val
    in := num.toFloat
    if (in >= limit) return num
    return Number(limit, num.unit)
  }
}

**************************************************************************
** ResetConvert
**************************************************************************

internal const class ResetConvert : PointConvert
{
  new make(Str[] args)
  {
    if (args.size != 4) throw ParseErr("Invalid num args $args.size, expected 4")
    inLo  = args[0].toFloat
    inHi  = args[1].toFloat
    outLo = args[2].toFloat
    outHi = args[3].toFloat
  }

  const Float inLo
  const Float inHi
  const Float outLo
  const Float outHi

  override Str toStr() { "reset($inLo,$inHi,$outLo,$outHi)" }

  override Obj? convert(PointLib lib, Dict rec, Obj? val)
  {
    if (val == null) return null
    num := (Number)val
    in := num.toFloat

    // clip input
    if (in < inLo) in = inLo
    if (in > inHi) in = inHi

    // compute output
    inDiff := (inHi - inLo).abs
    outDiff := (outHi - outLo).abs
    out := (in - inLo) / inDiff * outDiff
    if (outHi < outLo) out = outLo - out
    else  out = outLo + out
    return Number(out, num.unit)
  }
}

**************************************************************************
** U2SwapEndianConvert
**************************************************************************

internal const class U2SwapEndianConvert : PointConvert
{
  new make(Str[] args)
  {
    if (args.size != 0) throw ParseErr("Invalid num args $args.size, expected 0")
  }

  override Str toStr() { "u2SwapEndian()" }

  override Obj? convert(PointLib lib, Dict rec, Obj? val)
  {
    if (val == null) return null
    num := (Number)val
    int := num.toInt
    swap := int.shiftr(8).and(0xff).or(int.and(0xff).shiftl(8))
    return Number(swap, num.unit)
  }
}


**************************************************************************
** U4SwapEndianConvert
**************************************************************************

internal const class U4SwapEndianConvert : PointConvert
{
  new make(Str[] args)
  {
    if (args.size != 0) throw ParseErr("Invalid num args $args.size, expected 0")
  }

  override Str toStr() { "u4SwapEndian()" }

  override Obj? convert(PointLib lib, Dict rec, Obj? val)
  {
    if (val == null) return null
    num := (Number)val
    int := num.toInt
    swap := int.and(0xff00_0000).shiftr(24)
        .or(int.and(0x00ff_0000).shiftr(8))
        .or(int.and(0x0000_ff00).shiftl(8))
        .or(int.and(0x0000_00ff).shiftl(24))
    return Number(swap, num.unit)
  }
}

**************************************************************************
** EnumConvert
**************************************************************************

internal abstract const class EnumConvert : PointConvert
{
  new make(Str[] args, Str funcName, Bool useChecked := true)
  {
    if (args.size != 1 && args.size != 2) throw ParseErr("Invalid num args $args.size, expected 1 or 2")
    this.enumId = args[0]
    this.checked = args.getSafe(1, "true").toBool
    this.toStr = useChecked ? "$funcName($enumId,$checked)" : "$funcName($enumId)"
  }

  const Str enumId
  const Bool checked
  override const Str toStr

  override final Obj? convert(PointLib lib, Dict rec, Obj? val)
  {
    if (val == null) return null
    def := enumId == "self" ? EnumDef(rec->enum) : lib.enums.get(enumId)
    return doConvert(def, val)
  }

  abstract Obj? doConvert(EnumDef enum, Obj val)
}

internal const class EnumStrToNumberConvert : EnumConvert
{
  new make(Str[] args) : super(args, "enumStrToNumber") {}
  override Obj? doConvert(EnumDef enum, Obj val) { enum.nameToCode(val, checked) }
}

internal const class EnumNumberToStrConvert : EnumConvert
{
  new make(Str[] args) : super(args, "enumNumberToStr") {}
  override Obj? doConvert(EnumDef enum, Obj val) { enum.codeToName(val, checked) }
}

internal const class EnumStrToBoolConvert : EnumConvert
{
  new make(Str[] args) : super(args, "enumStrToBool") {}
  override Obj? doConvert(EnumDef enum, Obj val)
  {
    code := enum.nameToCode(val, checked)
    if (code == null) return null
    return code.toInt != 0
  }
}

internal const class EnumBoolToStrConvert : EnumConvert
{
  new make(Str[] args) : super(args, "enumBoolToStr",false) {}
  override Obj? doConvert(EnumDef enum, Obj val)
  {
    (Bool)val ? enum.trueName : enum.falseName
  }
}


**************************************************************************
** NumberToBoolConvert
**************************************************************************

internal const class NumberToBoolConvert : PointConvert
{
  new make(Str[] args)
  {
    if (args.size != 0) throw ParseErr("Invalid num args $args.size, expected 0")
  }

  override Str toStr() { "numberToBool()" }

  override Obj? convert(PointLib lib, Dict rec, Obj? val)
  {
    if (val == null) return null
    num := (Number)val
    return num.toFloat != 0f
  }
}

**************************************************************************
** NumberToStrConvert
**************************************************************************

/*
  UNDOCUMENTED (no arg Number.toStr is documented)

  // convert a zero based number to an enumerated string value;
  // 0 is "off", 1 is "slow", 2 is "fast", and any other
  // number resolves to null
  numberToStr(off, slow, fast)

*/
internal const class NumberToStrConvert : PointConvert
{
  new make(Str[] args)
  {
    this.enum = args
    this.toStr = "numberToStr(" + enum.join(", ") + ")"
  }

  const Str[] enum

  const override Str toStr

  override Obj? convert(PointLib lib, Dict rec, Obj? val)
  {
    if (val == null) return null
    num := (Number)val
    if (enum.isEmpty) return num.toStr
    ord := num.toInt
    if (ord < 0 || ord >= enum.size) return null
    return enum[ord]
  }
}

**************************************************************************
** BoolToNumberConvert
**************************************************************************

internal const class BoolToNumberConvert : PointConvert
{
  new make(Str[] args)
  {
    if (args.size == 0)
    {
      falseVal = Number.zero
      trueVal = Number.one
    }
    else if (args.size == 2)
    {
      falseVal = Number.fromStr(args[0])
      trueVal = Number.fromStr(args[1])
    }
    else
    {
      throw ParseErr("Invalid num args $args.size, expected 0 or 2")
    }
  }

  override Str toStr() { "boolToNumber($falseVal,$trueVal)" }

  override Obj? convert(PointLib lib, Dict rec, Obj? val)
  {
    if (val == null) return null
    if (val == true) return trueVal
    return falseVal
  }

  const Number falseVal
  const Number trueVal
}

**************************************************************************
** StrToBoolConvert
**************************************************************************

/*
  UNDOCUMENTED

  // convert enum string values to boolean; the first parameter
  // is the false strings and the second parameter is the
  // true strings.  Each parameter may be one or more tokens
  // separated by space or use "*" to indicate a wildcard.
  // If neither false nor true is a match then resolve null
  strToBool(off, on)         // "off" is false; "on" is true
  strToBool(off, *)          // "off" is false; anything else is true
  strToBool(*, on)           // "on" is true; anything else is false
  strToBool(off, slow fast)  // "off" is false, "slow" or "fast" is true
*/
internal const class StrToBoolConvert : PointConvert
{
  new make(Str[] args)
  {
    if (args.size != 2) throw ParseErr("Invalid num args $args.size, expected 2")
    this.falseStrs = parseToks(args[0])
    this.trueStrs = parseToks(args[1])
    if (falseStrs.isEmpty && trueStrs.isEmpty) throw ParseErr("Both false and true are wildcard")

    s := StrBuf().add("strToBool(")
    addToStr(s, falseStrs)
    s.addChar(',').addChar(' ')
    addToStr(s, trueStrs)
    s.addChar(')')
    this.toStr = s.toStr
  }

  static Void addToStr(StrBuf s, Str[] list)
  {
    if (list.isEmpty) s.addChar('*')
    else list.each |x, i| { if (i > 0) s.addChar(' '); s.add(x) }
  }

  static Str[] parseToks(Str s)
  {
    if (s == "*") return Str#.emptyList
    toks := s.split.findAll |tok| { !tok.isEmpty }
    if (toks.isEmpty) throw ParseErr("Invalid StrToBool arg: $s.toCode")
    return toks
  }

  const Str[] falseStrs
  const Str[] trueStrs
  const override Str toStr

  override Obj? convert(PointLib lib, Dict rec, Obj? val)
  {
    if (val == null) return null
    s := val.toStr
    if (falseStrs.contains(s)) return false
    if (trueStrs.contains(s)) return true
    if (falseStrs.isEmpty) return false
    if (trueStrs.isEmpty) return true
    return null
  }
}

**************************************************************************
** StrToNumberConvert
**************************************************************************

internal const class StrToNumberConvert : PointConvert
{
  new make(Str[] args)
  {
    if (args.size > 1) throw ParseErr("Invalid num args $args.size, expected 0 or 1")
    this.checked = args.getSafe(0, "true").toBool
    this.toStr = "strToNumber($checked)"
  }

  const Bool checked
  override const Str toStr

  override Obj? convert(PointLib lib, Dict rec, Obj? val)
  {
    if (val == null) return null
    if (val is Number) return val
    return Number.fromStr(val.toStr, checked)
  }
}

**************************************************************************
** HexToNumberConvert
**************************************************************************

internal const class HexToNumberConvert : PointConvert
{
  new make(Str[] args)
  {
    if (args.size > 1) throw ParseErr("Invalid num args $args.size, expected 0 or 1")
    this.checked = args.getSafe(0, "true").toBool
    this.toStr = "hexToNumber($checked)"
  }

  const Bool checked
  override const Str toStr

  override Obj? convert(PointLib lib, Dict rec, Obj? val)
  {
    if (val == null) return null
    i := Int.fromStr(val.toStr, 16, checked)
    if (i == null) return null
    return Number.makeInt(i)
  }
}

**************************************************************************
** NumberToHexConvert
**************************************************************************

internal const class NumberToHexConvert : PointConvert
{
  new make(Str[] args)
  {
    if (args.size != 0) throw ParseErr("Invalid num args $args.size, expected 0")
  }

  override Str toStr() { "numberToHex()" }

  override Obj? convert(PointLib lib, Dict rec, Obj? val)
  {
    if (val == null) return null
    num := (Number)val
    return num.toInt.toHex
  }
}

**************************************************************************
** LowerConvert
**************************************************************************

internal const class LowerConvert : PointConvert
{
  new make(Str[] args)
  {
    if (args.size != 0) throw ParseErr("Invalid num args $args.size, expected 0")
  }

  override Str toStr() { "lower()" }

  override Obj? convert(PointLib lib, Dict rec, Obj? val)
  {
    if (val == null) return null
    return val.toStr.lower
  }
}

**************************************************************************
** UpperConvert
**************************************************************************

internal const class UpperConvert : PointConvert
{
  new make(Str[] args)
  {
    if (args.size != 0) throw ParseErr("Invalid num args $args.size, expected 0")
  }

  override Str toStr() { "upper()" }

  override Obj? convert(PointLib lib, Dict rec, Obj? val)
  {
    if (val == null) return null
    return val.toStr.upper
  }
}

**************************************************************************
** StrReplaceConvert
**************************************************************************

internal const class StrReplaceConvert : PointConvert
{
  new make(Str[] args)
  {
    if (args.size != 2) throw ParseErr("Invalid num args $args.size, expected 0")
    this.from = args[0]
    this.to   = args[1]
  }

  override Str toStr() { "strReplace(from, to)" }

  override Obj? convert(PointLib lib, Dict rec, Obj? val)
  {
    if (val == null) return null
    return val.toStr.replace(from, to)
  }

  const Str from
  const Str to
}

**************************************************************************
** ThermistorConvert
**************************************************************************

internal const class ThermistorConvert : PointConvert
{
  static Str[] listTables()
  {
    files := ThermistorConvert#.pod.files.findAll |f|
    {
      f.pathStr.startsWith("/thermistor/thermistor-") && f.ext == "csv"
    }
    return files.map |f->Str| { f.basename[11..-1] }
  }

  static File? findTableFile(Str name, Bool checked := true)
  {
    f := ThermistorConvert#.pod.file(`/thermistor/thermistor-${name}.csv`, false)
    if (f != null) return f
    if (checked) throw ParseErr("Uknown thermistor table: $name")
    return null
  }

  new make(Str[] args)
  {
    // lookup ohms,degF CSV file
    if (args.size != 1) throw ParseErr("Invalid num args $args.size, expected 1")
    this.name = args.first
    f := findTableFile(name)

    // parse into memory
    lines := f.readAllLines
    if (lines.first != "ohms,degF") throw Err("Invalid header: $lines.first")
    acc := ThermistorItem[,]
    acc.capacity = lines.size - 1
    lines.each |line, i|
    {
      if (i == 0) return
      toks := line.split(',')
      acc.add(ThermistorItem(toks[0].toFloat, toks[1].toFloat))
    }
    this.items = acc
  }

  override Str toStr() { "thermistor($name)" }

  override Obj? convert(PointLib lib, Dict rec, Obj? val)
  {
    if (val == null) return null
    num := (Number)val
    ohms := num.toFloat
    degF := ohmsToDegF(ohms)
    unit := rec["unit"] as Str
    if (unit == Number.C.symbol || unit == Number.C.name)
      return Number((degF-32f)*5f/9f, Number.C)
    else
      return Number(degF, Number.F)
  }

  Float ohmsToDegF(Float ohms)
  {
    // boundaries outside of table
    if (ohms <= items.first.ohms) return items.first.degF
    if (ohms >= items.last.ohms) return items.last.degF

    // binary search
    i := items.binarySearch(ThermistorItem(ohms, 0f))

    // exact match
    if (i >= 0) return items[i].degF

    // linear interpolation using binary search insertion point
    i = -i - 2
    prev := items[i]
    next := items[i+1]
    ohmsDiff := prev.ohms - next.ohms
    degFDiff := prev.degF - next.degF
    return prev.degF + (ohms - prev.ohms) / ohmsDiff * degFDiff
  }

  const Str name
  const ThermistorItem[] items
}

internal const class ThermistorItem
{
  new make(Float ohms, Float degF) { this.ohms = ohms; this.degF = degF }
  override Str toStr() { "$ohms, $degF" }
  override Int compare(Obj that) { ohms <=> ((ThermistorItem)that).ohms }
  const Float ohms
  const Float degF
}

