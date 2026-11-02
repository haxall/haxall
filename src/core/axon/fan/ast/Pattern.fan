//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   30 Oct 2026  Brian Frank  Creation
//

using util
using xeto
using xetom::XetoUtil
using haystack

**
** Pattern is the AST node for a switch case pattern.  Patterns are
** not evaluated, they test if a subject matches and bind names to it.
**
@NoDoc @Js
const abstract class Pattern : Expr
{
  new make(FileLoc loc) { this.loc = loc }

  override const FileLoc loc

  ** Return if subject matches and add every name it binds to binds
  abstract Bool match(AxonContext cx, Obj? subject, Str:Obj? binds)

  ** Iterate every name this pattern binds
  virtual Void eachBind(|Str name| f) {}

  override final Obj? eval(AxonContext cx) { throw UnsupportedErr("Pattern cannot be evaluated: $type") }

  ** Map subject to its enum item spec or null if not a valid key
  static Spec? enumItem(Spec enum, Obj? subject)
  {
    key := XetoUtil.enumKey(subject)
    return key == null ? null : enum.enum.spec(key, false)
  }
}

**************************************************************************
** LiteralPattern
**************************************************************************

**
** Matches when subject equals literal using Axon equality, or when
** literal is a DateSpan such as a month and the subject is a Date
** within the span
**
@NoDoc @Js
const class LiteralPattern : Pattern
{
  new make(FileLoc loc, Obj? literal) : super(loc) { this.literal = literal }

  override ExprType type() { ExprType.literalPattern }

  const Obj? literal

  override Bool match(AxonContext cx, Obj? subject, Str:Obj? binds)
  {
    if (subject is Date && literal is DateSpan) return ((DateSpan)literal).contains(subject)
    return Eq.eqVals(literal, subject)
  }

  override Void walk(|Str key, Obj? val| f) { f("val", literal) }

  override Printer print(Printer out) { out.val(literal) }
}

**************************************************************************
** RangePattern
**************************************************************************

** Matches when subject is same type and within inclusive range: "400..499"
@NoDoc @Js
const class RangePattern : Pattern
{
  new make(FileLoc loc, Obj start, Obj end) : super(loc)
  {
    this.start = start
    this.end   = end
  }

  override ExprType type() { ExprType.rangePattern }

  const Obj start

  const Obj end

  override Bool match(AxonContext cx, Obj? subject, Str:Obj? binds)
  {
    subject?.typeof === start.typeof && start <= subject && subject <= end
  }

  override Void walk(|Str key, Obj? val| f)
  {
    f("start", start)
    f("end", end)
  }

  override Printer print(Printer out) { out.val(start).w("..").val(end) }
}

**************************************************************************
** SpecPattern
**************************************************************************

**
** Matches when subject is non-null and fits a spec: "Ahu", "ph::Site".
** For an enum spec a Str subject matches if it is a valid key.
**
@NoDoc @Js
const class SpecPattern : Pattern
{
  new make(TopName spec) : super(spec.loc) { this.spec = spec }

  override ExprType type() { ExprType.specPattern }

  const TopName spec

  override Bool match(AxonContext cx, Obj? subject, Str:Obj? binds)
  {
    if (subject == null) return false
    Spec s := spec.eval(cx)
    return cx.ns.fits(subject, s) || (s.isEnum && enumItem(s, subject) != null)
  }

  override Void walk(|Str key, Obj? val| f) { f("spec", spec) }

  override Printer print(Printer out) { out.expr(spec) }
}

**************************************************************************
** EnumPattern
**************************************************************************

**
** Matches enum item by its key: "CurStatus.ok".  The subject may be
** the Str key or a Fantom value bound to the enum spec.
**
@NoDoc @Js
const class EnumPattern : Pattern
{
  new make(TopName spec, Str item) : super(spec.loc)
  {
    this.spec = spec
    this.item = item
  }

  override ExprType type() { ExprType.enumPattern }

  const TopName spec

  const Str item

  override Bool match(AxonContext cx, Obj? subject, Str:Obj? binds)
  {
    Spec s := spec.eval(cx)
    if (!s.isEnum) throw EvalErr("Not enum spec: $s", cx, loc)
    itemSpec := s.slot(item, false) ?: throw EvalErr("Unknown enum item: ${s}.$item", cx, loc)
    return enumItem(s, subject) === itemSpec && (subject is Str || cx.ns.fits(subject, s))
  }

  override Void walk(|Str key, Obj? val| f)
  {
    f("spec", spec)
    f("item", item)
  }

  override Printer print(Printer out) { out.expr(spec).wc('.').w(item) }
}

