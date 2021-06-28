//
// Copyright (c) 2015, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   28 Oct 2015  Brian Frank  Creation
//

using concurrent
using haystack
using folio
using hxStore

**
** Rec models an entity record in the Folio database.  It is composed
**   - Dict for persistent tags (including id, mod)
**   - Dict for transient tags
**   - Dict current value of the record (merge of persistent and transient)
**   - Reference to Blob for persistent storage
**
const class Rec
{
  new make(Blob blob, Dict persistent)
  {
    blob.stash = this
    this.blob = blob
    this.id = persistent.id;
    this.id.disVal = persistent.dis
    this.persistentRef.val = persistent;
    this.dictRef.val = persistent;
    this.isTrashRef.val = persistent.has("trash")
  }

  ** Id ref
  const Ref id

  ** Backing store [owned by StoreMgr]
  const Blob blob

  ** String format
  override Str toStr() { "Rec($id.toZinc)" }

  ** Blob handle
  Int handle() { blob.handle }

  ** Dict display
  Str dis() { dict.dis }

  ** Current dict value [owned by IndexMgr]
  Dict dict() { dictRef.val }
  private const AtomicRef dictRef := AtomicRef()

  ** Persistent tags [owned by IndexMgr]
  Dict persistent() { persistentRef.val }
  private const AtomicRef persistentRef := AtomicRef()

  ** Transient tags [owned by IndexMgr]
  Dict transient() { transientRef.val }
  private const AtomicRef transientRef := AtomicRef(Etc.emptyDict)

  ** Is this record marked for trash
  Bool isTrash() { isTrashRef.val }
  private const AtomicBool isTrashRef := AtomicBool()

  ** Ticks for last persistent or transient change [owned by IndexMgr]
  Int ticks() { ticksRef.val }
  private const AtomicInt ticksRef := AtomicInt(1)

  ** Update dict, transient, persistent [IndexMgr only]
  internal Void updateDict(Dict p, Dict t, Int ticks)
  {
    persistentRef.val = p
    transientRef.val = t
    dictRef.val = Etc.dictMerge(p, t)
    isTrashRef.val = p.has("trash")
    ticksRef.val = ticks
  }

  ** Number of times written to backing store [owned by StoreMgr]
  Int numWrites() { numWritesRef.val }
  internal const AtomicInt numWritesRef := AtomicInt()

  ** Used to do watch reference counting
  const AtomicInt numWatches := AtomicInt()

  ** History data as HisItem[]
  HisItem[] hisItems() { hisItemsRef.val }

  ** Update history data [owned by IndexMgr]
  internal This hisUpdate(HisItem[] items)
  {
    t := Etc.dictToMap(transient)
    if (items.isEmpty)
    {
      t.remove("hisSize")
      t.remove("hisStart")
      t.remove("hisEnd")
    }
    else
    {
      t["hisSize"]  = Number(items.size)
      t["hisStart"] = items.first.ts
      t["hisEnd"]   = items.last.ts
    }
    newTransient := Etc.makeDict(t)
    updateDict(persistent, newTransient, Duration.nowTicks)
    hisItemsRef.val = items
    return this
  }
  private const AtomicRef hisItemsRef := AtomicRef(HisItem#.emptyList)

  ** Iterate of all blobs including this rec blob + all dimensions
  Void eachBlob(|Blob b| f)
  {
    f(blob)  // do this last
  }
}

