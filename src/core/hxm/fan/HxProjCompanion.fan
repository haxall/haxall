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
** ProjSpecs implementation
**
const class HxProjCompanion : ProjCompanion
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
      db.commit(Diff(null, rec, Diff.add.or(Diff.bypassRestricted)))
    }
  }

  override Void update(Dict rec)
  {
    name := validate(rec)
    doUpdate |->|
    {
      cur := read(name)
      changes := updateDiff(name, cur, rec)
      db.commit(Diff(cur, changes, Diff.bypassRestricted))
    }
  }

  override Void rename(Str oldName, Str newName)
  {
    doUpdate |->|
    {
      cur := read(oldName)
      checkName(cur, newName)
      if (read(newName, false) != null) throw DuplicateNameErr(newName)
      db.commit(Diff(cur, Etc.dict1("name", newName), Diff.bypassRestricted))
    }
  }

  override Void remove(Str name)
  {
    doUpdate |->|
    {
      cur := read(name)
      db.commit(Diff(cur, null, Diff.remove.or(Diff.bypassRestricted)))
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
    if (rec["rt"] == "instance")
    {
      if (!XetoUtil.isInstanceName(name)) throw InvalidCompanionRecErr("Invalid instance name: $name")
    }
    else
    {
      if (!XetoUtil.isSpecName(name)) throw InvalidCompanionRecErr("Invalid spec name: $name")
    }
  }

  private static Bool isCompanionRec(Dict rec)
  {
    rt := rec["rt"] as Str
    return rt == "spec" || rt == "instance"
  }

  private static Str validate(Dict rec)
  {
    name := rec["name"] as Str ?: throw InvalidCompanionRecErr("Missing 'name' tag")
    checkName(rec, name)

    rt := rec["rt"] as Str ?: throw InvalidCompanionRecErr("Missing 'rt' tag")
    if (rt == "spec") return validateSpec(name, rec)
    if (rt == "instance") return validateInstance(name, rec)
    throw InvalidCompanionRecErr("Invalid 'rt' tag: $rt")
  }

  private static Str validateSpec(Str name, Dict rec)
  {
    // verify these tags are _not_ defined
    if (rec.has("qname")) throw InvalidCompanionRecErr("Must not include 'qname' tag")
    if (rec.has("type")) throw InvalidCompanionRecErr("Must not include 'type' tag")

    // check base
    baseRef := rec["base"] as Ref ?: throw InvalidCompanionRecErr("Missing 'base' ref tag")

    // check spec
    specRef := rec["spec"] as Ref ?: throw InvalidCompanionRecErr("Missing 'spec' ref tag")
    if (specRef.id != "sys::Spec") throw InvalidCompanionRecErr("Invalid 'spec' tag - must be @sys::Spec, not @$specRef")

    // check slots (don't recurse into them)
    slots := rec["slots"]
    if (slots != null && slots isnot Dict) throw InvalidCompanionRecErr("Invalid 'slots' tag - must be Dict, not $slots.typeof")

    return name
  }

  private static Str validateInstance(Str name, Dict rec)
  {
    specRef := rec["spec"] as Ref
    if (specRef?.id == "sys::Spec") throw InvalidCompanionRecErr("Invalid 'spec' tag - must not be @sys::Spec")

    return name
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
    acc := Str:Obj[:]
    meta.each |v, n| { acc[n] = v }
    acc["rt"] = "spec"
    acc["name"] = name
    acc["spec"] = specRef
    acc["base"] = funcRef
    acc["axon"] = axon
    acc["slots"] = funcSlots(axon)
    return Etc.dictFromMap(acc)
  }

  override Dict funcSlots(Str axon)
  {
    // parse axon to verify its correct
    fn := Parser(Loc.synthetic, axon.in).parseTop("funcSlots", Etc.dict0)
    acc := Str:Obj[:]
    acc.ordered = true
    fn.params.each |p|
    {
      acc[p.name] = objMaybeSlot
    }
    acc["returns"] = objMaybeSlot
    return Etc.dictFromMap(acc)
  }

  /*
  static Str funcToXeto(LibNamespace ns, Str name, Str src, Dict meta)
  {

    // use XetoPrinter to write to in-memory buffer
    buf := StrBuf()
    buf.capacity = 100 + src.size
    out := XetoPrinter(ns, buf.out)
    out.omitSpecName = true

    // foo: Func <meta>
    out.specHeader(name, "Func", meta).w(" {")

    // params + returns
    first := true
    fn.params.each |p, i|
    {
      if (first) first = false
      else out.w(", ")
      out.w(p.name).w(": Obj?")
    }
    if (!first) out.w(", ")
    out.w("returns: Obj?\n")

    // axon source
    out.metaInline("axon", src)
    out.w("}")

    return buf.toStr
  }
  */

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  static const Ref specRef := Ref("sys::Spec")
  static const Ref funcRef := Ref("sys::Func")
  static const Ref objRef  := Ref("sys::Obj")
  static const Dict objMaybeSlot := Etc.dict2("type", objRef, "maybe", Marker.val)

  private const Lock lock := Lock.makeReentrant

}

