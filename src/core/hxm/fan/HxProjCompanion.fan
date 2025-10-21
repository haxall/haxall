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
    oldRec.each |v, n|
    {
      if (n == "id" || n == "mod" || n == "rt" || n == "name") return
      acc[n] = Remove.val
    }

    // add back in the update tag (check name is not modified)
    newRec.each |v, n|
    {
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
// Old API
//////////////////////////////////////////////////////////////////////////

// TODO: shim code for old API

  override Str[] _list()
  {
    db.readAllList(Filter.eq("rt", "spec")).map |d->Str| { d->name }
  }

  override Str? _read(Str name, Bool checked := true)
  {
    // TODO: need spec or instance
    rec := db.read(Filter.eq("name", name).and(Filter.eq("rt", "spec")))
    s := StrBuf()
    XetoPrinter(rt.ns, s.out, Etc.dict1("noInferMeta", Marker.val)).ast(rec)
    x := s.toStr
    return x

/*
    buf := tb.read("${name}.xeto", false)
    if (buf != null) return readFormat(name, buf)
    if (checked) throw UnknownSpecErr("proj::$name")
    return null
*/
  }

  override Spec _add(Str name, Str body)
  {
    checkName(Etc.dict1("rt", "spec"), name)
    src := writeFormat(name, body)

    recs := ns.parseToDicts(src)
    if (recs.size != 1) throw ArgErr()

    rec := Etc.dictMerge(recs.first, ["rt":"spec", "name":name])
    if (db.read(Filter.eq("name", name), false) != null) throw DuplicateNameErr("Duplicate spec name: $name")
    db.commit(Diff(null, rec, Diff.add.or(Diff.bypassRestricted)))

    rt.libsRef.reload
    return lib.spec(name)

/*
    checkName(name)
    checkExists(name, false)
    return doUpdate(name, body)
*/
  }

  override Spec _update(Str name, Str body)
  {
    rec := db.read(Filter.eq("name", name).and(Filter.eq("rt", "spec")))

if (body.startsWith(name))
{
  colon := body.index(":")
  body = body[colon+1..-1]
}

    src := writeFormat(name, body)

    ast := ns.parseToDicts(src)
    if (ast.size != 1) throw ArgErr()

    // TODO: check removing meta, etc
    changes := Str:Obj[:]
    rec.each |v, n|
    {
      if (n == "id" || n == "mod" || n == "rt" || n == "name") return
      changes[n] = Remove.val
    }
    ast.first.each |v, n|
    {
      if (n == "name" && v != name) throw NameErr("Cannot change spec name: $name => $v")
      changes[n] = v
    }

    db.commit(Diff(rec, changes, Diff.bypassRestricted))
    rt.libsRef.reload
    return lib.spec(name)

/*
    checkExists(name, true)
    return doUpdate(name, body)
*/
  }

  override Spec _rename(Str oldName, Str newName)
  {
    checkName(Etc.dict1("rt", "spec"), newName)
    rec := db.read(Filter.eq("name", oldName).and(Filter.eq("rt", "spec")))

    dup := db.read(Filter.eq("name", newName).and(Filter.eq("rt", "spec")), false)
    if (dup != null) throw DuplicateNameErr("Duplicate spec name: $newName")

    db.commit(Diff(rec, Etc.dict1("name", newName), Diff.bypassRestricted))

    rt.libsRef.reload
    return lib.spec(newName)

/*
    checkName(newName)
    checkExists(newName, false)

    body := _read(oldName)
    write(newName, body)
    _remove(oldName)
    return lib.spec(newName)
*/
  }

  override Void _remove(Str name)
  {
    rec := db.read(Filter.eq("name", name).and(Filter.eq("rt", "spec")))
    db.commit(Diff(rec, null, Diff.remove.or(Diff.bypassRestricted)))
    rt.libsRef.reload

/*
    tb.delete("${name}.xeto")
    rt.libsRef.reload
*/
  }

/*
  private Spec _doUpdate(Str name, Str body)
  {
    //write(name, body)
    rt.libsRef.reload
    return lib.spec(name)
  }
*/

//////////////////////////////////////////////////////////////////////////
// Axon Functions
//////////////////////////////////////////////////////////////////////////

  override Spec addFunc(Str name, Str src, Dict meta := Etc.dict0)
  {
    _add(name, funcToXeto(ns, name, src, meta))
  }

  override Spec updateFunc(Str name, Str? src, Dict? meta := null)
  {
    cur     := lib.func(name)
    curSrc  := cur.metaOwn["axon"] ?: throw ArgErr("Func spec missing axon tag: $name")
    curMeta := Etc.dictRemove(cur.metaOwn, "axon")
    return _update(name, funcToXeto(ns, name, src ?: curSrc, meta ?: curMeta))
  }

  static Str funcToXeto(LibNamespace ns, Str name, Str src, Dict meta)
  {
    // parse axon to verify its correct
    fn := Parser(Loc(name), src.in).parseTop(name, meta)

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

//////////////////////////////////////////////////////////////////////////
// Formatting
//////////////////////////////////////////////////////////////////////////

// TODO: scrap this...
  private Str readFormat(Str name, Str buf)
  {
    sb := StrBuf()
    sb.capacity = buf.size
    prelude := true
    buf.eachLine |line|
    {
      if (prelude && line.trim.isEmpty) return
      if (!sb.isEmpty) sb.add("\n")
      if (prelude)
      {
        if (line.startsWith("//")) { sb.add(line); return }
        colon := line.index(":") ?: throw Err("Malformed proj spec: $line")
        line = line[colon+1..-1].trim
        prelude = false
      }
      sb.add(line)
    }
    return sb.toStr
  }

  private Str writeFormat(Str name, Str body)
  {
    buf := StrBuf()
    buf.capacity = name.size + 16 + body.size
    prelude := true
    body.splitLines.each |line|
    {
      line = line.trimEnd
      if (prelude)
      {
        line = line.trimStart
        if (line.isEmpty) return
        if (!line.startsWith("//"))
        {
          buf.add(name).add(": ")
          prelude = false
        }
      }
      buf.add(line).addChar('\n')
    }
    while (!buf.isEmpty && buf[-1] == '\n') buf.remove(-1)
    return buf.toStr
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  private const Lock lock := Lock.makeReentrant

}