**************************************************************************
** DictPattern
**************************************************************************

** Matches dict which fits optional spec and every slot pattern
@NoDoc @Js
const class DictPattern : Pattern
{
  new make(FileLoc loc, SpecPattern? spec, SlotPattern[] slots) : super(loc)
  {
    this.spec  = spec
    this.slots = slots
  }

  override ExprType type() { ExprType.dictPattern }

  const SpecPattern? spec

  const SlotPattern[] slots

  override Bool match(AxonContext cx, Obj? subject, Str:Obj? binds)
  {
    dict := subject as Dict
    if (dict == null) return false
    if (spec != null && !spec.match(cx, dict, binds)) return false
    for (i := 0; i<slots.size; ++i)
      if (!slots[i].match(cx, dict, binds)) return false
    return true
  }

  override Void eachBind(|Str name| f) { slots.each |slot| { slot.eachBind(f) } }

  override Void walk(|Str key, Obj? val| f)
  {
    f("spec", spec)
    f("slots", slots)
  }

  override Printer print(Printer out)
  {
    if (spec != null) spec.print(out).wc(' ')
    out.wc('{')
    slots.each |slot, i|
    {
      if (i > 0) out.comma
      slot.print(out)
    }
    return out.wc('}')
  }
}

**************************************************************************
** SlotPattern
**************************************************************************

**
** Matches dict subject by one of its slots.  The slot must be present
** unless optional, and its value must match the pattern if specified.
**
@NoDoc @Js
const class SlotPattern : Pattern
{
  new make(FileLoc loc, Str name, Pattern? pattern, Bool optional, Str? bind) : super(loc)
  {
    this.name     = name
    this.pattern  = pattern
    this.optional = optional
    this.bind     = bind
  }

  override ExprType type() { ExprType.slotPattern }

  ** Slot name
  const Str name

  ** Constraint on slot value or null for presence check
  const Pattern? pattern

  ** Does slot match when missing: "{area: Number?}"
  const Bool optional

  ** Name to bind slot value to: "{area as a}"
  const Str? bind

  override Bool match(AxonContext cx, Obj? subject, Str:Obj? binds)
  {
    val := ((Dict)subject).get(name)
    if (val == null ? !optional : pattern != null && !pattern.match(cx, val, binds)) return false
    if (bind != null) binds[bind] = val
    return true
  }

  override Void eachBind(|Str name| f) { if (bind != null) f(bind) }

  override Void walk(|Str key, Obj? val| f)
  {
    f("name", name)
    f("pattern", pattern)
    f("optional", optional)
    f("bind", bind)
  }

  override Printer print(Printer out)
  {
    out.w(Etc.isTagName(name) ? name : name.toCode)
    if (pattern != null) out.w(": ").expr(pattern)
    if (optional) out.wc('?')
    if (bind != null) out.w(" as ").w(bind)
    return out
  }
}

**************************************************************************
** BindPattern
**************************************************************************

** Matches inner pattern and binds the subject to a name: "Ahu as ahu"
@NoDoc @Js
const class BindPattern : Pattern
{
  new make(Pattern inner, Str name) : super(inner.loc)
  {
    this.inner = inner
    this.name  = name
  }

  override ExprType type() { ExprType.bindPattern }

  const Pattern inner

  const Str name

  override Bool match(AxonContext cx, Obj? subject, Str:Obj? binds)
  {
    if (!inner.match(cx, subject, binds)) return false
    binds[name] = subject
    return true
  }

  override Void eachBind(|Str name| f) { inner.eachBind(f); f(name) }

  override Void walk(|Str key, Obj? val| f)
  {
    f("inner", inner)
    f("name", name)
  }

  override Printer print(Printer out) { inner.print(out).w(" as ").w(name) }
}

**************************************************************************
** OrPattern
**************************************************************************

** Matches if any of the alternatives match: "200 or 204"
@NoDoc @Js
const class OrPattern : Pattern
{
  new make(Pattern[] alts) : super(alts.first.loc) { this.alts = alts }

  override ExprType type() { ExprType.orPattern }

  const Pattern[] alts

  override Bool match(AxonContext cx, Obj? subject, Str:Obj? binds)
  {
    for (i := 0; i<alts.size; ++i)
      if (alts[i].match(cx, subject, binds)) return true
    return false
  }

  override Void walk(|Str key, Obj? val| f) { f("alts", alts) }

  override Printer print(Printer out)
  {
    alts.each |alt, i|
    {
      if (i > 0) out.w(" or ")
      alt.print(out)
    }
    return out
  }
}

