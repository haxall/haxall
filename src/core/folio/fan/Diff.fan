//
// Copyright (c) 2009, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   8 Feb 2009  Brian Frank  Creation
//   9 Nov 2015  Brian Frank  Copy from proj
//

using xeto
using haystack

**
** Diff encapsulates a set of changes to apply to a record.
**
const class Diff
{

//////////////////////////////////////////////////////////////////////////
// Construction
//////////////////////////////////////////////////////////////////////////

  ** Construct a modfication for an existing record.  The oldRec
  ** should be the instance which was read from the project.  Any
  ** tags to add/set/remove should be included in the changes dict.
  ** Use `haystack::Remove.val` to indicate a tag should be removed.
  ** See `makeAdd` to create a Diff for adding a new record to a project.
  new make(Dict? oldRec, Obj? changes, Int flags := 0)
  {
    this.changes = Etc.makeDict(changes)
    this.flags = flags
    if (oldRec == null)
    {
      if (flags.and(add) == 0) throw DiffErr("Must pass 'add' flag if oldRec is null")
      if (this.changes.has("id")) throw DiffErr("Cannot specify 'id' tag if using 'add' flag")
      this.id = Ref.gen
    }
    else
    {
      if (flags.and(add) != 0) throw DiffErr("Cannot pass oldRec if using 'add' flag")
      this.id      = oldRec->id
      this.oldMod  = oldRec->mod
    }

    this.flags = check
  }

  ** Make a Diff to add a new record into the database.
  new makeAdd(Obj? changes, Ref id := Ref.gen)
  {
    this.id = id
    this.changes = Etc.makeDict(changes)
    this.flags = add

    if (this.changes.has("id"))
      throw DiffErr("makeAdd cannot specify 'id' tag")

    this.flags = check
  }

  ** Throw an exception such as InvalidTagValErr if the diff doesn't declare valid tags
  private Int check()
  {
    // check that add/remove aren't transient
    if (isTransient)
    {
      if (isAdd) throw DiffErr("Invalid diff flags: transient + add")
      if (isRemove) throw DiffErr("Invalid diff flags: transient + remove")
    }

    // check for valid add id
    if (isAdd) FolioUtil.checkRecId(id)

    // check tag name and values to insert
    newFlags := flags
    changes.each |Obj? val, Str name|
    {
      FolioUtil.checkTagName(name)
      kind := FolioUtil.checkTagVal(name, val)
      newFlags = newFlags.or(DiffTagRule.check(this, name, kind, val))
    }

    return newFlags
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  ** Target record id
  const Ref id

  ** Timestamp version of `oldRec` or null if adding new record
  const DateTime? oldMod

  ** Original record or null if adding new record
  const Dict? oldRec

  ** Updated record which is null until after commit
  const Dict? newRec

  ** Timestamp version of `newRec` or null
  const DateTime? newMod

  ** Changes applied to `oldRec` with resulting `newRec`
  const Dict changes

  ** Bitmask meta-data for diff
  const Int flags

//////////////////////////////////////////////////////////////////////////
// Flags
//////////////////////////////////////////////////////////////////////////

  ** Flag bitmask for `isAdd`
  static const Int add := 0x01

  ** Flag bitmask for `isRemove`
  static const Int remove  := 0x02

  ** Flag bitmask for `isTransient`
  static const Int transient := 0x04

  ** Flag bitmask for `isForce`
  static const Int force := 0x08

  ** Flag bitmask for `isBypassRestricted`
  @NoDoc static const Int bypassRestricted := 0x10

  ** Flag bitmask add in ctor if curVal or curStatus in changes
  @NoDoc static const Int curVal := 0x20

  ** Flag bitmask indicating changes dict has point tag
  @NoDoc static const Int point := 0x40

  ** Flag bitmask for `force` and `transient`
  static const Int forceTransient := force.or(transient)

  ** Update diff - not an add nor a remove
  Bool isUpdate() { !isAdd && !isRemove }

  ** Flag indicating if adding a new record to the project
  Bool isAdd() { flags.and(add) != 0 }

  ** Flag indicating if remove an existing record from the project
  Bool isRemove() { flags.and(remove) != 0 }

  ** Flag indicating that this diff should not be flushed to
  ** persistent storage (it may or may not be persisted).
  Bool isTransient() { flags.and(transient) != 0 }

  ** Flag indicating that changes should be applied regardless
  ** of other concurrent changes which may be been applied after
  ** the `oldRec` version was read.
  Bool isForce() { flags.and(force) != 0 }

  ** Flag indicating bypass of restricted handling for system
  ** level records such as projMeta, uiMeta, or ext records
  @NoDoc Bool isBypassRestricted() { flags.and(bypassRestricted) != 0 }

  ** Flag indicating curVal or curStatus is in changed tags
  @NoDoc Bool isCurVal() { flags.and(curVal) != 0 }

  ** Flag indicating we are adding new point
  @NoDoc Bool isAddPoint() { isAdd && flags.and(point) != 0 }

//////////////////////////////////////////////////////////////////////////
// Methods
//////////////////////////////////////////////////////////////////////////

  ** Get tag value from old record or null.
  Obj? getOld(Str tag, Obj? def := null) { oldRec?.get(tag, def) }

  ** Get tag value from new record or null.
  Obj? getNew(Str tag, Obj? def := null) { newRec?.get(tag, def) }

  ** String representation
  override Str toStr()
  {
    s := StrBuf()

    if (isAdd) s.addChar('+')
    else if (isRemove) s.addChar('-')
    else s.addChar('^')

    s.add("{id:").add(id.toCode)
    if (newMod != null) s.add(",mod:").add(newMod.toIso)

    first := true
    changes.each |val, name|
    {
      if (name == "id" || name == "mod") return
      s.addChar(',')
      s.add(name)
      if (val !== Marker.val)
      {
        s.addChar(':')
        if (val is Ref)
          s.addChar('@').add(val.toStr)
        else
          s.add(ZincWriter.valToStr(val))
      }
    }
    s.addChar('}')
    return s.toStr
  }

//////////////////////////////////////////////////////////////////////////
// Implementation
//////////////////////////////////////////////////////////////////////////

  ** Explicit access to the fields used by folio
  @NoDoc new makex(Ref id, DateTime newMod, Obj changes, Int flags)
  {
    this.id      = id
    this.newMod  = newMod
    this.changes = changes
    this.flags   = flags
  }

  ** Explicit access to the fields used by folio
  @NoDoc new makeAll(Ref id, DateTime? oldMod, Dict? oldRec, DateTime? newMod, Dict? newRec, Dict changes, Int flags)
  {
    this.id      = id
    this.oldMod  = oldMod
    this.oldRec  = oldRec
    this.newMod  = newMod
    this.newRec  = newRec
    this.changes = changes
    this.flags   = flags
  }

  ** Return string to use for an audit log
  @NoDoc Str toAuditStr()
  {
    try
    {
      s := StrBuf()
      dis := newRec?.dis ?: oldRec?.dis
      s.addChar('@').add(id.toProjRel.id).addChar(' ')
       .addChar('"').add(dis).add("\" => ")

      if (isRemove) return s.add("Remove").toStr
      if (isAdd) return s.add("Add").toStr
      return s.add(ZincWriter.valToStr(changes)).toStr
    }
    catch (Err e) return e.toStr
  }
}

