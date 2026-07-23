//
// Copyright (c) 2026, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   22 Jul 2026  Brian Frank  Creation
//

using xeto
using xetom

**
** Generate Fantom source for each @Gen type as file line edits
**
internal class GenEdits : Step
{
  override Void run()
  {
    info("GenEdits")
    pods.each |pod| { pod.eachType |t| { genType(t) } }
    bombIfErr
  }

  private Void genType(AType t)
  {
    genTypeDoc(t)
    if (t.kind.isEnum) return genEnumItems(t)
    genSlots(t)
    genDeletes(t)
  }

//////////////////////////////////////////////////////////////////////////
// Enum Items
//////////////////////////////////////////////////////////////////////////

  ** Regenerate the enum item list preserving hand-written
  ** ctor args by item name
  private Void genEnumItems(AType t)
  {
    args := enumItemArgs(t)
    acc := Str[,]
    keys := t.spec.enum.keys
    keys.each |key, i|
    {
      if (i > 0) acc.add("")
      acc.addAll(specDoc(t.spec.enum.spec(key), 2))
      acc.add("  " + key + (args[key] ?: "") + (i < keys.size-1 ? "," : ""))
    }
    if (t.items != null)
      edit(t, t.items.start, t.items.end+1, acc)
    else
      edit(t, t.bodyOpen+1, t.bodyOpen+1, acc)
  }

  ** Map existing enum item names to their "(args)" text
  private Str:Str enumItemArgs(AType t)
  {
    acc := Str:Str[:]
    if (t.items == null) return acc
    for (i := t.items.start; i <= t.items.end; ++i)
    {
      line := t.file.lines[i].trim
      if (line.startsWith("**")) continue
      if (line.endsWith(",")) line = line[0..-2]
      paren := line.index("(")
      if (paren == null || paren == 0) continue
      name := line[0..<paren]
      if (!line.endsWith(")")) continue
      acc[name] = line[paren..-1]
    }
    return acc
  }

//////////////////////////////////////////////////////////////////////////
// Type Doc
//////////////////////////////////////////////////////////////////////////

  ** Sync the type fandoc from the spec doc
  private Void genTypeDoc(AType t)
  {
    acc := specDoc(t.spec, 0)
    if (acc.isEmpty) return
    if (t.docLines != null)
      edit(t, t.docLines.start, t.docLines.end+1, acc)
    else
      edit(t, t.lines.start, t.lines.start, acc)
  }

//////////////////////////////////////////////////////////////////////////
// Slots
//////////////////////////////////////////////////////////////////////////

  ** Update existing slots in place and insert missing slots
  private Void genSlots(AType t)
  {
    inserts := Str[][,]
    t.spec.slotsOwn.each |x|
    {
      if (isSkipped(t, x)) return
      existing := t.slots.find |s| { s.name == toFanName(x.name) }
      lines := genUnit(t, x, existing)
      if (existing != null)
        edit(t, existing.lines.start, existing.lines.end+1, lines)
      else
        inserts.add(lines)
    }
    genInserts(t, inserts)
  }

  ** Skip slots in the @Gen meta skip list.  Also auto-skip comp
  ** get/set field slots which covariantly narrow their base:
  ** Fantom cannot covariantly override a field, so refinements
  ** like Button's 'style: StyleButton?' are spec-side only.
  ** Getter shapes emit legal covariant method overrides.
  private Bool isSkipped(AType t, Spec x)
  {
    if (t.kind.isComp && !isGetterOnly(x) && XetoUtil.isCovariantOverride(x)) return true
    skip := t.gen.meta["skip"] as Str
    if (skip == null) return false
    return skip.split(',').contains(x.name)
  }

  ** Does this slot override a slot inherited from the base.
  ** An overriding slot's base is the inherited slot; a newly
  ** declared slot's base is its type.
  private Bool isBaseSlot(Spec x)
  {
    x.base != null && x.base.isSlot
  }

  ** Insert missing slots after the last slot or the body open brace
  private Void genInserts(AType t, Str[][] inserts)
  {
    if (inserts.isEmpty) return
    acc := Str[,]
    at := t.bodyOpen + 1
    if (!t.slots.isEmpty) at = t.slots.last.lines.end + 1
    inserts.each |unit, i|
    {
      if (i > 0 || at != t.bodyOpen + 1) acc.add("")
      acc.addAll(unit)
    }
    edit(t, at, at, acc)
  }

