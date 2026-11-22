//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   13 Jan 2026  Brian Frank  Creation
//   12 Sep 2026  Brian Frank  Move from ion
//

using util
using xeto
using haystack

**
** ItemSelection is the API to work with the selected items of a
** collection.  It has no state of its own: the selected ids, the
** collection and the select mode are those of its holder, such as the slots
** of a widget, so setting the selection sets the holder's ids.
**
@Js
abstract class ItemSelection
{

//////////////////////////////////////////////////////////////////////////
// Holder
//////////////////////////////////////////////////////////////////////////

  ** Collection the items are selected from
  @NoDoc protected abstract ItemCollection collection()

  ** None, single item, or multiple items
  @NoDoc protected abstract SelectMode selectMode()

  ** Ids of the selected items as the holder stores them.  This is
  ** the only state; to change the selection use `ids`
  @NoDoc protected abstract Ref[] selectedIds

  ** Max entries to retain, or zero for unlimited.  Overflow evicts the oldest.
  virtual Int max() { 0 }

  ** Most-recently-used ordering: add pushes to the front and re-adding an
  ** existing item moves it back to the front.  Default appends to the end.
  virtual Bool mru() { false }

//////////////////////////////////////////////////////////////////////////
// Selection State
//////////////////////////////////////////////////////////////////////////

  ** Is the current selection empty
  Bool isEmpty() { selectedIds.isEmpty }

  ** Return number of selected items
  Int size() { selectedIds.size }

  ** Return if size is one
  Bool one() { size == 1 }

  ** Return if size is one or more
  Bool oneOrMore() { size >= 1 }

  ** Get or set single selection by Item.id
  Ref? id
  {
    get { selectedIds.first }
    set { ids = it == null ? Ref#.emptyList : Ref[it] }
  }

  ** Get or set multiple selection by Item.id
  Ref[] ids
  {
    get { selectedIds }
    set { select(it, true) }
  }

  ** Get or set single selection by Item
  Item? item
  {
    get { id := this.id; return id == null ? null : collection.itemById(id, false) }
    set { this.id = it?.id }
  }

  ** Get or set multiple selection by Item.  An id which is no
  ** longer in the collection has no item
  Item[] items
  {
    get
    {
      acc := Item[,]
      selectedIds.each |id| { acc.addNotNull(collection.itemById(id, false)) }
      return acc
    }
    set { ids = it.map |x->Ref| { x.id } }
  }

  ** Get or set single selection by Item.data
  Obj? data
  {
    get { item?.data }
    set { ids = it == null ? Ref#.emptyList : [itemByData(it).id] }
  }

  ** Get or set multiple selection by Item.data
  Obj[] dataList
  {
    get { items.map |x->Obj| { x.data } }
    set { ids = it.map |d->Ref| { itemByData(d).id } }
  }

  ** Return if selection should be enabled for given select mode
  Bool enabled(SelectMode mode)
  {
    if (mode === SelectMode.single) return size == 1
    if (mode === SelectMode.multi)  return size > 0
    return false
  }

  ** Clear the selection
  Void clear() { select(Ref#.emptyList, false) }

//////////////////////////////////////////////////////////////////////////
// Membership
//////////////////////////////////////////////////////////////////////////

  ** Is the given item currently selected (keyed by id)
  Bool contains(Item item) { selectedIds.contains(item.id) }

  ** Is this item eligible to be selected.  Advisory for UI enablement; does
  ** not gate add.  Anything selected can always be removed, so there is no
  ** corresponding removal predicate.
  virtual Bool canSelect(Item item) { !item.sni.isTemp }

  ** Hook for the add membership check; default requires the id be
  ** that of an item of the collection
  @NoDoc protected virtual Bool isMember(Ref id) { collection.itemById(id, false) != null }

  ** Add item to the selection.  In mru mode the item goes to the front, as
  ** does an existing item which is added again; otherwise it is appended
  ** to the end.  Overflow past max evicts the oldest.  No-op in append mode if
  ** already present.  Respects mode (single replaces, none is a no-op).
  Void add(Item item)
  {
    if (selectMode.isSingle) return select([item.id], true)
    if (!mru && contains(item)) return
    acc := selectedIds.dup
    acc.remove(item.id)
    if (mru) acc.insert(0, item.id)
    else acc.add(item.id)
    select(acc, true)
  }

  ** Remove item from the selection by id (no-op if not present)
  Void remove(Item item) { select(selectedIds.exclude |x| { x == item.id }, false) }

  ** Toggle item in the selection
  Void toggle(Item item) { if (contains(item)) remove(item); else add(item) }

  ** Remove the ids which are no longer in the collection
  Void prune() { select(selectedIds.findAll |id| { isMember(id) }, false) }

//////////////////////////////////////////////////////////////////////////
// Implementation
//////////////////////////////////////////////////////////////////////////

  private Item itemByData(Obj data)
  {
    collection.list.find |x| { x.data == data } ?: throw UnknownItemErr(data.toStr)
  }

  ** Every change comes thru here: check the ids, apply the mode and
  ** the max, and set the holder only if its ids change
  private Void select(Ref[] newIds, Bool check)
  {
    if (check) newIds.each |id| { if (!isMember(id)) throw UnknownItemErr("Item not in collection: $id") }

    if (selectMode.isNone) newIds = Ref#.emptyList
    else if (selectMode.isSingle) { if (newIds.size > 1) newIds = newIds[0..0] }
    else newIds = trimMax(newIds)

    if (newIds != selectedIds) selectedIds = newIds.toImmutable
  }

  ** Trim to max entries evicting the oldest; front is oldest in mru mode,
  ** end is oldest otherwise.  No-op if max is zero (unlimited).
  private Ref[] trimMax(Ref[] sel)
  {
    if (max <= 0 || sel.size <= max) return sel
    return mru ? sel[0..<max] : sel[sel.size-max..-1]
  }
}

**************************************************************************
** MItemSelection
**************************************************************************

**
** ItemSelection which holds its own collection, mode and ids
**
@NoDoc @Js
class MItemSelection : ItemSelection
{
  new make(ItemCollection collection, SelectMode selectMode, Int max := 0, Bool mru := false)
  {
    this.collection = collection
    this.selectMode = selectMode
    this.max  = max
    this.mru  = mru
  }

  override ItemCollection collection
  override SelectMode selectMode
  override const Int max
  override const Bool mru
  protected override Ref[] selectedIds := Ref#.emptyList
}

**************************************************************************
** SelectMode
**************************************************************************

**
** SelectionMode
**
@Js @Gen
enum class SelectMode
{
  ** Nothing can be selected
  none,

  ** Can select only one item
  single,

  ** Can select one or more items
  multi

  @NoDoc Bool isNone()   { this === none }
  @NoDoc Bool isSingle()   { this === single }
  @NoDoc Bool isMulti()    { this === multi }

  @NoDoc Int limit()
  {
    if (isNone) return 0
    if (isSingle) return 1
    return Int.maxVal
  }
}

