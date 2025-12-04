//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   10 Jul 2025  Brian Frank  Creation
//

using concurrent
using util
using xeto
using xetom
using haystack
using axon
using folio
using hx
using hxUtil

**
** ProjCompanion implementation
**
const class HxCompanion : ProjCompanion
{

  new make(HxRuntime rt)
  {
    this.rt = rt
  }

  const HxRuntime rt

  Namespace ns() { rt.ns }

  Folio db() { rt.db }

  override Lib? lib(Bool checked := true)
  {
    ns.lib("proj", checked)
  }

  override Str? libDigest()
  {
    rt.libsRef.companionLibDigest
  }

  override Str? libErrMsg()
  {
    err := ns.libErr("proj")
    if (err == null) return null
    if (err is FileLocErr) return ((FileLocErr)err).loc.toFilenameOnly.toStr + ": " + err.msg
    return err.toStr
  }

//////////////////////////////////////////////////////////////////////////
// CRUD
//////////////////////////////////////////////////////////////////////////

  override Dict[] list()
  {
    acc := Dict[,]
    acc.capacity = 64
    db.readAllEach(Filter.has("name"), Etc.dict0) |rec|
    {
      if (isCompanionRec(rec)) acc.add(rec)
    }
    acc.sort |a, b| { a["name"] <=> b["name"] }
    return acc
  }

  override Dict? read(Str name, Bool checked := true)
  {
    matches := db.readAllList(Filter.eq("name", name))
    match := matches.find |rec| { isCompanionRec(rec) }
    if (match != null) return match
    if (checked) throw UnknownRecErr("No spec or instance for name: $name")
    return null
  }

  override Void add(Dict rec)
  {
    name := validate(rec)
    doUpdate |->|
    {
      if (read(name, false) != null) throw DuplicateNameErr(name)
      db.commit(Diff(null, rec, Diff.add.or(diffFlags)))
    }
  }

  override Void update(Dict rec)
  {
    name := validate(rec)
    doUpdate |->|
    {
      cur := read(name)
      changes := updateDiff(name, cur, rec)
      db.commit(Diff(cur, changes, diffFlags))
    }
  }

  override Void rename(Str oldName, Str newName)
  {
    doUpdate |->|
    {
      cur := read(oldName)
      if (read(newName, false) != null) throw DuplicateNameErr(newName)
      checkName(cur, newName)
      db.commit(Diff(cur, Etc.dict1("name", newName), diffFlags))
    }
  }

  override Void remove(Str name)
  {
    doUpdate |->|
    {
      cur := read(name, false)
      if (cur == null) return
      db.commit(Diff(cur, null, Diff.remove.or(diffFlags)))
    }
  }

  private Void doUpdate(|->| cb)
  {
    lock.lock
    try
      cb()
    finally
      lock.unlock
    rt.libsRef.reload
  }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  private static Dict updateDiff(Str name, Dict oldRec, Dict newRec)
  {
    // first remove an existing spec/isntance tags
    acc := Str:Obj[:]
    Ref? id
    DateTime? mod
    oldRec.each |v, n|
    {
      if (n == "id")   { id = v; return }
      if (n == "mod")  { mod = v; return }
      if (n == "rt" || n == "name") return
      acc[n] = Remove.val
    }

    // add back in the update tag (check name is not modified)
    newRec.each |v, n|
    {
      if (n == "id")  { if (v != id) throw InvalidCompanionRecErr("Cannot change id"); return }
      if (n == "mod") { if (v != mod) throw ConcurrentChangeErr("Rec has been modified"); return }
      if (n == "name" && v != name) throw InvalidCompanionRecErr("Cannot change spec name: $name => $v")
      acc[n] = v
    }
    return Etc.dictFromMap(acc)
  }

  private static Void checkName(Dict rec, Str name)
  {
    rt := rec["rt"] as Str
    switch (rt)
    {
      case "func":     if (!XetoUtil.isFuncName(name)) throw InvalidCompanionRecErr("Invalid func name: $name")
      case "spec":     if (!XetoUtil.isTypeName(name)) throw InvalidCompanionRecErr("Invalid top-level spec name: $name")
      case "instance": if (!XetoUtil.isInstanceName(name)) throw InvalidCompanionRecErr("Invalid instance name: $name")
    }
  }

  static Bool isCompanionRec(Dict rec)
  {
    rt := rec["rt"] as Str
    return rt == "func" || rt == "spec" || rt == "instance"
  }

  private static Str validate(Dict rec)
  {
    name := rec["name"] as Str ?: throw InvalidCompanionRecErr("Missing 'name' tag")
    checkName(rec, name)

    rt := rec["rt"] as Str ?: throw InvalidCompanionRecErr("Missing 'rt' tag")
    if (rt == "func")     return validateSpec(name, rec)
    if (rt == "spec")     return validateSpec(name, rec)
    if (rt == "instance") return validateInstance(name, rec)
    throw InvalidCompanionRecErr("Invalid 'rt' tag: $rt")
  }

  private static Str validateSpec(Str name, Dict rec)
  {
    // verify these tags are _not_ defined
    if (rec.has("qname")) throw InvalidCompanionRecErr("Must not include 'qname' tag")
    if (rec.has("type")) throw InvalidCompanionRecErr("Must not include 'type' tag")

    // check base
    baseRef := validateTypeRef(rec, "base")

    // check spec
    specRef := validateTypeRef(rec, "spec")
    if (specRef.id != "sys::Spec") throw InvalidCompanionRecErr("Invalid 'spec' tag - must be @sys::Spec, not @$specRef")

    // check slots (don't recurse into them)
    validateSlots(rec["slots"])

    return name
  }

  private static Void validateSlots(Obj? slots)
  {
    if (slots == null) return

    grid := slots as Grid ?: throw InvalidCompanionRecErr("Invalid 'slots' tag - must be Grid, not $slots.typeof")
    if (grid.isEmpty) return

    nameCol := grid.col("name", false) ?: throw InvalidCompanionRecErr("Slots grid missing 'name' col")
    typeCol := grid.col("type", false) ?: throw InvalidCompanionRecErr("Slots grid missing 'type' col")
    slotNames := Str:Str[:]

    grid.each |row|
    {
      slotName := row.val(nameCol) as Str ?: throw InvalidCompanionRecErr("Slots grid row missing 'name'")
      typeRef  := row.val(typeCol) as Ref ?: throw InvalidCompanionRecErr("Slots grid row missing 'type'")

      if (slotNames[slotName] != null) throw InvalidCompanionRecErr("Duplicate slot name: $slotName")
      slotNames[slotName] = slotName

      if (!typeRef.id.contains("::")) throw InvalidCompanionRecErr("Slot '$slotName' type must be qname: $typeRef")
    }
  }

  private static Str validateInstance(Str name, Dict rec)
  {
    specRef := rec["spec"] as Ref
    if (specRef?.id == "sys::Spec") throw InvalidCompanionRecErr("Invalid 'spec' tag - must not be @sys::Spec")

    return name
  }

  private static Ref validateTypeRef(Dict rec, Str name)
  {
    val := rec[name]
    if (val == null) throw InvalidCompanionRecErr("Type ref tag '$name' missing")
    ref := val as Ref  ?: throw InvalidCompanionRecErr("Type ref tag '$name' must be Ref, not $val.typeof")
    if (!ref.id.contains("::")) throw InvalidCompanionRecErr("Type ref tag '$name' must be qname: $val")
    return ref
  }

//////////////////////////////////////////////////////////////////////////
// Helper APIs
//////////////////////////////////////////////////////////////////////////

  override Dict parse(Str xeto)
  {
    recs := ns.parseToDicts(xeto, Etc.dict1("rtInclude", Marker.val))
    if (recs.size == 1) return recs.first
    if (recs.isEmpty) throw ArgErr("No xeto specs in source")
    else throw ArgErr("Multiple xeto specs in source")
  }

  override Str print(Dict rec)
  {
    s := StrBuf()
    XetoPrinter(ns, s.out, Etc.dict0).ast(rec)
    return s.toStr
  }

  override Dict func(Str name, Str axon, Dict meta := Etc.dict0)
  {
    toFunc(name, axon, meta)
  }

  override Grid funcSlots(Str axon)
  {
    toFuncSlots(axon)
  }

  static Dict toFunc(Str name, Str axon, Dict meta := Etc.dict0)
  {
    acc := Str:Obj[:]
    meta.each |v, n| { acc[n] = v }
    acc["rt"]    = "func"
    acc["name"]  = name
    acc["spec"]  = specRef
    acc["base"]  = funcRef
    acc["axon"]  = axon
    acc["slots"] = toFuncSlots(axon)
    return Etc.dictFromMap(acc)
  }

  static Grid toFuncSlots(Str axon)
  {
    // parse axon to verify its correct
    fn := Parser(Loc.synthetic, axon.in).parseTop("funcSlots", Etc.dict0)
    gb := GridBuilder()
    gb.addCol("name").addCol("type").addCol("maybe")
    fn.params.each |p|
    {
      gb.addRow([p.name, objRef, Marker.val])
    }
    gb.addRow(["returns", objRef, Marker.val])
    return gb.toGrid
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  static const Ref specRef := Ref("sys::Spec")
  static const Ref funcRef := Ref("sys::Func")
  static const Ref objRef  := Ref("sys::Obj")
  static const Int diffFlags := Diff.bypassRestricted.or(Diff.skipRefNorm)

  private const Lock lock := Lock.makeReentrant

}