  ** Remove slots which are no longer declared by the spec.
  ** Swallow one adjacent blank line so surrounding slots are
  ** left separated by a single blank line.
  private Void genDeletes(AType t)
  {
    lines := t.file.lines
    t.slots.each |s|
    {
      if (t.spec.slotOwn(toXetoName(s.name), false) != null) return
      start := s.lines.start
      endEx := s.lines.end + 1
      if (start-1 > t.bodyOpen && lines[start-1].trim.isEmpty) start--
      else if (endEx < t.lines.end && lines[endEx].trim.isEmpty) endEx++
      edit(t, start, endEx, Str[,])
    }
  }

//////////////////////////////////////////////////////////////////////////
// Slot Unit
//////////////////////////////////////////////////////////////////////////

  ** Generate machine owned unit for slot: doc lines and signature
  private Str[] genUnit(AType t, Spec x, ASlot? existing)
  {
    acc := specDoc(x, 2)
    acc.add("  " + sig(t, x, existing))
    return acc
  }

  ** Generate the slot signature line
  private Str sig(AType t, Spec x, ASlot? existing)
  {
    t.kind.isComp ? compSig(t, x, existing) : dictSig(t, x, existing)
  }

  ** Comp slots are fields backed by the comp get/set methods
  private Str compSig(AType t, Spec x, ASlot? existing)
  {
    n := toFanName(x.name)
    s := StrBuf()
    s.add("@Gen ").add(isOverride(t, x, existing) ? "override" : "virtual")
    s.add(" ").add(typeSig(x)).add(" ").add(n)
    if (isGetterOnly(x))
      s.add("() { get(").add(x.name.toCode).add(") }")
    else
      s.add(" { get {get(").add(x.name.toCode).add(")} set {set(").add(x.name.toCode).add(", it)} }")
    return s.toStr
  }

  ** Dict slots are getters.  On a mixin the author picks the style
  ** which we preserve: abstract implemented by the wrapper class, or
  ** concrete backed by get.  A concrete class which is its own
  ** wrapper always uses concrete getters.  New mixin slots default
  ** to abstract.
  private Str dictSig(AType t, Spec x, ASlot? existing)
  {
    s := StrBuf()
    s.add("@Gen ")
    concrete := !t.flags.isMixin || existing?.hasBody == true
    if (!concrete)
    {
      s.add("abstract ")
      if (isOverride(t, x, existing)) s.add("override ")
      s.add(typeSig(x)).add(" ").add(toFanName(x.name)).add("()")
    }
    else
    {
      s.add(isOverride(t, x, existing) ? "override " : "virtual ")
      s.add(typeSig(x)).add(" ").add(toFanName(x.name))
      s.add("() { get(").add(x.name.toCode).add(") }")
    }
    return s.toStr
  }

  ** Slots with readonly meta or in prefixed names are getter only
  private Bool isGetterOnly(Spec x)
  {
    x.meta.has("readonly") || isInSlot(x.name)
  }

  ** Match "in", "inFoo" but not names like "input" or "inversion"
  private Bool isInSlot(Str n)
  {
    n.startsWith("in") && (n.size == 2 || !n[2].isLower)
  }

  ** Override if existing code has override keyword or base declares slot
  private Bool isOverride(AType t, Spec x, ASlot? existing)
  {
    if (existing != null && existing.flags.isOverride) return true
    return isBaseSlot(x)
  }

  ** Fantom type signature via the spec binding
  private Str typeSig(Spec x)
  {
    Str? sig
    if (x.type.isList)
    {
      of := x.of(false)
      sig = (of?.fantomType?.name ?: "Obj?") + "[]"
    }
    else sig = x.type.fantomType.name
    if (x.isMaybe) sig += "?"
    return sig
  }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  ** Map xeto slot name to Fantom slot name
  private Str toFanName(Str n) { n == "readonly" ? "ro" : n }

  ** Map Fantom slot name to xeto slot name
  private Str toXetoName(Str n) { n == "ro" ? "readonly" : n }

  ** Spec doc formatted as fandoc comment lines with given indent.
  ** Type level indent zero wraps with leading/trailing bare ** lines.
  private Str[] specDoc(Spec spec, Int indent)
  {
    doc := spec.metaOwn["doc"] as Str
    if (doc == null) return Str[,]
    lines := doc.splitLines
    while (lines.size > 0 && lines.first.trim.isEmpty) lines.removeAt(0)
    while (lines.size > 0 && lines.last.trim.isEmpty) lines.removeAt(-1)
    if (lines.isEmpty) return Str[,]
    if (indent == 0) { lines.insert(0, ""); lines.add("") }
    return lines.map |s->Str| { (Str.spaces(indent) + "** $s").trimEnd }
  }

  ** Add edit to replace type's file lines [start, endEx) with new lines
  private Void edit(AType t, Int start, Int endEx, Str[] lines)
  {
    t.file.edits.add(AEdit(start, endEx, lines))
  }
}

