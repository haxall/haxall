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
** ItemSelection provides APIs to work with selected Items.
**
@Js
class ItemSelection
{

//////////////////////////////////////////////////////////////////////////
// Selection State
//////////////////////////////////////////////////////////////////////////

  ** Is the current selection empty
  Bool isEmpty() { selected.isEmpty }

  ** Get or set single selection by Item
  Item? item
  {
    get { selected.first }
    set { selectByItem(it) }
  }

  ** Get or set multiple selection by Item
  Item[] items
  {
    get { selected.ro }
    set { selectByItems(it, true) }
  }

  ** Get or set single selection by Item.id
  Obj? id
  {
    get { selected.first?.id }
    set { selectById(it) }
  }

  ** Get or set multiple selection by Item.id
  Ref[] ids
  {
    get { selected.map |x->Ref| { x.id } }
    set { selectByIds(it) }
  }

  ** Get or set single selection by Item.data
  Obj? data
  {
    get { selected.first?.data }
    set { selectByData(it) }
  }

  ** Get or set multiple selection by Item.data
  Obj[] dataList
  {
    get { selected.map |x->Obj| { x.data } }
    set { selectByDataList(it) }
  }

  ** Return number of selected items
  Int size() { items.size }

  ** Return if size is one
  Bool one() { size == 1 }

  ** Return if size is one or more
  Bool oneOrMore() { size >= 1 }

  ** Return if selection should be enabled for given select mode
  Bool enabled(SelectMode mode)
  {
    if (mode === SelectMode.single) return size == 1
    if (mode === SelectMode.multi)  return size > 0
    return false
  }

  ** Clear the selection
  Void clear() { selectByItems(Item#.emptyList, false) }

//////////////////////////////////////////////////////////////////////////
// Membership
//////////////////////////////////////////////////////////////////////////

  ** Is the given item currently selected (keyed by id)
  Bool contains(Item item) { selected.any |x| { x.id == item.id } }

  ** Is this item eligible to be selected.  Advisory for UI enablement; does
  ** not gate add.  Anything selected can always be removed, so there is no
  ** corresponding removal predicate.
  virtual Bool canSelect(Item item) { !item.sni.isTemp }

  ** Hook for the add membership check; default requires the item be
  ** a member of the collection
  @NoDoc protected virtual Bool isMember(Item item) { collection.contains(item) }

  ** Add item to the selection.  In mru mode the item moves to the front and
  ** re-adding an existing item refreshes its recency; otherwise it is appended
  ** to the end.  Overflow past max evicts the oldest.  No-op in append mode if
  ** already present.  Respects mode (single replaces, disabled is a no-op).
  Void add(Item item)
  {
    if (mode.isSingle) return selectByItems([item], true)
    if (!mru && contains(item)) return
    acc := selected.dup.exclude |x| { x.id == item.id }
    if (mru) acc.insert(0, item)
    else acc.add(item)
    selectByItems(acc, true)
  }

  ** Remove item from the selection by id (no-op if not present)
  Void remove(Item item) { selectByItems(selected.exclude |x| { x.id == item.id }, false) }

  ** Toggle item in the selection
  Void toggle(Item item) { if (contains(item)) remove(item); else add(item) }

//////////////////////////////////////////////////////////////////////////
// Implementation
//////////////////////////////////////////////////////////////////////////

  private Void selectByData(Obj? data)
  {
    if (data == null)
      clear
    else
      selectByItems([itemByData(data)], false)
  }

  private Void selectById(Ref? id)
  {
    if (id == null)
      clear
    else
      selectByItems([collection.itemById(id)], false)
  }

  private Void selectByItem(Item? item)
  {
    if (item == null)
      clear
    else
      selectByItems([item], true)
  }

  private Void selectByDataList(Obj[] dataList)
  {
    items := dataList.map |d->Item| { itemByData(d) }
    selectByItems(items, false)
  }

  private Item itemByData(Obj data)
  {
    item := collection.list.find |x| { x.data == data }
    if (item != null) return item
    throw UnknownItemErr(""+data)
  }

  private Void selectByIds(Ref[] ids)
  {
    items := ids.map |id->Item| { collection.itemById(id) }
    selectByItems(items, false)
  }

  private Void selectByItems(Item[] newSel, Bool check, Bool fire := true)
  {
    if (check)
    {
      newSel.each |x|
      {
        if (!isMember(x)) throw UnknownItemErr("Item not in collection: $x")
      }
    }

    switch (mode)
    {
      case SelectMode.disabled: this.selected = Item#.emptyList
      case SelectMode.single:   this.selected = newSel.size > 1 ? newSel[0..0].ro : newSel.ro
      default:                  this.selected = trimMax(newSel.dup).ro
    }

    if (fire) onSelect(this.selected)
  }

  ** Trim to max entries evicting the oldest; front is oldest in mru mode,
  ** end is oldest otherwise.  No-op if max is zero (unlimited).
  private Item[] trimMax(Item[] sel)
  {
    if (max <= 0 || sel.size <= max) return sel
    return mru ? sel[0..<max] : sel[sel.size-max..-1]
  }

//////////////////////////////////////////////////////////////////////////
// Binding
//////////////////////////////////////////////////////////////////////////

  @NoDoc new make(ItemList collection, SelectMode mode)
  {
    this.collection = collection
    this.mode = mode
  }

  ** Seed initial selection from restored state without firing onSelect.
  ** Applies mode collapse and max trimming; assumes items are in collection.
  @NoDoc Void seed(Item[] items) { selectByItems(items, false, false) }

  @NoDoc virtual Void updateData(ItemList collection)
  {
    if (this.collection === collection) return
    this.collection = collection
    this.clear
  }

  @NoDoc virtual Void updateMode(SelectMode mode)
  {
    if (this.mode === mode) return
    this.mode = mode
    switch (mode)
    {
      case SelectMode.disabled: clear
      case SelectMode.single: if (selected.size > 1) selected = selected[0..0]
    }
  }

  @NoDoc virtual Void onSelect(Item[] selected) {}

//////////////////////////////////////////////////////////////////////////
// State
//////////////////////////////////////////////////////////////////////////

  ** Max entries to retain, or zero for unlimited.  Overflow evicts the oldest.
  Int max := 0

  ** Most-recently-used ordering: add pushes to the front and re-adding an
  ** existing item refreshes its recency.  Default appends to the end.
  Bool mru := false

  @NoDoc ItemList collection := ItemList.empty { private set }
  @NoDoc SelectMode mode := SelectMode.multi { private set }
  private Item[] selected := Item[,]
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
  ** Selection is disabled
  disabled,

  ** Can select only one item
  single,

  ** Can select one or more items
  multi

  @NoDoc Bool isDisabled() { this === disabled }
  @NoDoc Bool isSingle()   { this === single }
  @NoDoc Bool isMulti()    { this === multi }

  @NoDoc Int limit()
  {
    if (isDisabled) return 0
    if (isSingle) return 1
    return Int.maxVal
  }
}

