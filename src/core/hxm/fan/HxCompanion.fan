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

  override Dict[] readAll()
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

  override Dict? readById(Ref id, Bool checked := true)
  {
    rec := db.readById(id, checked)
    if (rec == null) return null
    if (isCompanionRec(rec)) return rec
    if (checked) throw UnknownRecErr("Not companion rec: $id.toCode")
    return null
  }

  override Dict? readByName(Str name, Bool checked := true)
  {
    matches := db.readAllList(Filter.eq("name", name))
    match := matches.find |rec| { isCompanionRec(rec) }
    if (match != null) return match
    if (checked) throw UnknownRecErr("No companion rec name: $name")
    return null
  }

  override Dict add(Dict rec)
  {
    name := validate(rec)
    return doUpdate |->Dict?|
    {
      checkDupName(name)
      return db.commit(Diff(null, rec, Diff.add.or(Diff.bypassRestricted))).newRec
    }
  }

  override Dict update(Dict newRec)
  {
    id := newRec.id
    newName := validate(newRec)
    return doUpdate |->Dict?|
    {
      curRec  := readById(id)
      curName := curRec->name.toStr
      if (curName != newName) checkDupName(newName)
      changes := updateDiff(curRec, newRec)
      return db.commit(Diff(curRec, changes, Diff.bypassRestricted)).newRec
    }
  }

  override Void remove(Ref id)
  {
    doUpdate |->Dict?|
    {
      cur := readById(id)
      db.commit(Diff(cur, null, Diff.remove.or(Diff.bypassRestricted)))
      return null
    }
  }

  private Void checkDupName(Str name)
  {
    nameLower := name.lower
    dup := readAll.find |x| { x->name.toStr.lower == nameLower }
    if (dup != null) throw DuplicateNameErr("'$name' duplicates $dup.id.toCode '${dup->name}'")
  }

  private Dict? doUpdate(|->Dict?| cb)
  {
    lock.lock
    Dict? res
    try
      res = cb()
    finally
      lock.unlock
    rt.libsRef.refresh
    return res
  }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  private static Dict updateDiff(Dict oldRec, Dict newRec)
  {
    // first remove an existing spec/instance tags
    acc := Str:Obj[:]
    Ref? id
    DateTime? mod
    oldRec.each |v, n|
    {
      if (n == "id")   { id = v; return }
      if (n == "mod")  { mod = v; return }
      if (n == "rt" || n == "name") return
      acc[n] = None.val
    }

    // add back in the update tag (check name is not modified)
    newRec.each |v, n|
    {
      if (n == "id")  { if (v != id) throw InvalidCompanionRecErr("Cannot change id"); return }
      if (n == "mod") { if (v != mod) throw ConcurrentChangeErr("Rec has been modified"); return }
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

  override Dict parse(Str src, Dict? meta := null)
  {
    rec := ns.io.readAst(src, Etc.dict1("rtInclude", Marker.val))
    return Etc.dictMerge(rec, meta)
  }

  override Str print(Dict rec)
  {
    ns.io.writeAstToStr(rec, Etc.dict0)
  }

  override Dict parseAxon(Str name, Str src, Dict? meta := null)
  {
    toFunc(ns, name, src, meta)
  }

  override Str printAxon(Dict rec)
  {
    ns.io.writeAxonToStr(rec, Etc.dict0)
  }

  static Dict toFunc(Namespace ns, Str name, Str src, Dict? meta := null)
  {
    x := ns.io.readAxon(src, Etc.dict0)
    acc := Str:Obj[:] { ordered = true }
    if (meta != null) meta.each |v, n| { acc[n] = v }
    acc["rt"]    = "func"
    acc["name"]  = name
    acc["spec"]  = specRef
    acc["base"]  = funcRef
    acc.setNotNull("axon",  x["axon"])
    acc.setNotNull("doc",   x["doc"])
    acc.setNotNull("slots", x["slots"])
    return Etc.dictFromMap(acc)
  }

  /* TODO
  static Dict toOldFunc(Str name, Str axon, Dict meta := Etc.dict0)
  {
    acc := Str:Obj[:]
    meta.each |v, n| { acc[n] = v }
    acc["rt"]    = "func"
    acc["name"]  = name
    acc["spec"]  = specRef
    acc["base"]  = funcRef
    acc["axon"]  = axon
    acc["slots"] = toOldFuncSlots(axon)
    return Etc.dictFromMap(acc)
  }

  static Grid toOldFuncSlots(Str axon)
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
  */

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  static const Ref specRef := Ref("sys::Spec")
  static const Ref funcRef := Ref("sys::Func")
  static const Ref objRef  := Ref("sys::Obj")

  private const Lock lock := Lock.makeReentrant

}

