//
// Copyright (c) 2016, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   04 Sep 2009  Brian Frank  Creation
//   01 Jan 2016  Brian Frank  Refactor for axon pod
//

using haystack

**
** System library
**
@Js
const class CoreLib
{

//////////////////////////////////////////////////////////////////////////
// Collections
//////////////////////////////////////////////////////////////////////////

  ** Return if two values are equivalent.  Unlike the standard '==' operator
  ** this function will compare the contents of collection values such
  ** as lists, dicts, and grids.  For non-collection values, the result
  ** is the same as the '==' operator.  This function does not work with
  ** lazy grids such as hisRead result.
  @Axon static Obj? _equals(Obj? a, Obj? b) { Etc.eq(a, b) }

  ** Return if a collection is empty: str, list, dict, or grid
  @Axon static Obj? isEmpty(Obj? val)
  {
    if (val is Dict) return ((Dict)val).isEmpty
    return val->isEmpty
  }

  ** Return number of items in str, list, or grid
  @Axon static Number size(Obj? val)
  {
    if (val is Dict) throw argErr("size", val)
    size := (Int)val->size
    return Number(size.toFloat)
  }

  ** Get an item from a collection:
  **   - str(num): get character at index as int (same semantics as Fantom)
  **   - str(range): get string slice (same semantics as Fantom)
  **   - list(num): get item at given index (same semantics as Fantom)
  **   - list(range): get list slice at given index (same semantics as Fantom)
  **   - dict(key): get item with given key or return null
  **   - grid(num): get row at given index
  **   - grid(range): `haystack::Grid.getRange`
  **
  ** The get function maybe be accessed using the '[]' shortcut operator:
  **    list[3]  >>  list.get(3)
  **
  ** See `docSkySpark::AxonLang#getAndTrap`.
  @Axon static Obj? get(Obj? val, Obj? key)
  {
    if (val is Dict) return ((Dict)val).get(key)
    if (key is ObjRange) return val->getRange(((ObjRange)key).toIntRange)
    if (val is Str) return Number.makeInt(((Str)val).get(((Number)key).toInt))
    if (key is Number) key = ((Number)key).toInt
    return val->get(key)
  }

  ** Get an item from a str, list, or grid safely when an index is out of bounds:
  **   - str(num): get a character at index or null if index invalid
  **   - str(range): get safe slice or "" if entire range invalid
  **   - list(num): get item at given index or null is index invalid
  **   - list(range): get list slice with safe index
  **   - grid(num): get row at given index or null if index invalid
  **   - grid(range): `haystack::Grid.getRange` with safe range
  @Axon static Obj? getSafe(Obj? val, Obj? key)
  {
    // key must be int or range
    Range? range := null
    Int index := 0
    if (key is Number)
      index = ((Number)key).toInt
    else
      range = ((ObjRange)key).toIntRange

    // process based on list, grid, or str
    if (val is List)
    {
      x := (List)val
      return range == null ? x.getSafe(index) : x.getRange(toSafeRange(x.size, range))
    }
    else if (val is Grid)
    {
      x := (Grid)val
      return range == null ? x.getSafe(index) : x.getRange(toSafeRange(x.size, range))
    }
    else if (val is Str)
    {
      x := (Str)val
      if (range != null) return x.getRange(toSafeRange(x.size, range))
      char := x.getSafe(index)
      return char <= 0 ? null : Number.makeInt(char)
    }
    else throw Err("Invalid val type: ${val?.typeof}")
  }

  private static Range toSafeRange(Int size, Range r)
  {
    s := r.start; if (s < 0) s = size + s
    e := r.end;   if (e < 0) e = size + e
    if (s >= size || e < 0) return 0..<0
    if (s < 0) s = 0
    if (e >= size) e = size-1
    return s..e
  }

  ** Get the first item from an ordered collection or return null
  ** if the collection is empty:
  **   - list: item at index 0
  **   - grid: first frow
  **   - stream: first item; see `docSkySpark::Streams#first`
  @Axon static Obj? first(Obj? val)
  {
    if (val is MStream) return FirstStream(val).run
    return val->first
  }

  ** Get the last item from an ordered collection or return null
  ** if the collection is empty:
  **   - list: item at index -1
  **   - grid: item at index -1
  **   - stream: last item; see `docSkySpark::Streams#last`
  @Axon static Obj? last(Obj? val)
  {
    if (val is MStream) return LastStream(val).run
    return val->last
  }

  ** If val is a Grid return if it has the given column name.
  ** If val is a Dict return if the given name is mapped to a non-null value.
  @Axon static Obj? has(Obj? val, Str name)
  {
    if (val is Dict) return ((Dict)val).has(name)
    if (val is Grid) return ((Grid)val).has(name)
    throw argErr("has", val)
  }

  ** If val is a Grid return if it does not have given column name.
  ** If val is a Dict, return if the given name is not mapped to a non-null value.
  @Axon static Obj? missing(Obj? val, Str name)
  {
    if (val is Dict) return ((Dict)val).missing(name)
    if (val is Grid) return ((Grid)val).missing(name)
    throw argErr("missing", val)
  }

  ** Return the first match of 'x' in 'val' searching forward, starting
  ** at the specified offset index.  A negative offset may be used to
  ** access from the end of string.  Return null if no occurences are found:
  **  - if 'val' is Str, then 'x' is substring.
  **  - if 'val' is List, then 'x' is item to search.
  @Axon static Obj? index(Obj val, Obj x, Number offset := Number.zero)
  {
    if (val is Str)  { r := ((Str)val).index(x, offset.toInt);  return r == null ? null : Number.makeInt(r) }
    if (val is List) { r := ((List)val).index(x, offset.toInt); return r == null ? null : Number.makeInt(r) }
    throw argErr("index", val)
  }

  ** Return the last match of 'x' in 'val' searching backward, starting
  ** at the specified offset index.  A negative offset may be used to
  ** access from the end of string.  Return null if no occurences are found:
  **  - if 'val' is Str, then 'x' is substring.
  **  - if 'val' is List, then 'x' is item to search.
  @Axon static Obj? indexr(Obj val, Obj x, Number offset := Number.negOne)
  {
    if (val is Str)  { r := ((Str)val).indexr(x, offset.toInt);  return r == null ? null : Number.makeInt(r) }
    if (val is List) { r := ((List)val).indexr(x, offset.toInt); return r == null ? null : Number.makeInt(r) }
    throw argErr("indexr", val)
  }

  ** Return if 'val' contains 'x':
  **  - if 'val' is Str, then 'x' is substring.
  **  - if 'val' is List, then 'x' is item to search.
  **  - if 'val' is Range, then is 'x' inside the range inclusively
  **  - if 'val' is DateSpan, then is 'x' a date in the span
  @Axon static Bool contains(Obj val, Obj? x)
  {
    if (val is Str)  return ((Str)val).contains(x)
    if (val is List) return ((Obj?[])val).contains(x)
    if (val is ObjRange) return ((ObjRange)val).contains(x)
    if (val is DateSpan) return ((DateSpan)val).contains(x)
    throw argErr("contains", val)
  }

  ** Add item to the end of a list and return a new list.
  @Axon static Obj? add(Obj? val, Obj? item)
  {
    if (val is List) return mutList(val).add(item)
    throw argErr("add", val)
  }

  ** Add all the items to the end of a list and return a new list.
  @Axon static Obj? addAll(Obj? val, Obj? items)
  {
    if (val is List) return mutList(val).addAll(items)
    throw argErr("addAll", val)
  }

  ** Set a collection item and return a new collection.
  **  - List: set item by index key
  **  - Dict: set item by key name
  @Axon static Obj? set(Obj? val, Obj? key, Obj? item)
  {
    if (val is List) return mutList(val).set(((Number)key).toInt, item)
    if (val is Dict) return Etc.dictSet(val, key, item)
    throw argErr("set", val)
  }

  ** Merge two Dicts together and return a new Dict.  Any tags
  ** in 'b' are added to 'a'.  If 'b' defines a tag already
  ** in 'a', then it is overwritten by 'b'.  If a tag in 'b' is
  ** mapped to 'Remove.val', then that tag is removed from the
  ** result.
  @Axon static Obj? merge(Obj? a, Obj? b) { Etc.dictMerge(a, b) }

  ** Insert an item into a list at the given index and return a new list.
  @Axon static Obj? insert(Obj? val, Number index, Obj? item)
  {
    if (val is List) return mutList(val).insert(index.toInt, item)
    throw argErr("insert", val)
  }

  ** Insert a list of items at the given index and return a new list.
  @Axon static Obj? insertAll(Obj? val, Number index, Obj? items)
  {
    if (val is List) return mutList(val).insertAll(index.toInt, (List)items)
    throw argErr("insertAll", val)
  }

  ** Remove an item from a collection and return a new collection.
  **  - List: key is index to remove at
  **  - Dict: key is tag name
  @Axon static Obj? remove(Obj? val, Obj? key)
  {
    if (val is List) { list := ((List)val).dup; list.removeAt(((Number)key).toInt); return list }
    if (val is Dict) return Etc.dictRemove(val, key)
    throw argErr("remove", val)
  }

  private static Obj?[] mutList(Obj?[] list) { Obj?[,].addAll(list) }

  ** Create new stream from given collection:
  **   - Grid: stream the rows
  **   - List: stream the items
  **   - Range: stream inclusive range of integers
  ** See `docSkySpark::Streams#stream`.
  @Axon static Obj stream(Obj? val)
  {
    if (val is Grid) return GridStream(val)
    if (val is List) return ListStream(val)
    if (val is ObjRange) return RangeStream(((ObjRange)val).toIntRange)
    throw argErr("stream", val)
  }

  ** Collect stream into a in-memory list or grid.
  ** See `docSkySpark::Streams#collect`.
  @Axon static Obj collect(Obj? stream, Fn? to := null)
  {
    CollectStream(stream, to).run
  }

  ** Truncate stream after given limit is reached.
  ** See `docSkySpark::Streams#limit`.
  @Axon static Obj limit(Obj? stream, Number limit)
  {
    LimitStream(stream, limit.toInt)
  }

  ** Skip the given number of items in a stream.
  ** See `docSkySpark::Streams#skip`.
  @Axon static Obj skip(Obj? stream, Number count)
  {
    c := count.toInt
    if (c <= 0) return stream
    return SkipStream(stream, c)
  }

  ** Sort a list or grid.
  **
  ** If sorting a list, the sorter should be a function
  ** that takes two list items and returns -1, 0, or 1 (typicaly
  ** done with the '<=>' operator.  If no sorter is passed, then
  ** the list is sorted by its natural ordering.
  **
  ** If sorting a grid, the sorter can be a column name
  ** or a function.  If a function, it should take two rows
  ** and return -1, 0, or 1.
  @Axon static Obj? sort(Obj val, Obj? sorter := null)
  {
    CoreLibUtil.sort(val, sorter, true)
  }

  ** Sort a grid by row display name - see `haystack::Grid.sortDis`
  @Axon static Obj? sortDis(Grid val) { val.sortDis }

  ** Reverse sort a list or grid.  This function works just
  ** like `sort` except sorts in reverse.
  @Axon static Obj? sortr(Obj val, Obj? sorter := null)
  {
    CoreLibUtil.sort(val, sorter, false)
  }

  ** Iterate the items of a collection:
  **   - Grid: iterate the rows as (row, index)
  **   - List: iterate the items as (value, index)
  **   - Dict: iterate the name/value pairs (value, name)
  **   - Range: iterate the integer range (integer)
  **   - Stream: iterate items as (val); see `docSkySpark::Streams#each`
  @Axon static Obj? each(Obj val, Fn fn)
  {
    if (val is MStream) return EachStream(val, fn).run
    if (val is Grid) { ((Grid)val).each(toGridIterator(fn)); return null }
    if (val is Dict) { ((Dict)val).each(toDictIterator(fn)); return null }
    if (val is List) { ((List)val).each(toListIterator(fn)); return null }
    if (val is ObjRange) { ((ObjRange)val).toIntRange.each(toRangeIterator(fn)); return null }
    throw argErr("each", val)
  }

  ** Iterate the items of a collection until the given function returns
  ** non-null.  Once non-null is returned, then break the iteration and
  ** return the resulting object.  Return null if the function returns null
  ** for every item.
  **   - Grid: iterate the rows as (row, index)
  **   - List: iterate the items as (val, index)
  **   - Dict: iterate the name/value pairs (val, name)
  **   - Range: iterate the integer range (integer)
  **   - Stream: iterate items as (val); see `docSkySpark::Streams#eachWhile`
  @Axon static Obj? eachWhile(Obj val, Fn fn)
  {
    if (val is MStream) return EachWhileStream(val, fn).run
    if (val is Grid) return ((Grid)val).eachWhile(toGridIterator(fn))
    if (val is Dict) return ((Dict)val).eachWhile(toDictIterator(fn))
    if (val is List) return ((List)val).eachWhile(toListIterator(fn))
    if (val is ObjRange) return ((ObjRange)val).toIntRange.eachWhile(toRangeIterator(fn))
    throw argErr("eachWhile", val)
  }

  ** Map list, dict, or grid by applying the given mapping function.
  **
  ** If mapping a list, the mapping should be a function
  ** that takes '(val)' or '(val, index)'.  It should return
  ** the new value for that index.
  **
  ** If mapping a dict, the mapping should be a function
  ** that takes '(val)' or '(val, name)'.  It should return
  ** the new value for that name.
  **
  ** If mapping a grid, the mapping function takes '(row)' or '(row,index)'
  ** and returns a new dictionary to use for the row.  The resulting
  ** grid shares the original's grid level meta.  Columns
  ** left intact share the old meta-data, new columns have no
  ** meta-data.  If the mapping function returns null, then that row
  ** is removed from the resulting grid (not mapped).
  **
  ** If mapping a range, then the mapping function takes '(integer)', and
  ** returns a list for each mapped integer inte the range.
  **
  ** If mapping a stream, the mapping functions takes '(val)'.
  ** See `docSkySpark::Streams#map`.
  @Axon static Obj? map(Obj val, Fn fn)
  {
    if (val is MStream) return MapStream(val, fn)
    if (val is Grid) return ((Grid)val).map(toGridIterator(fn))
    if (val is Dict) return Etc.dictMap(val, toDictIterator(fn))
    if (val is List) return ((List)val).map(toListIterator(fn))
    if (val is ObjRange) return ((ObjRange)val).toIntRange.map(toRangeIterator(fn))
    throw argErr("map", val)
  }

  ** Map each item in a list or grid to zero or more new items
  ** as a flattened result.
  **
  ** If mapping a list, the mapping should be a function
  ** that takes '(val)' or '(val, index)'.  It should return
  ** the a list of zero or more new values.
  ** See `sys::List.flatMap`.
  **
  ** If mapping a grid, the mapping function takes '(row)' or '(row,index)'
  ** and returns a list of zero or more new Dict rows.
  ** See `haystack::Grid.flatMap`.
  **
  ** If mapping a stream, the mapping functions takes '(val)'.
  ** See `docSkySpark::Streams#flatMap`.
  @Axon static Obj? flatMap(Obj val, Fn fn)
  {
    if (val is MStream) return FlatMapStream(val, fn)
    if (val is Grid) return ((Grid)val).flatMap(toGridIterator(fn))
    if (val is List) return ((List)val).flatMap(toListIterator(fn))
    throw argErr("flatMap", val)
  }

  ** Find the first matching item in a list or grid by
  ** applying the given filter function.  If no match
  ** is found return null.
  **
  ** If working with a list, the filter should be a function
  ** that takes '(val)' or '(val, index)'.  It should return
  ** true to match and return the item.
  **
  ** If working with a dict, the filter should be a function
  ** that takes '(val)' or '(val, name)'.  It should return
  ** true to match and return the item.
  **
  ** If working with a grid, the filter function takes '(row)'
  ** or '(row, index)' and returns true to match and return the row.
  **
  ** If working with a stream, the filter takes '(val)' and returns
  ** true to match.  See `docSkySpark::Streams#find`.
  @Axon static Obj? find(Obj val, Fn fn)
  {
    if (val is MStream) return FindStream(val, fn).run
    if (val is Grid) return ((Grid)val).find(toGridIterator(fn))
    if (val is Dict) return Etc.dictToMap(val).find(toDictIterator(fn))
    if (val is List) return ((List)val).find(toListIterator(fn))
    throw argErr("findAll", val)
  }

  ** Find all the items in a list, dict, or grid by applying
  ** the given filter function.  Also see `find`.
  **
  ** If working with a list, the filter should be a function
  ** that takes '(val)' or '(val, index)'.  It should return
  ** true to keep the item.
  **
  ** If working with a dict, the filter should be a function
  ** that takes '(val)' or '(val, name)'.  It should return
  ** the true to keep the name/value pair.
  **
  ** If working with a grid, the filter function takes '(row)'
  ** or '(row, index)' and returns true to keep the row.  The
  ** resulting grid shares the original's grid meta and columns.
  **
  ** If working with a stream, the filter takes '(val)' and returns
  ** true to match.  See `docSkySpark::Streams#findAll`.
  @Axon static Obj? findAll(Obj val, Fn fn)
  {
    if (val is MStream) return FindAllStream(val, fn)
    if (val is Grid) return ((Grid)val).findAll(toGridIterator(fn))
    if (val is List) return ((List)val).findAll(toListIterator(fn))
    if (val is Dict) return Etc.dictFindAll(val, toDictIterator(fn))
    throw argErr("findAll", val)
  }

  ** Return if all the items in a list, dict, or grid match the
  ** given test function.  If the collection is empty, then return
  ** true.
  **
  ** If working with a list, the function takes '(val)'
  ** or '(val, index)' and returns true or false.
  **
  ** If working with a dict, the function takes '(val)'
  ** or '(val, name)' and returns true or false.
  **
  ** If working with a grid, the function takes '(row)'
  ** or '(row, index)' and returns true or false.
  **
  ** If working with a stream, then function takes '(val)'
  ** and returns true or false.  See `docSkySpark::Streams#all`.
  **
  ** Examples:
  **   [1, 3, 5].all v => v.isOdd  >>  true
  **   [1, 3, 6].all(isOdd)        >>  false
  @Axon static Obj? all(Obj val, Fn fn)
  {
    if (val is MStream) return AllStream(val, fn).run
    if (val is Grid) return ((Grid)val).all(toGridIterator(fn))
    if (val is List) return ((List)val).all(toListIterator(fn))
    if (val is Dict) return Etc.dictAll(val, toDictIterator(fn))
    throw argErr("any", val)
  }

  ** Return if any the items in a list, dict, or grid match the
  ** given test function.  If the collection is empty, then return
  ** false.
  **
  ** If working with a list, the function takes '(val)'
  ** or '(val, index)' and returns true or false.
  **
  ** If working with a dict, the function takes '(val)'
  ** or '(val, name)' and returns true or false.
  **
  ** If working with a grid, the function takes '(row)'
  ** or '(row, index)' and returns true or false.
  **
  ** If working with a stream, then function takes '(val)'
  ** and returns true or false.  See `docSkySpark::Streams#any`.
  **
  ** Examples:
  **   [1, 3, 5].any v => v.isOdd  >>  true
  **   [2, 4, 6].any(isOdd)        >>  false
  @Axon static Obj? any(Obj val, Fn fn)
  {
    if (val is MStream) return AnyStream(val, fn).run
    if (val is Grid) return ((Grid)val).any(toGridIterator(fn))
    if (val is List) return ((List)val).any(toListIterator(fn))
    if (val is Dict) return Etc.dictAny(val, toDictIterator(fn))
    throw argErr("any", val)
  }

  ** Reduce a collection to a single value with the given reducer
  ** function.  The given function is called with each item in the
  ** collection along with a current *accumulation* value.  The accumation
  ** value is initialized to 'init' for the first item, and for every
  ** subsequent item it is the result of the previous item.  Return
  ** the final accumulation value.  Also see `fold` which is preferred
  ** if doing standard rollup such as sum or average.
  **
  ** If working with a list, the function takes '(acc, val, index)'
  ** and returns accumulation value
  **
  ** If working with a grid, the function takes '(acc, row, index)'
  ** and returns accumulation value
  **
  ** If working with a stream, then function takes '(acc, val)'
  ** and returns accumulation value  See `docSkySpark::Streams#reduce`.
  **
  ** Examples:
  **   [2, 5, 3].reduce(0, (acc, val)=>acc+val)  >> 10
  **   [2, 5, 3].reduce(1, (acc, val)=>acc*val)  >> 30
  @Axon
  static Obj? reduce(Obj val, Obj? init, Fn fn)
  {
    cx := AxonContext.curAxon
    if (val is MStream) return ReduceStream(val, init, fn).run
    if (val is Grid) val = ((Grid)val).toRows
    if (val is List) return ((List)val).reduce(init) |acc, item, index| { fn.call(cx, [acc, item, Number(index)]) }
    throw argErr("reduce", val)
  }

  ** Find the given item in a list, and move it to the given index.  All
  ** the other items are shifted accordingly.  Negative indexes may
  ** used to access an index from the end of the list.  If the item is
  ** not found then this is a no op.  Return new list.
  **
  ** Examples:
  **   [10, 11, 12].moveTo(11, 0)  >>  [11, 10, 12]
  **   [10, 11, 12].moveTo(11, -1) >>  [10, 12, 11]
  @Axon static Obj[] moveTo(Obj[] list, Obj? item, Number toIndex)
  {
    list.dup.moveTo(item, toIndex.toInt)
  }

  ** Return the unique items in a collection.  If val is a List
  ** then return `sys::List.unique`.  If val is a Grid then
  ** return `haystack::Grid.unique` where key must be a column
  ** name or list of column names.
  **
  ** Examples:
  **   [1, 1, 2, 2].unique                 >> [1, 2]
  **   grid.unique("geoState")             >> unique states
  **   grid.unique(["geoCity", geoState"]) >> city,state combos
  @Axon static Obj? unique(Obj val, Obj? key := null)
  {
    if (val is List) return ((List)val).unique
    if (val is Grid) return ((Grid)val).unique(key as Obj[] ?: [key])
    throw argErr("unique", val)
  }

  ** Flatten a list to a single level.  If given a list of
  ** grids, then flatten rows to a single grid.  Also see
  ** `sys::List.flatten` and `haystack::Etc.gridFlatten`.
  **
  ** Examples:
  **   // flatten a list of numbers
  **   [1, [2, 3], [4, [5, 6]]].flatten  >>  [1, 2, 3, 4, 5, 6]
  **
  **   // flatten a list of grids
  **   ["Carytown", "Gaithersburg"].map(n=>readAll(siteRef->dis==n)).flatten
  @Axon static Obj flatten(List list)
  {
    if (list.of.fits(Grid#) || list.all |x| { x is Grid })
      return Etc.gridFlatten(list)
    else
      return list.flatten
  }

  ** Convert grid rows into a dict of name/val pairs.  The name/value
  ** pairs are derived from each row using the given functions.  The
  ** functions take '(row, index)'
  @Axon static Dict gridRowsToDict(Grid grid, Fn rowToKey, Fn rowToVal)
  {
    cx := AxonContext.curAxon
    map := Str:Obj?[:]
    args := [null, null]
    grid.each |row, i|
    {
      index := Number.makeInt(i)
      key := rowToKey.call(cx, args.set(0, row).set(1, index))
      val := rowToVal.call(cx, args.set(0, row).set(1, index))
      map[key] = val
    }
    return Etc.makeDict(map)
  }

  ** Convert grid columns into a dict of name/val pairs.  The name/val
  ** paris are derived from each column using the given functions.  The
  ** functions take '(col, index)'
  @Axon static Dict gridColsToDict(Grid grid, Fn colToKey, Fn colToVal)
  {
    cx := AxonContext.curAxon
    map := Str:Obj?[:]
    args := [null, null]
    grid.cols.each |col, i|
    {
      index := Number.makeInt(i)
      key := colToKey.call(cx, args.set(0, col).set(1, index))
      val := colToVal.call(cx, args.set(0, col).set(1, index))
      map[key] = val
    }
    return Etc.makeDict(map)
  }

  ** Given a grid return the types used in each column as a grid
  ** with the following:
  **   - 'name': string name of the column
  **   - 'kind': all the different value kinds in the column separated by "|"
  **   - 'count': total number of rows with column with a non-null value
  ** Also see `readAllTagNames`.
  @Axon static Grid gridColKinds(Grid grid) { CoreLibUtil.gridColKinds(grid) }

  private static Func toGridIterator(Fn fn)
  {
    cx := AxonContext.curAxon
    args := [null, null]
    return |Obj? row, Int i->Obj?|
    {
      fn.call(cx, args.set(0, row).set(1, Number.makeInt(i)))
    }
  }

  private static Func toDictIterator(Fn fn)
  {
    cx := AxonContext.curAxon
    args := [null, null]
    return |Obj? v, Obj? k->Obj?|
    {
      fn.call(cx, args.set(0, v).set(1, k))
    }
  }

  private static Func toListIterator(Fn fn)
  {
    cx := AxonContext.curAxon
    args := [null, null]
    return |Obj? v, Int i->Obj?|
    {
      fn.call(cx, args.set(0, v).set(1, Number.makeInt(i)))
    }
  }

  private static Func toRangeIterator(Fn fn)
  {
    cx := AxonContext.curAxon
    args := [null]
    return |Int i->Obj?|
    {
      fn.call(cx, args.set(0, Number.makeInt(i)))
    }
  }

//////////////////////////////////////////////////////////////////////////
// Fold
//////////////////////////////////////////////////////////////////////////

  ** Fold a list or stream into a single value using given folding function.
  ** The folding function signature must be '(val, acc)' where val is the items
  ** being folded, and acc is an accumulator used to maintain
  ** state between interations.  Lifecycle of a fold:
  **   1. Call 'fn(foldStart, null)', return initial accumulator state
  **   2. Call 'fn(item, acc)' for every item, return new accumulator state
  **   3. Call 'fn(foldEnd, acc)' return final result
  **
  ** See `docSkySpark::Streams#fold` for streaming details.
  **
  ** The fold will short-circuit and halt immediately if the folding
  ** function returns `na()` for the accumulator state. The result of
  ** the fold is `na()` in this case.  A folding function should document
  ** its behavior when a collection contains `na()`.
  **
  ** Built-in folding functions include:
  **   - `count()`
  **   - `sum()`
  **   - `avg()`
  **   - `min()`
  **   - `max()`
  **   - `mean()`
  **   - `median()`
  **   - `rootMeanSquareErr()`
  **   - `meanBiasErr()`
  **   - `standardDeviation()`
  **
  ** Example:
  **   [1, 2, 3, 4].fold(max)  // fold list into its max value
  **   [1, 2, 3, 4].fold(avg)  // fold list into its average value
  **   [1, 2, na(), 3].fold(sum) // => na()
  **
  ** Example of writing your own custom fold function that
  ** used start/end values and has support for na():
  **    average: (val, acc) => do
  **      if (val == foldStart()) return {sum:0, count:0}
  **      if (val == foldEnd()) return acc->sum / acc->count
  **      if (val == na()) return na()
  **      return {sum: acc->sum + val, count: acc->count + 1}
  **    end
  ** Also see `reduce()` which is easier to use if doing your
  ** own simple rollup computation.
  @Axon static Obj? fold(Obj? val, Fn fn)
  {
    if (val is MStream) return FoldStream(val, fn).run

    list := val as List ?: throw argErr("fold", val)
    cx := AxonContext.curAxon
    args := Obj?[foldStartVal, null]
    r := fn.call(cx, args)
    na := list.eachWhile |item|
    {
      r = fn.call(cx, args.set(0, item).set(1, r))
      if (r === NA.val) return r
      return null
    }
    if (na != null) return na
    return fn.call(cx, args.set(0, foldEndVal).set(1, r))
  }

  ** Fold the values of the given column into a single value.
  ** The folding function uses the same semantics as `fold`.
  **
  ** Example:
  **   readAll(site).foldCol("area", sum)
  @Axon static Obj? foldCol(Grid grid, Str colName, Fn fn)
  {
    col := grid.col(colName)
    cx := AxonContext.curAxon
    args := Obj?[foldStartVal, null]
    r := fn.call(cx, args)
    na := grid.eachWhile |row|
    {
      r = fn.call(cx, args.set(0, row.val(col)).set(1, r))
      if (r === NA.val) return r
      return null
    }
    if (na != null) return na
    return fn.call(cx, args.set(0, foldEndVal).set(1, r))
  }

  ** Fold a set of columns in each row into a new folded column
  ** and return a new grid.  The columns to fold are selected by the
  ** 'colSelector' function and removed from the result.  The selector
  ** may be a list of string names or a function which takes a Col
  ** and returns true to select it.  The folding function uses same
  ** semantics as `fold`.
  **
  **
  ** Example:
  **   // consider grid 'g' with the following structure:
  **   a    b    c
  **   ---  ---  ---
  **   1    10   100
  **   2    20   200
  **
  **   // foldCols, add b and c together to create new bc column
  **   g.foldCols(["b", "c"], "bc", sum)
  **
  **   // yields this grid:
  **   a    bc
  **   ---  ---
  **   1    110
  **   2    220
  **
  **   // we could also replace list of col names with a function
  **   colSel: col => col.name == "b" or col.name == "c"
  **   g.foldCols(colSel, "bc", sum)
  @Axon static Grid foldCols(Grid grid, Obj colSelector, Str newColName, Fn fn)
  {
    cx := AxonContext.curAxon

    // figure out which columns we are using for selection
    Col[]? cols := null
    if (colSelector is List)
    {
      cs := (Str[])colSelector
      cols = grid.cols.findAll |c| { cs.contains(c.name) }
    }
    else
    {
      cs := (Fn)colSelector
      csArgs := [null]
      cols = grid.cols.findAll |c| { cs.call(cx, csArgs.set(0, c)) }
    }

    // add new column
    origRows := (Row[])grid->toRows
    removed  := grid.removeCols(cols.map |c->Str| { c.name })
    added    := removed.addCol(newColName, Etc.emptyDict) |ignore, i|
    {
      // fold row cols into new col
      row := origRows[i]
      args := Obj?[foldStartVal, null]
      r := fn.call(cx, args)
      cols.each |col| { r = fn.call(cx, args.set(0, row.val(col)).set(1, r)) }
      return fn.call(cx, args.set(0, foldEndVal).set(1, r))
    }
    return added
  }

  ** The fold start marker value
  @Axon static Obj? foldStart() { foldStartVal }

  ** The fold end marker value
  @Axon static Obj? foldEnd() { foldEndVal }

  private static const Str foldStartVal := "__foldStart__"
  private static const Str foldEndVal   := "__foldEnd__"

  ** Fold multiple values into their total count
  ** Return zero if no values.
  @Axon { meta = ["foldOn":"Obj"] }
  static Obj? count(Obj val, Obj? acc)
  {
    if (val === foldStartVal) return Number.zero
    if (val === foldEndVal) return acc
    return ((Number)acc).increment
  }

  ** Fold multiple values into their numeric sum.
  ** Return null if no values.
  @Axon { meta = ["foldOn":"Number"] }
  static Obj? sum(Obj? val, Obj? acc)
  {
    if (val === foldStartVal) return null
    if (val === foldEndVal) return acc
    if (val === NA.val || acc === NA.val) return NA.val
    if (val == null) return acc

    if (val is Number) return ((Number)val) + (acc ?: Number.zero)
    throw argErr("Cannot sum", val)
  }

  ** Compare two numbers and return the smaller one.  This function
  ** may also be used with `fold` to return the smallest number (or
  ** null if no values).
  **
  ** Examples:
  **   min(7, 4)            >>  4
  **   [7, 2, 4].fold(min)  >>  2
  @Axon { meta = ["foldOn":"Number"] }
  static Obj? min(Obj? val, Obj? acc)
  {
    if (val === foldStartVal) return Number.posInf
    if (val === foldEndVal) return acc == Number.posInf ? null : acc
    if (val === NA.val || acc === NA.val) return NA.val
    if (val == null) return acc
    if (acc == null) return val
    return ((Number)val).min(acc)
  }

  ** Compare two numbers and return the larger one.  This function
  ** may also be used with `fold` to return the largest number (or
  ** null if no values).
  **
  ** Examples:
  **   max(7, 4)            >>  7
  **   [7, 2, 4].fold(max)  >>  7
  @Axon { meta = ["foldOn":"Number"] }
  static Obj? max(Obj? val, Obj? acc)
  {
    if (val === foldStartVal) return foldStartVal
    if (val === foldEndVal)   return acc == foldStartVal ? null : acc
    if (acc === foldStartVal) return val
    if (val === NA.val || acc === NA.val) return NA.val
    if (val == null) return acc
    if (acc == null) return val
    return ((Number)val).max(acc)
  }

  ** Fold multiple values into their standard average or arithmetic
  ** mean.  This function is the same as [math::mean]`mean`.  Null
  ** values are ignored.  Return null if no values.
  **
  ** Example:
  **   [7, 2, 3].fold(avg)  >>  4
  @Axon { meta = ["foldOn":"Number"] }
  static Obj? avg(Obj? val, Obj? acc)
  {
    if (val === foldStartVal) return [Number.zero, Number.zero]
    if (val === NA.val || acc === NA.val) return NA.val
    state := toFoldNumAcc("avg", acc)
    count := state[0]
    total := state[1]
    if (val === foldEndVal) return count.toFloat == 0f ? null : total / count
    if (val == null) return acc
    state[0] = count.increment
    state[1] = total + val
    return state
  }

  ** Fold multiple values to compute the difference between
  ** the max and min value. Return null if no values.
  **
  ** Example:
  **   [7, 2, 3].fold(spread)  >>  5
  @Axon { meta = ["foldOn":"Number"] }
  static Obj? spread(Obj? val, Obj? acc)
  {
    // store state in acc as [min, max]
    if (val === foldStartVal) return [Number.posInf, Number.negInf]
    if (val === NA.val || acc === NA.val) return NA.val
    state := toFoldNumAcc("spread", acc)
    if (val === foldEndVal) return state[0] == Number.posInf ? null : state[1] - state[0]
    if (val == null) return state
    num := (Number)val
    state[0] = num.min(state[0])
    state[1] = num.max(state[1])
    return state
  }

  private static Number[] toFoldNumAcc(Str name, Obj? acc)
  {
    list := acc as List
    if (list != null && list.size == 2) return list
    throw Err("Invalid accumulator; try using fold($name)")
  }

//////////////////////////////////////////////////////////////////////////
// Dict
//////////////////////////////////////////////////////////////////////////

  ** Get the marker value singleton `haystack::Marker.val`
  @Axon static Marker marker() { Marker.val }

  ** Get the remove value singleton `haystack::Remove.val`
  @Axon static Remove removeMarker() { Remove.val }

  ** Get NA not-available singleton `haystack::NA.val`
  @Axon static NA na() { NA.val }

  ** Return if the given string is legal tag name -
  ** see `haystack::Etc.isTagName`
  @Axon static Bool isTagName(Str n) { Etc.isTagName(n) }

  ** Given arbitrary string, convert to a safe tag name -
  ** see `haystack::Etc.toTagName`
  @Axon static Str toTagName(Str n) { Etc.toTagName(n) }

  ** Get the list of names used by a given dict
  @Axon static Obj? names(Dict dict) { Etc.dictNames(dict) }

  ** Get the list of values used by a given dict
  @Axon static Obj? vals(Dict dict) { Etc.dictVals(dict) }

  ** Function for the '->' operator.  If the given value is a dict,
  ** then get a value by name, or throw UnknownNameErr if name not mapped.
  ** If the value is a Ref, then perform a checked 'readById', then perform
  ** the name lookup.
  **
  ** The trap function maybe be accessed using the '->' shortcut operator:
  **    dict->foo  >>>  dict.trap("foo")
  **
  ** See `docSkySpark::AxonLang#getAndTrap`.
  @Axon static Obj? _trap(Obj? val, Str name)
  {
    if (val is Dict)  return ((Dict)val).trap(name, null)
    if (val is Ref) return AxonContext.curAxon.trapRef(val).trap(name, null)
    throw argErr("trap", val)
  }
//////////////////////////////////////////////////////////////////////////
// Grid
//////////////////////////////////////////////////////////////////////////

  ** Get the meta-data from a grid or col as a dict.
  @Axon static Dict meta(Obj? val)
  {
    if (val is Grid) return ((Grid)val).meta
    if (val is Col)  return ((Col)val).meta
    throw argErr("meta", val)
  }

  ** Get the columns from a grid as a list.
  @Axon static Col[] cols(Grid grid) { grid.cols }

  ** Get a column by its name.  If not resolved then
  ** return null or throw UnknownNameErr based on checked flag.
  @Axon static Col? col(Grid grid, Str name, Bool checked := true) { grid.col(name, checked) }

  ** Get the column names a list of strings.
  @Axon static Str[] colNames(Grid grid) { grid.colNames}

  ** If val is a Col, get the column name.
  @Axon static Str name(Obj? val)
  {
    if (val is Col)  return ((Col)val).name
    throw argErr("name", val)
  }

  ** Return new grid with grid level meta-data replaced by given
  ** meta Dict.  Also see `addMeta` and `docSkySpark::Streams#setMeta`.
  @Axon static Obj setMeta(Obj grid, Dict meta)
  {
    if (grid is Grid) return ((Grid)grid).setMeta(meta)
    if (grid is MStream) return SetMetaStream(grid, meta)
    throw argErr("setMeta", grid)
  }

  ** Return new grid with additional grid level meta-data tags.
  ** Tags are added using `merge` conventions.  Also see `setMeta`
  ** and `docSkySpark::Streams#addMeta`.
  @Axon static Obj addMeta(Obj grid, Dict meta)
  {
    if (grid is Grid) return ((Grid)grid).addMeta(meta)
    if (grid is MStream) return AddMetaStream(grid, meta)
    throw argErr("setMeta", grid)
  }

  ** Join two grids by column name.  Current implementation requires:
  **  - grids cannot have conflicting col names (other than join col)
  **  - each row in both grids must have a unique value for join col
  **  - grid level meta is merged
  **  - join column meta is merged
  @Axon static Grid join(Grid a, Grid b, Str joinColName)
  {
    a.join(b, joinColName)
  }

  ** Join a list of grids into a single grid.  See `join`.
  @Axon static Grid joinAll(Grid[] grids, Str joinColName)
  {
    if (grids.isEmpty) throw ArgErr("Grid.joinAll no grids specified")
    if (grids.size == 1) return grids.first
    result := grids.first
    grids.eachRange(1..-1) |x| { result = result.join(x, joinColName) }
    return result
  }

  ** Add a column to a grid by mapping each row to a new cell value.
  ** The 'col' parameter may be a simple String name or may be a
  ** dictionary which must have a "name" tag (any other
  ** tags become column meta-data).  The mapping function takes
  ** '(row)' and returns the new cell values for the column.
  @Axon static Grid addCol(Grid grid, Obj? col, Fn fn)
  {
    Str? name := col as Str
    Dict meta := Etc.emptyDict
    if (col is Dict)
    {
      meta = col
      name = meta->name
    }
    return grid.addCol(name, meta, toGridIterator(fn))
  }

  ** Return a new grid with the given column renamed.
  **
  ** Example:
  **   readAll(site).renameCol("dis", "title")
  @Axon static Grid renameCol(Grid grid, Str oldName, Str newName)
  {
    grid.renameCol(oldName, newName)
  }

  ** Return a new grid with multiple columns renamed.
  ** Mapping must be a dict of old to new names.  Old column names
  ** not found are ignored.
  **
  ** Example:
  **   readAll(site).renameCols({dis:"title", geoAddr:"subtitle"})
  @Axon static Grid renameCols(Grid grid, Dict mapping)
  {
    grid.renameCols((Str:Str)Etc.dictToMap(mapping))
  }

  ** Return a new grid with the columns reordered.  The given list
  ** of names represents the new order and must contain the same current
  ** column names.  Any columns not specified are removed.  Also
  ** see `colNames`, `moveTo`, and `docSkySpark::Streams#reorderCols`.
  **
  ** Example:
  **   // move name to first col, and foo to last col
  **   cols: grid.colNames.moveTo("name", 0).moveTo("foo", -1)
  **   return grid.reorderCols(cols)
  @Axon static Obj reorderCols(Obj grid, Str[] colNames)
  {
    if (grid is Grid) return ((Grid)grid).reorderCols(colNames)
    if (grid is MStream) return ReorderColsStream(grid, colNames)
    throw argErr("reorderCols", grid)
  }

  ** Return a new grid with column meta-data replaced by given meta dict.
  ** Also see `addColMeta` and `docSkySpark::Streams#setColMeta`.
  @Axon static Obj setColMeta(Obj grid, Str name, Dict meta)
  {
    if (grid is Grid) return ((Grid)grid).setColMeta(name, meta)
    if (grid is MStream) return SetColMetaStream(grid, name, meta)
    throw argErr("setColMeta", grid)
  }

  ** Return a new grid with additional column meta-data.
  ** Column meta is added using `merge` conventions.  Also
  ** see `setColMeta` and `docSkySpark::Streams#addColMeta`.
  @Axon static Obj addColMeta(Obj grid, Str name, Dict meta)
  {
    if (grid is Grid) return ((Grid)grid).addColMeta(name, meta)
    if (grid is MStream) return AddColMetaStream(grid, name, meta)
    throw argErr("addColMeta", grid)
  }

  ** Return a new grid with the given column removed.
  ** If the column doesn't exist, then return given grid.
  ** Also see `docSkySpark::Streams#removeCol`.
  @Axon static Obj removeCol(Obj grid, Obj col)
  {
    if (grid is Grid) return ((Grid)grid).removeCol(col)
    if (grid is MStream) return RemoveColsStream(grid, [col])
    throw argErr("removeCol", grid)
  }

  ** Return a new grid with all the given columns removed.
  ** Columns can be Str names or Col instances.
  ** Also see `docSkySpark::Streams#removeCols`.
  @Axon static Obj removeCols(Obj grid, Obj[] cols)
  {
    if (grid is Grid) return ((Grid)grid).removeCols(cols)
    if (grid is MStream) return RemoveColsStream(grid, cols)
    throw argErr("removeCols", grid)
  }

  ** Return a new grid with keeps the given columns, but removes
  ** all the others.  Columns can be Str names or Col instances.
  ** Also see `docSkySpark::Streams#keepCols`.
  @Axon static Obj keepCols(Obj grid, Obj[] cols)
  {
    if (grid is Grid) return ((Grid)grid).keepCols(cols)
    if (grid is MStream) return KeepColsStream(grid, cols)
    throw argErr("keepCols", grid)
  }

  ** Add an additional Dict row to the end of a grid.
  @Axon static Grid addRow(Grid grid, Dict newRow) { addRows(grid, [newRow]) }

  ** Add an list of rows to the end of a grid.
  ** The newRows may be expressed as list of Dict or a Grid.
  @Axon static Grid addRows(Grid grid, Obj newRows)
  {
    // if no new rows return original grid
    newRowsSize := 0
    try
    {
      newRowsSize = (Int)newRows->size
      if (newRowsSize == 0) return grid
    }
    catch (Err e) e.trace

    // build up list of new rows
    rows := Dict[,]
    rows.capacity = grid.size + newRowsSize
    grid.each |row| { rows.add(row) }
    if (newRows is List) rows.addAll(newRows)
    else if (newRows is Grid) ((Grid)newRows).each |row| { rows.add(row) }
    else throw ArgErr("Invalid newRows type: $newRows.typeof")

    // first pass finds all the unique columns, but keep meta
    colNames := Etc.dictsNames(rows)
    if (colNames.isEmpty) throw ArgErr("cols are empty")

    gb := GridBuilder()
    gb.setMeta(grid.meta)
    colNames.each |n, i|  { gb.addCol(n, grid.col(n, false)?.meta) }
    gb.addDictRows(rows)
    return gb.toGrid
  }

  ** Get a column as a list of the cell values ordered by row.
  @Axon static Obj?[] colToList(Grid grid, Obj col) { grid.colToList(col) }

  ** Perform a matrix transpose on the grid.  The cells of the
  ** first column because the display names for the new columns.
  ** Columns 1..n become the new rows.
  @NoDoc @Axon static Grid transpose(Grid grid) { grid.transpose }

  ** Given a grid of records, assign new ids and swizzle all internal
  ** ref tags.  Each row of the grid must have an 'id' tag.  A new id
  ** is generated for each row, and any Ref tags which used one of
  ** the old ids is replaced with the new id.  This function is handy
  ** for copying graphs of recs such as site/equip/point trees.
  @Axon static Grid swizzleRefs(Grid grid)
  {
    oldToNewIds := Ref:Ref[:]
    grid.each |r| { oldToNewIds[r.id] = Ref.gen }
    return grid.map |r|
    {
      map := Str:Obj?[:]
      r.each |v, n| { map[n] = swizzleRefsVal(oldToNewIds, v) }
      return Etc.makeDict(map)
    }
  }

  ** Swizzle utility
  @NoDoc static Obj? swizzleRefsVal(Ref:Ref oldToNewIds, Obj? v)
  {
    if (v == null) return null
    if (v is Ref) return oldToNewIds.get(v, v)
    if (v is List) return ((List)v).map |x| { swizzleRefsVal(oldToNewIds, x) }
    return v
  }

//////////////////////////////////////////////////////////////////////////
// Numeric Stuff
//////////////////////////////////////////////////////////////////////////

  ** Call the specified function the given number
  ** of times passing the counter.
  @Axon static Obj? times(Number times, Fn fn)
  {
    cx := AxonContext.curAxon
    args := Obj?[null]
    times.toInt.times |i| { fn.call(cx, args.set(0, Number(i))) }
    return null
  }

  ** Return if an integer is an odd number.
  @Axon static Obj? isOdd(Number val) { val.toInt.isOdd }

  ** Return if an integer is an even number.
  @Axon static Obj? isEven(Number val) { val.toInt.isEven }

  ** Return absolute value of a number, if null return null
  @Axon static Obj? abs(Number? val) { val?.abs }

  ** Return if 'val' is the Number representation of not-a-number
  @Axon static Bool isNaN(Obj? val) { val is Number && ((Number)val).isNaN }

  ** Return the Number representation of not-a-number
  @Axon static Number nan() { Number.nan }

  ** Return the Number representation positive infinity
  @Axon static Number posInf() { Number.posInf }

  ** Return the Number representation negative infinity
  @Axon static Number negInf() { Number.negInf }

//////////////////////////////////////////////////////////////////////////
// General Time Stuff
//////////////////////////////////////////////////////////////////////////

  ** Return today's Date according to context's time zone
  @Axon static Date today() { Date.today }

  ** Return yesterday's Date according to context's time zone
  @Axon static Date yesterday() { Date.today - 1day}

  ** Return current DateTime according to context's time zone
  @Axon static DateTime now() { DateTime.now }

  ** Return current time as nanosecond ticks since 1 Jan 2000 UTC.
  ** Note that the 64-bit floating point representations of nanosecond
  ** ticks will loose accuracy below the microsecond.
  @Axon static Number nowTicks() { Number(DateTime.nowTicks, Number.ns) }

  ** Return if a timestamp is contained within a Date range.
  ** Range may be any value supported by `toDateSpan`.  Timestamp
  ** may be either a Date or a DateTime.  Also see `contains`.
  **
  ** Examples:
  **   ts.occurred(thisWeek)
  **   ts.occurred(pastMonth())
  **   ts.occurred(2010-01-01..2010-01-15)
  @Axon static Obj? occurred(Obj? ts, Obj? range)
  {
    // ts as date
    if (ts is DateTime) ts = ((DateTime)ts).date
    else if (ts isnot Date) throw argErr("occurred", ts)
    date := (Date)ts

    return toDateSpan(range).contains(date)
  }

//////////////////////////////////////////////////////////////////////////
// Range
//////////////////////////////////////////////////////////////////////////

  ** Start value of a DateSpan, Span or a range.
  @Axon static Obj? start(Obj? val)
  {
    if (val is Span) return ((Span)val).start
    if (val is DateSpan) return ((DateSpan)val).start
    if (val is ObjRange) return ((ObjRange)val).start
    throw argErr("start", val)
  }

  ** End value of a DateSpan, Span, or a range.
  @Axon static Obj? end(Obj? val)
  {
    if (val is Span) return ((Span)val).end
    if (val is DateSpan) return ((DateSpan)val).end
    if (val is ObjRange) return ((ObjRange)val).end
    throw argErr("end", val)
  }

  ** DateSpan for this week as 'sun..sat' (uses locale start of week)
  @Axon static DateSpan thisWeek() { DateSpan.thisWeek }

  ** DateSpan for this month as '1st..28-31'
  @Axon static DateSpan thisMonth() { DateSpan.thisMonth }

  ** DateSpan for this year 'Jan-1..Dec-31'
  @Axon static DateSpan thisYear() { DateSpan.thisYear }

  ** DateSpan for last 7 days as 'today-7days..today'
  @Axon static DateSpan pastWeek() { DateSpan.pastWeek }

  ** DateSpan for last 30days 'today-30days..today'
  @Axon static DateSpan pastMonth() { DateSpan.pastMonth }

  ** DateSpan for this past 'today-365days..today'
  @Axon static DateSpan pastYear() { DateSpan.pastYear }

  ** DateSpan for week previous to this week 'sun..sat' (uses locale start of week)
  @Axon static DateSpan lastWeek() { DateSpan.lastWeek }

  ** DateSpan for month previous to this month '1..28-31'
  @Axon static DateSpan lastMonth() { DateSpan.lastMonth }

  ** DateSpan for year previous to this year 'Jan-1..Dec-31'
  @Axon static DateSpan lastYear() { DateSpan.lastYear}

  ** Convert the following objects into a `haystack::DateSpan`:
  **   - 'Date..Date': starting and ending date
  **   - 'Date..Number': starting date and num of days (day unit required)
  **   - 'Date': one day range
  **   - 'Number': convert as year
  **   - 'Func': function which evaluates to date range
  **   - 'DateTime..DateTime': use starting/ending dates; if end is midnight,
  **     then use previous date
  **   - 'Str': evaluates to `haystack::DateSpan.fromStr`
  **   - null: use projMeta dateSpanDefault or default to today
  **
  ** Examples:
  **   toDateSpan(2010-07-01..2010-07-03)  >>  01-Jul-2010..03-Jul-2010
  **   toDateSpan(2010-07-01..4)           >>  01-Jul-2010..04-Jul-2010
  **   toDateSpan(2010-07-01..60day)       >>  01-Jul-2010..29-Aug-2010
  **   toDateSpan(2010-07)                 >>  01-Jul-2010..31-Jul-2010
  **   toDateSpan(2010)                    >>  01-Jan-2010..31-Dec-2010
  **   toDateSpan(pastWeek) // on 9 Aug    >>  02-Aug-2010..09-Aug-2010
  @Axon static DateSpan toDateSpan(Obj? r)
  {
    if (r == null) return AxonContext.curAxon.toDateSpanDef
    if (r is Fn) r = ((Fn)r).call(AxonContext.curAxon, Obj#.emptyList)
    if (r is DateSpan) return r
    if (r is Date) return DateSpan(r, DateSpan.day)
    if (r is Span) return ((Span)r).toDateSpan
    if (r is Str) return DateSpan.fromStr(r)
    if (r is ObjRange)
    {
      or := (ObjRange)r
      s := or.start
      e := or.end
      if (s is Date) return DateSpan.make(s, e)
      if (s is DateTime && e is DateTime)
      {
        st := (DateTime)s; sd := st.date
        et := (DateTime)e; ed := et.date
        if (et.isMidnight) ed = ed - 1day
        return DateSpan(sd, ed)
      }
    }
    if (r is Number)
    {
      year := ((Number)r).toInt
      if (1900 < year && year < 2100) return DateSpan.makeYear(year)
    }
    throw ArgErr("Cannot convert toDateSpan: $r  $r.typeof")
  }

  ** Use `toSpan`
  @Deprecated { msg = "Use toSpan" }
  @Axon static Span toDateTimeSpan(Obj? a, Obj? b := null) { toSpan(a, b) }

  ** Convert the following objects into a `haystack::Span`:
  **   - 'DateSpan,tz': anything accepted by `toDateSpan` plus a Timezone string
  **   - 'DateTime..DateTime': range of two DateTimes
  @Axon static Span toSpan(Obj? a, Obj? b := null)
  {
    if (a is Span) return a
    if (a is Str) return Span.fromStr(a)
    if (b is Str)
    {
      tz := TimeZone.fromStr(b)
      return toDateSpan(a).toSpan(tz)
    }
    else if (a is ObjRange)
    {
      or := (ObjRange)a
      if (or.start is DateTime && or.end is DateTime) return Span.makeAbs(or.start, or.end)
    }
    else if (b == null)
    {
      return toDateSpan(a).toSpan(TimeZone.cur)
    }
    throw ArgErr("Cannot convert toSpan: $a , $b")
  }

  ** Number of whole days in a span
  @Axon static Number numDays(Obj? span)
  {
    Number(toSpan(span).numDays, Number.day)
  }

  ** Iterate the days of a span.  The 'dates' argument may be any object
  ** converted into a date range by `toDateSpan`.  The given function is
  ** called with a 'Date' argument for each iterated day.
  **
  ** Example:
  **   f: day => echo(day)
  **   eachDay(2010-07-01..2010-07-03, f) >> iterate Jul 1st, 2nd, 3rd
  **   eachDay(2010-07, f)                >> iterate each day of July 2010
  **   eachDay(pastWeek, f)               >> iterate last 7 days
  @Axon static Obj? eachDay(Obj dates, Fn fn)
  {
    cx := AxonContext.curAxon
    args := Obj?[null]
    toDateSpan(dates).eachDay |date| { fn.call(cx, args.set(0, date)) }
    return null
  }

  ** Iterate the months of a span.  The 'dates' argument may be any object
  ** converted into a date range by `toDateSpan`.  The given function is
  ** called with a 'DateSpan' argument for each interated month.
  **
  ** Examples:
  **   // iterate each month in 2010, and echo data range
  **   eachMonth(2010) d => echo(d)
  **
  **   // call f once for current method
  **   eachMonth(today(), f)
  @Axon static Obj? eachMonth(Obj dates, Fn fn)
  {
    cx := AxonContext.curAxon
    args := Obj?[null]
    toDateSpan(dates).eachMonth |span| { fn.call(cx, args.set(0, span)) }
    return null
  }

//////////////////////////////////////////////////////////////////////////
// Date/Time
//////////////////////////////////////////////////////////////////////////

  ** Get year as integer such as 2010 from date or datetime
  @Axon static Obj? year(Obj d)
  {
    Number.makeInt(d->year, unitYear)
  }

  ** Get month as integer between 1 to 12 from date or datetime
  @Axon static Obj? month(Obj d)
  {
    Number.makeInt(((Month)d->month).ordinal + 1, unitMo)
  }

  ** Get day of month as integer between 1 to 31 from date or datetime.
  @Axon static Obj? day(Obj d)
  {
    Number.makeInt(d->day, unitDay)
  }

  ** Get hour of day as integer between 0 to 23 from time or datetime
  @Axon static Obj? hour(Obj t)
  {
    Number.makeInt(t->hour, unitHour)
  }

  ** Get minutes of the time as integer between 0 to 59 from time or datetime
  @Axon static Obj? minute(Obj t)
  {
    Number.makeInt(t->min, unitMin)
  }

  ** Get seconds of the time as integer between 0 to 59 from time or datetime
  @Axon static Obj? second(Obj t)
  {
    Number.makeInt(t->sec, unitSec)
  }

  ** Get weekday as integer from 0 to 6 of Date or DateTime.
  ** Zero indicates Sunday and 6 indicates Saturday
  @Axon static Number weekday(Obj t)
  {
    Number.makeInt(((Weekday)t->weekday).ordinal, unitDay)
  }

  ** Does the given Date or DateTime fall on Sat or Sun
  @Axon static Obj? isWeekend(Obj t)
  {
    w := weekday(t)
    return w.toFloat == 0f || w.toFloat == 6f
  }

  ** Does the given Date or DateTime fall on Mon, Tue, Wed, Thu, or Fri
  @Axon static Obj? isWeekday(Obj t)
  {
    w := weekday(t)
    return w.toFloat != 0f && w.toFloat != 6f
  }

  ** Get timezone as city name string in tzinfo database from datetime.
  ** If the datetime is null then return the environment default timezone.
  @Axon static Obj? tz(DateTime? dt := null) { (dt?.tz ?: TimeZone.cur).name }

  ** Construct a DateTime from a date, time, and timezone name.
  ** If timezone is null, use system default.
  @Axon static Obj? dateTime(Date d, Time t, Str? tz := null)
  {
    d.toDateTime(t, tz == null ? TimeZone.cur : TimeZone(tz))
  }

  **
  ** If val is a DateTime: get date portion of the timestamp.
  ** If val is a Number: construct a date instance from year, month, day
  **
  ** Examples:
  **   now().date         // same as today()
  **   date(2010, 12, 1)  // same as 2010-12-01
  @Axon static Obj? date(Obj val, Number? month := null, Number? day := null)
  {
    if (val is DateTime) return ((DateTime)val).date
    if (val is Number) return Date(((Number)val).toInt, Month.vals[month.toInt-1], day.toInt)
    throw ArgErr("Invalid val type: $val.typeof")
  }

  ** If val is a DateTime: get time portion of the timestamp.
  ** If val is a Number: construct a time instance from hour, minutes,
  ** secs (truncated to nearest second).
  **
  ** Examples:
  **   now().time      // current time
  **   time(20, 45)    // same as 20:45
  @Axon static Obj? time(Obj val, Number? minutes := null, Number secs := Number.zero)
  {
    if (val is DateTime) return ((DateTime)val).time
    if (val is Number) return Time(((Number)val).toInt, minutes.toInt, secs.toInt)
    throw ArgErr("Invalid val type: $val.typeof")
  }

  ** Convert a DateTime or Span to another timezone:
  **    now().toTimeZone("Chicago")
  **    now().toTimeZone("UTC")
  @Axon static Obj? toTimeZone(Obj val, Str tz)
  {
    if (val is DateTime) return ((DateTime)val).toTimeZone(TimeZone.fromStr(tz))
    if (val is Span) return ((Span)val).toTimeZone(TimeZone.fromStr(tz))
    throw ArgErr("Invalid val type: $val.typeof")
  }

  ** Get the number of days in a given month.  The month parameter may be:
  **   - Date: returns number of days in given month (uses month/year, ignores day)
  **   - Number 1-12: returns days in month for current year
  **   - null: returns day in current month
  **
  ** Examples:
  **   numDaysInMonth()            >>>  days in current month
  **   numDaysInMonth(1)           >>>  31day (days in January)
  **   numDaysInMonth(6)           >>>  30day (days in June)
  **   numDaysInMonth(2)           >>>  28day or 29day (days for Feb this year)
  **   numDaysInMonth(2012-02-13)  >>>  29day (days in Feb for leap year)
  @Axon static Number numDaysInMonth(Obj? month := null)
  {
    Date? d
    if (month is Date) d = month
    else if (month is Number) d = Date(Date.today.year, Month.vals[((Number)month).toInt - 1], 1)
    else if (month == null) d = Date.today
    else throw ArgErr("Invalid month arg: $month [$month.typeof]")
    return Number.makeInt(d.month.numDays(d.year), Number.day)
  }

  ** Return if a year is a leap year. Year must be four digit Number such as 2020.
  @Axon static Bool isLeapYear(Number year) { DateTime.isLeapYear(year.toInt) }

  ** Return if a DateTime is in daylight saving time.  For the given DateTime
  ** and its specific timezone, return true if the time is in daylight savings
  ** time or false if standard time.
  @Axon static Bool dst(DateTime dt) { dt.dst }

  ** Given a DateTime in a specific timezone, return the number of hours
  ** in the day.  Dates which transition to DST will be 23 hours and days
  ** which transition back to standard time will be 25 hours.
  @Axon static Number hoursInDay(DateTime dt) { Number(dt.hoursInDay) }

  ** Given a DateTime or Date, return the day of the year.  The result
  ** is a number between 1 and 365 (or 1 to 366 if a leap year).
  @Axon static Number dayOfYear(Obj val) { Number.makeInt(val->dayOfYear, unitDay) }

  ** Given a DateTime or Date, return the week number of the year.  The
  ** result is a number between 1 and 53 using the given start of week weekday
  ** as number 0-6 (defaults start of week for current locale).
  @Axon static Number weekOfYear(Obj val, Number? startOfWeek := null)
  {
    sow := startOfWeek != null ? Weekday.vals[startOfWeek.toInt] : Weekday.localeStartOfWeek
    return Number.makeInt(val->weekOfYear(sow), unitDay)
  }

  ** Return current locale's start of weekday.  Weekday is
  ** returned as integer from 0 (Sunday) to 6 (Saturday).
  @Axon static Number startOfWeek()
  {
    Number.makeInt((Weekday.localeStartOfWeek).ordinal, unitDay)
  }

  ** Given a DateTime return Number of milliseconds since Unix epoch.
  ** The epic is defined as 1-Jan-1970 UTC.  Also see `fromJavaMillis`.
  @Axon static Number toJavaMillis(DateTime dt) { Number(dt.toJava, Number.ms) }

  ** Given Number of milliseconds since Unix epoch return a DateTime.
  ** The epic is defined as 1-Jan-1970 UTC.  If timezone is null, use system
  ** default.  Also see `toJavaMillis`.
  @Axon static DateTime fromJavaMillis(Number millis, Str? tz := null)
  {
    DateTime.fromJava(millis.toInt, tz == null ? TimeZone.cur : TimeZone(tz), false)
  }

//////////////////////////////////////////////////////////////////////////
// Units
//////////////////////////////////////////////////////////////////////////

  ** Given an optional value return true if the SI metric system should be
  ** used.  Return false if the United States customary unit system should be
  ** used.  The following rules are used:
  **   - if val is a dict with `geoCountry` return return false if "US"
  **   - if number or rec with `unit` and unit is known to be a US
  **     customary unit return false (right now we only check
  **     for °F and Δ°F)
  **   - fallback to locale of hosting server, see `sys::Locale`
  **
  ** Examples:
  **    isMetric({geoCountry:"US"})  >>  false
  **    isMetric({geoCountry:"FR"})  >>  true
  **    isMetric(75°F)               >>  false
  **    isMetric({unit:"Δ°C"})       >>  true
  **    isMetric()                   >>  fallback to server locale
  @Axon static Bool isMetric(Obj? val := null)
  {
    if (val is Number)
    {
      unit := ((Number)val).unit
      if (unit != null)
      {
        metric := isUnitMetric(unit)
        if (metric != null) return metric
      }
    }

    if (val is Dict)
    {
      rec := (Dict)val

      geoCountry := rec["geoCountry"]
      if (geoCountry != null) return  geoCountry != "US"

      unit := rec["unit"]
      if (unit != null)
      {
        metric := isUnitMetric(Unit.fromStr(unit))
        if (metric != null) return metric
      }
    }

    return Locale.cur.country != "US"
  }

  private static Bool? isUnitMetric(Unit unit)
  {
    if (unit === Number.F || unit === Number.Fdeg) return false
    if (unit === Number.C || unit === Number.Cdeg) return true
    return null
  }

  ** Given a number return its unit string or null.
  ** If the val is null, then return null.
  @Axon static Str? unit(Number? val) { val?.unit?.toStr }

  ** Return if the two numbers have the same unit.  If either
  ** of the numbers if null return false.
  @Axon static Bool unitsEq(Number? a, Number? b)
  {
    if (a == null || b == null) return false
    return a.unit == b.unit
  }

  ** Convert a number to the given unit.  If the units are not
  ** of the same dimension then an exception is raised.  The
  ** target unit can be a string or a Number.  If target unit
  ** is a Number, then the scalar value is ignored, but by
  ** convention should be 1.  Also see `as()` function to set a
  ** unit without conversion.
  **
  ** Examples:
  **    10kWh.to(1BTU)
  **    10kWh.to("BTU")
  **    75°F.to(1°C)
  **    to(75°F, 1°C)
  @Axon static Number? to(Number? val, Obj? unit)
  {
    if (val == null) return null
    if (unit == null) return Number(val.toFloat)
    u := unit is Number ? ((Number)unit).unit : Number.loadUnit(unit)
    if (val.unit === u) return val
    if (val.unit == null)  return Number(val.toFloat, u)
    if (u == null) return Number(val.toFloat)
    return Number(val.unit.convertTo(val.toFloat, u), u)
  }

  ** Set the unit of a number.  Unlike `to()` function, no conversion of
  ** the scalar of the number is performed.  The target unit can be a
  ** unit string or a number in which case the scalar value of the
  ** unit parameter is ignored (by convention should be 1).
  **
  ** Examples:
  **   75°F.as(1°C)
  **   75°F.as("°C")
  @Axon static Number? _as(Number? val, Obj? unit)
  {
    if (val == null) return null
    if (unit == null) return val
    u := unit is Number ? ((Number)unit).unit : Number.loadUnit(unit)
    if (val.unit === u) return val
    return Number(val.toFloat, u)
  }

//////////////////////////////////////////////////////////////////////////
// Defs
//////////////////////////////////////////////////////////////////////////

  ** Lookup a def by its symbol name (Str or Symbol).  If not
  ** found return null or raise UnknownDefErr based on checked flag.
  ** The result is returned as the definition's normalized dict
  ** representation.
  @Axon static Def? def(Obj symbol, Bool checked := true)
  {
    symbol as Def ?: AxonContext.curAxon.ns.def(symbol.toStr, checked)
  }

  ** List all definitions in the context namespace as Def[].
  @Axon static Def[] defs()
  {
    AxonContext.curAxon.ns.defs.sort
  }

  ** List tag definitions in the context namespace as Def[].
  @Axon static Def[] tags()
  {
    defs := AxonContext.curAxon.ns.findDefs |d| { d.symbol.type.isTag }
    return defs.sort
  }

  ** List term definitions (tags and conjuncts) in the context namespace as Def[].
  @Axon static Def[] terms()
  {
    defs := AxonContext.curAxon.ns.findDefs |d| { d.symbol.type.isTerm }
    return defs.sort
  }

  ** List conjunct definitions in the context namespace as Def[].
  @Axon static Def[] conjuncts()
  {
    defs := AxonContext.curAxon.ns.findDefs |d| { d.symbol.type.isConjunct }
    return defs.sort
  }

  ** List the lib definitions in the context namespace as Def[].
  @NoDoc @Axon static Def[] libs()
  {
    AxonContext.curAxon.ns.feature("lib").defs
  }

  ** Return declared supertypes of the given def.  The result
  ** is effectively the resolved defs of the "is" meta tag.
  @NoDoc @Axon static Def[] supertypes(Obj d)
  {
    AxonContext.curAxon.ns.supertypes(def(d))
  }

  ** Return all declared subtypes of the given def.  This is
  ** effectively all defs which have a declared supertype of def.
  ** Feature keys are not included in results.
  @NoDoc @Axon static Def[] subtypes(Obj d)
  {
    AxonContext.curAxon.ns.subtypes(def(d))
  }

  ** Return if the given def has subtypes.
  @NoDoc @Axon static Bool hasSubtypes(Obj d)
  {
    AxonContext.curAxon.ns.hasSubtypes(def(d))
  }

  ** Return a flatten list of all supertypes of the given def.  This
  ** list always includes the def itself.   The result represents the
  ** complete set of all defs implemented by the given def.
  @NoDoc @Axon static Def[] inheritance(Obj d)
  {
    AxonContext.curAxon.ns.inheritance(def(d))
  }

  ** Return list of defs for given association on the parent.
  ** Association define ontological relationships between definitions.
  @NoDoc @Axon static Def[] associations(Obj parent, Obj association)
  {
    AxonContext.curAxon.ns.associations(def(parent), def(association))
  }

  ** Return list of tags to apply to implement the given def
  @NoDoc @Axon static Def[] implement(Obj d)
  {
    AxonContext.curAxon.ns.implement(def(d))
  }

  ** Reflect the given subject dict into the list of its implemented Def[]
  @NoDoc @Axon static Def[] reflect(Dict dict)
  {
    AxonContext.curAxon.ns.reflect(dict).defs
  }

  ** Generate a child prototype for the given parent dict.  This call
  ** will automatically apply childrenFlatten tags and parent refs.
  @NoDoc @Axon Dict proto(Dict parent, Dict proto)
  {
    AxonContext.curAxon.ns.proto(parent, proto)
  }

  ** Generate a list of children prototypes for the given parent
  ** dict based on all its reflected defs.
  @NoDoc @Axon static Dict[] protos(Dict parent)
  {
    AxonContext.curAxon.ns.protos(parent)
  }

//////////////////////////////////////////////////////////////////////////
// Typing
//////////////////////////////////////////////////////////////////////////

  ** Return a string of the given value's type.  No guarantee is made
  ** for the string's format.  Applications must **not** assume any
  ** specific format, this function is for human consumption only.
  @Axon static Str debugType(Obj? val)
  {
    if (val == null) return "null"
    return val.typeof.qname
  }

  ** Return if an object is a list type
  @Axon static Bool isList(Obj? val) { val is List }

  ** Return if an object is a dict type
  @Axon static Bool isDict(Obj? val) { val is Dict }

  ** Return if an object is a grid type
  @Axon static Bool isGrid(Obj? val) { val is Grid }

  ** Return if an object is a boolean type
  @Axon static Bool isBool(Obj? val) { val is Bool }

  ** Return if an object is a number type
  @Axon static Bool isNumber(Obj? val) { val is Number }

  ** Return if an object is a ref type
  @Axon static Bool isRef(Obj? val) { val is Ref }

  ** Return if an object is a str type
  @Axon static Bool isStr(Obj? val) { val is Str }

  ** Return if an object is a Uri type
  @Axon static Bool isUri(Obj? val) { val is Uri }

  ** Return if an object is a Date type
  @Axon static Bool isDate(Obj? val) { val is Date }

  ** Return if an object is a Time type
  @Axon static Bool isTime(Obj? val) { val is Time }

  ** Return if an object is a DateTime type
  @Axon static Bool isDateTime(Obj? val) { val is DateTime }

  ** Return if an object is a function type
  @Axon static Bool isFunc(Obj? val) { val is Fn}

  ** Return if given string is an Axon keyword
  @Axon static Bool isKeyword(Str val) { Token.isKeyword(val) }

//////////////////////////////////////////////////////////////////////////
// Conversions
//////////////////////////////////////////////////////////////////////////

  ** Convert a number to a hexadecimal string.
  @Axon static Obj? toHex(Number val) { val.toInt.toHex }

  ** Convert a number to its string representation in the given radix (base).
  ** If width is non-null, then leading zeroes are prepended to ensure the
  ** specified width.
  **
  ** Example:
  **   6.toRadix(2) => "110"
  **   255.toRadix(16, 4) => "00ff"
  @Axon static Obj? toRadix(Number val, Number radix, Number? width := null) { val.toInt.toRadix(radix.toInt, width?.toInt) }

  ** Convert an obj to its string representation
  @Axon static Obj? _toStr(Obj? val) { val == null ? "null" : val.toStr }

  ** If val is a list return it, otherwise return '[val]'.
  @Axon static Obj?[] toList(Obj? val) { val as List ?: Obj?[val].toImmutable }

  ** Given an arbitrary object, translate it to a Grid via
  ** `haystack::Etc.toGrid`:
  **   - if grid just return it
  **   - if row in grid of size, return row.grid
  **   - if scalar return 1x1 grid
  **   - if dict return grid where dict is only
  **   - if list of dict return grid where each dict is row
  **   - if list of non-dicts, return one col grid with rows for each item
  **
  ** Example:
  **   // create simple grid with dis,age cols and 3 rows:
  **   [{dis:"Bob", age:30},
  **    {dis:"Ann", age:40},
  **    {dis:"Dan", age:50}].toGrid
  @Axon static Grid toGrid(Obj? val, Dict? meta := null) { Etc.toGrid(val, meta) }

//////////////////////////////////////////////////////////////////////////
// Localization
//////////////////////////////////////////////////////////////////////////

  ** Localize column display names.  For each col which does not have
  ** an explicit dislay name, add a 'dis' tag based on the column name.
  ** Also see `haystack::Grid.colsToLocale` and `docSkySpark::Localization#tags`.
  @Axon static Grid colsToLocale(Grid grid) { grid.colsToLocale }

  ** Get the localized string for the given tag name or qualified name.
  ** If the key is formatted as "pod::name" then route to `sys::Env.locale`,
  ** otherwise to `haystack::Etc.tagToLocale`.
  @Axon static Str toLocale(Str key)
  {
    colons := key.index("::")
    if (colons == null) return Etc.tagToLocale(key)
    pod  := Pod.find(key[0..<colons])
    name := key[colons+2..-1]
    return Env.cur.locale(pod, name)
  }

  ** Evaluate an expression within a specific locale.  This enables
  ** formatting and parsing of localized text using a locale other than
  ** the default for the current context.
  **
  ** Examples:
  **   // format Date in German
  **   localeUse("de", today().format)
  **
  **   // parse Date in German
  **   localeUse("de", parseDate("01 Mär 2021", "DD MMM YYYY"))
  @Axon static Obj? localeUse(Expr locale, Expr expr)
  {
    cx := AxonContext.curAxon
    result := null
    Locale(locale.eval(cx)).use { result = expr.eval(cx) }
    return result
  }

//////////////////////////////////////////////////////////////////////////
// Parsing and Formatting
//////////////////////////////////////////////////////////////////////////

  ** Get display string for dict or the given tag.  If 'name'
  ** is null, then return display text for the entire dict
  ** using `haystack::Etc.dictToDis`.  If 'name' is non-null then format
  ** the tag value using its appropiate 'toLocale' method.
  ** Also see `haystack::Dict.dis`.
  @Axon static Str dis(Dict? dict, Str? name := null, Str? def := "")
  {
    if (dict == null) return "null"
    return dict.dis(name, def)
  }

  ** Get a relative display name.  If the child display name
  ** starts with the parent, then we can strip that as the
  ** common suffix.  Parent and child must be either a Dict or a Str.
  @Axon static Str relDis(Obj parent, Obj child)
  {
    if (parent is Dict) parent = ((Dict)parent).dis
    if (child is Dict) child = ((Dict)child).dis
    return Etc.relDis(parent, child)
  }

  ** Format an object using the current locale and specified format
  ** pattern.  Formatting patterns follow Fantom toLocale conventions:
  **   - `sys::Bool.toLocale`
  **   - `haystack::Number.toLocale`
  **   - `sys::Date.toLocale`
  **   - `sys::Time.toLocale`
  **   - `sys::DateTime.toLocale`
  ** If 'toLocale' method is found, then return 'val.toStr'
  @Axon static Str format(Obj? val, Str? pattern := null)
  {
    if (val == null) return "null"
    m := val.typeof.method("toLocale", false)
    if (m == null) return val.toStr
    return m.callOn(val, [pattern])
  }

  ** Parse a Str into a Bool, legal formats are "true" or "false.  If invalid
  ** format and checked is false return null, otherwise throw ParseErr.
  @Axon static Bool? parseBool(Str val, Bool checked := true) { Bool.fromStr(val, checked) }

  ** Parse a Str into a integer number using the specified radix.
  ** If invalid format and checked is false return null, otherwise
  ** throw ParseErr. This string value *cannot* include a unit (see
  ** parseNumber).
  @Axon static Number? parseInt(Str val, Number radix := Number.ten, Bool checked := true)
  {
    i := Int.fromStr(val, radix.toInt, checked)
    if (i == null) return null
    return Number(i.toFloat)
  }

  ** Parse a Str into a Float.  Representations for infinity and
  ** not-a-number are "-INF", "INF", "NaN".  If invalid format
  ** and checked is false return null, otherwise throw ParseErr.
  ** This string value *cannot* include a unit (see parseNumber).
  @Axon static Number? parseFloat(Str val, Bool checked := true)
  {
    f := Float.fromStr(val, checked)
    if (f == null) return null
    return Number(f)
  }

  ** Parse a Str into a number with an option unit.  If invalid
  ** format and checked is false return null, otherwise throw ParseErr.
  ** Also see `parseInt` and `parseFloat` to parse basic integers and
  ** floating point numbers without a unit.
  @Axon static Number? parseNumber(Str val, Bool checked := true)
  {
    ch := val.isEmpty ? 0 : val[0]
    if (ch.isDigit || ch == '-' || ch == 'N' || ch == 'I')
    {
      try
        return (Number)ZincReader(val.in).readVal
      catch (Err e) {}
    }
    if (checked) throw ParseErr("Invalid number: $val")
    return null
  }

  ** Parse a string into a Uri instance.  If the string cannot be parsed
  ** into a valid Uri and checked is false then return null, otherwise
  ** throw ParseErr.  This function converts an URI from *standard form*.
  ** Use `uriDecode` to convert a string from *escaped form*.  See `sys::Uri`
  ** for a detailed discussion on standard and escaped forms.
  **
  ** Examples:
  **   "foo bar".parseUri     >>  `foo bar`
  **   "foo%20bar".uriDecode  >>  `foo bar`
  @Axon static Uri? parseUri(Str val, Bool checked := true)
  {
    Uri.fromStr(val, checked)
  }

  ** Parse a Str into a Date.  If the string cannot be parsed into a valid
  ** Date and checked is false then return null, otherwise throw ParseErr.
  ** See `sys::Date.toLocale` for pattern.
  @Axon static Date? parseDate(Str val, Str pattern := "YYYY-MM-DD", Bool checked := true)
  {
    Date.fromLocale(val, pattern, checked)
  }

  ** Parse a Str into a Time.  If the string cannot be parsed into a valid
  ** Time and checked is false then return null, otherwise throw ParseErr.
  ** See `sys::Time.toLocale` for pattern.
  @Axon static Time? parseTime(Str val, Str pattern := "hh:mm:SS", Bool checked := true)
  {
    Time.fromLocale(val, pattern, checked)
  }

  ** Parse a Str into a DateTime.  If the string cannot be parsed into a valid
  ** DateTime and checked is false then return null, otherwise throw ParseErr.
  ** See `sys::DateTime.toLocale` for pattern:
  **
  **   YY     Two digit year             07
  **   YYYY   Four digit year            2007
  **   M      One/two digit month        6, 11
  **   MM     Two digit month            06, 11
  **   MMM    Three letter abbr month    Jun, Nov
  **   MMMM   Full month                 June, November
  **   D      One/two digit day          5, 28
  **   DD     Two digit day              05, 28
  **   DDD    Day with suffix            1st, 2nd, 3rd, 24th
  **   WWW    Three letter abbr weekday  Tue
  **   WWWW   Full weekday               Tuesday
  **   V      One/two digit week of year 1,52
  **   VV     Two digit week of year     01,52
  **   VVV    Week of year with suffix   1st,52nd
  **   h      One digit 24 hour (0-23)   3, 22
  **   hh     Two digit 24 hour (0-23)   03, 22
  **   k      One digit 12 hour (1-12)   3, 11
  **   kk     Two digit 12 hour (1-12)   03, 11
  **   m      One digit minutes (0-59)   4, 45
  **   mm     Two digit minutes (0-59)   04, 45
  **   s      One digit seconds (0-59)   4, 45
  **   ss     Two digit seconds (0-59)   04, 45
  **   SS     Optional seconds (only if non-zero)
  **   f*     Fractional secs trailing zeros
  **   F*     Fractional secs no trailing zeros
  **   a      Lower case a/p for am/pm   a, p
  **   aa     Lower case am/pm           am, pm
  **   A      Upper case A/P for am/pm   A, P
  **   AA     Upper case AM/PM           AM, PM
  **   z      Time zone offset           Z, +03:00 (ISO 8601, XML Schema)
  **   zzz    Time zone abbr             EST, EDT
  **   zzzz   Time zone name             New_York
  **   'xyz'  Literal characters
  **   ''     Single quote literal
  **
  @Axon static DateTime? parseDateTime(Str val, Str pattern := "YYYY-MM-DD'T'hh:mm:SS.FFFFFFFFFz zzzz", Str tz := TimeZone.cur.name, Bool checked := true)
  {
    DateTime.fromLocale(val, pattern, TimeZone.fromStr(tz), checked)
  }

  ** Parse a Str into a Ref.  If the string is not a valid Ref identifier
  ** then raise ParseErr or return null based on checked flag.  The string
  ** must *not* include a leading "@".
  @Axon static Ref? parseRef(Str val, Obj? dis := null, Bool checked := true)
  {
    if (dis is Bool) return Ref.fromStr(val, dis) // signature for 3.0.13 and earlier
    try
    {
      return Ref.make(val, dis)
    }
    catch (Err e)
    {
      if (checked) throw e
      return null
    }
  }

  ** Parse a Str into a Symbol.  If the string is not a valid Symbol
  ** identifier then raise ParseErr or return null based on checked flag.
  ** The string must *not* include a leading "^".
  @Axon static Symbol? parseSymbol(Str val, Bool checked := true)
  {
    Symbol.fromStr(val, checked)
  }

  ** Parse a string into a Filter expr which may be used
  ** with the `read` or `readAll` function.  Also see `filterToFunc`.
  **
  ** Example:
  **   str: "point and kw"
  **   readAll(parseFilter(str))
  @Axon static Obj? parseFilter(Str val, Bool checked := true)
  {
    Filter.fromStr(val, checked)
  }

  ** Parse a Str into a standardized unit name.  If the val is not
  ** a valid unit name from the standard database then return null
  ** or raise exception based on checked flag.
  @Axon static Str? parseUnit(Str val, Bool checked := true)
  {
    return Unit.fromStr(val, checked)?.symbol
  }

  ** Construct decoded `haystack::XStr` instance
  @Axon static Obj xstr(Str type, Str val) { XStr.decode(type, val) }

//////////////////////////////////////////////////////////////////////////
// Case Conversion / Character stuff
//////////////////////////////////////////////////////////////////////////

  ** Convert a char number or str to upper case
  @Axon static Obj? upper(Obj val) { val->upper }

  ** Convert a char number or str to lower case
  @Axon static Obj? lower(Obj val) { val->lower }

  ** Is number is whitespace char: space \t \n \r \f
  @Axon static Bool isSpace(Number num) { num.toInt.isSpace }

  ** Is number an ASCII alpha char: isUpper||isLower
  @Axon static Bool isAlpha(Number num) { num.toInt.isAlpha }

  ** Is number an ASCII alpha-numeric char: isAlpha||isDigit
  @Axon static Bool isAlphaNum(Number num) { num.toInt.isAlphaNum }

  ** Is number an ASCII uppercase alphabetic char: A-Z
  @Axon static Bool isUpper(Number num) { num.toInt.isUpper }

  ** Is number an ASCII lowercase alphabetic char: a-z
  @Axon static Bool isLower(Number num) { num.toInt.isLower }

  ** Is number a digit in the specified radix.  A decimal radix of
  ** ten returns true for 0-9.  A radix of 16 also returns true
  ** for a-f and A-F.
  @Axon static Bool isDigit(Number num, Number radix := Number.ten) { num.toInt.isDigit(radix.toInt) }

  ** Convert a unicode char number into a single char string
  @Axon static Str toChar(Number num) { num.toInt.toChar }

//////////////////////////////////////////////////////////////////////////
// Str
//////////////////////////////////////////////////////////////////////////

  ** Split a string by the given separator and trim whitespace.
  ** If 'sep' is null then split by any whitespace char; otherwise
  ** it must be exactly one char long.  See `sys::Str.split` for detailed
  ** behavior.
  **
  ** Options:
  **   - noTrim: disable auto-trim of whitespace from start and end of tokens
  @Axon static Obj? split(Str val, Str? sep := null, Dict? opts := null)
  {
    if (sep == null) return val.split
    if (sep.size != 1) throw ArgErr("Split string must be one char: $sep.toCode")
    if (opts == null) opts = Etc.emptyDict
    trim := opts.missing("noTrim")
    return val.split(sep[0], trim)
  }

  ** Return this string with the first character converted to
  ** uppercase.  The case conversion is for ASCII only.
  @Axon static Str capitalize(Str val) { val.capitalize }

  ** Return this string with the first character converted to
  ** lowercase.  The case conversion is for ASCII only.
  @Axon static Str decapitalize(Str val) { val.decapitalize }

  ** Trim whitespace from the beginning and end of the string.  For the purposes
  ** of this function, whitespace is defined as any character equal to or less
  ** than the 0x20 space character (including ' ', '\r', '\n', and '\t').
  @Axon static Str trim(Str val) { val.trim }

  ** Trim whitespace only from the beginning of the string.
  ** See `trim` for definition of whitespace.
  @Axon static Str trimStart(Str val) { val.trimStart }

  ** Trim whitespace only from the end of the string.
  ** See `trim` for definition of whitespace.
  @Axon static Str trimEnd(Str val)  { val.trimEnd }

  ** Return if Str starts with the specified Str.
  @Axon static Bool startsWith(Str val, Str sub) { val.startsWith(sub) }

  ** Return if Str ends with the specified Str.
  @Axon static Bool endsWith(Str val, Str sub) { val.endsWith(sub) }

  ** String replace of all occurrences of 'from' with 'to'.
  ** All three parameters must be strings.
  **
  ** Examples:
  **   "hello".replace("hell", "t")  >>  "to"
  **   "aababa".replace("ab", "-")   >>  "a--a"
  @Axon static Str replace(Str val, Str from, Str to) { val.replace(from, to) }

  ** Pad string to the left.  If size is less than width, then
  ** add the given char to the left to achieve the specified width.
  **
  ** Examples:
  **   "3".padl(3, "0")    >>  "003"
  **   "123".padl(2, "0")  >>  "123"
  @Axon static Str padl(Str val, Number width, Str char := " ") { val.padl(width.toInt, char[0]) }

  **
  ** Pad string to the right.  If size is less than width, then add
  ** the given char to the left to acheive the specified with.
  **
  ** Examples:
  **   "xyz".padr(2, ".")  >>  "xyz"
  **   "xyz".padr(5, "-")  >>  "xyz--"
  **
  @Axon static Str padr(Str val, Number width, Str char := " ") { val.padr(width.toInt, char[0]) }

  ** Concatenate a list of items into a string.
  **
  ** Examples:
  **   [1, 2, 3].concat       >>  "123"
  **   [1, 2, 3].concat(",")  >>  "1,2,3"
  @Axon static Str concat(List list, Str sep := "") { list.join(sep) }

//////////////////////////////////////////////////////////////////////////
// Regex
//////////////////////////////////////////////////////////////////////////

  ** Return if regular expression matches entire region of 's'.
  ** See [AxonUsage]`docSkySpark::AxonUsage#regex`.
  **
  ** Examples:
  **   reMatches(r"\d+", "x123y")  >>  false
  **   reMatches(r"\d+", "123")    >>  true
  @Axon static Bool reMatches(Obj regex, Str s)
  {
    AxonContext.curAxon.toRegex(regex).matches(s)
  }

  ** Find the first match of regular expression in 's'
  ** or return null if no matches.
  ** See [AxonUsage]`docSkySpark::AxonUsage#regex`.
  **
  ** Examples:
  **   reFind(r"\d+", "x123y")  >>  "123"
  **   reFind(r"\d+", "xyz")    >>  null
  @Axon static Str? reFind(Obj regex, Str s)
  {
    m := AxonContext.curAxon.toRegex(regex).matcher(s)
    if (!m.find) return null
    return m.group
  }

  ** Return a list of the substrings captured by matching the given
  ** regular operation against 's'.  Return null if no matches.  The
  ** first item in the list is the entire match, and each additional
  ** item is matched to '()' arguments in the regex pattern.
  ** See [AxonUsage]`docSkySpark::AxonUsage#regex`.
  **
  ** Examples:
  **   re: r"(RTU|AHU)-(\d+)"
  **   reGroups(re, "AHU")    >> null
  **   reGroups(re, "AHU-7")  >> ["AHU-7", "AHU", "7"]
  @Axon static Obj? reGroups(Obj regex, Str s)
  {
    m := AxonContext.curAxon.toRegex(regex).matcher(s)
    if (!m.find) return null
    groups := [,]
    for (i:=0; i<=m.groupCount; ++i) groups.add(m.group(i))
    return groups
  }

//////////////////////////////////////////////////////////////////////////
// Uri
//////////////////////////////////////////////////////////////////////////

  ** Get the scheme of a Uri as a string or null
  @Axon static Str? uriScheme(Uri val) { val.scheme }

  ** Get the host Uri as a string or null
  @Axon static Str? uriHost(Uri val) { val.host }

  ** Get the port of a Uri as a Number or null
  @Axon static Number? uriPort(Uri val) { val.port == null ? null : Number(val.port.toFloat) }

  ** Get the name Str of a Uri (last item in path).
  @Axon static Str? uriName(Uri val) { val.name }

  ** Get the path segments of a Uri as a list of Strs.
  @Axon static Obj? uriPath(Uri val) { val.path }

  ** Get the path a Uri as a string.
  @Axon static Str? uriPathStr(Uri val) { val.pathStr }

  ** Get the basename (last name in path without extension) of a Uri as a string.
  @Axon static Str? uriBasename(Uri val) { val.basename }

  ** Get the URI extension of a Uri as a string or null.
  @Axon static Str? uriExt(Uri val) { val.ext }

  ** Return if the URI path ends in a slash.
  @Axon static Bool uriIsDir(Uri val) { val.isDir }

  ** Return if the fragment identifier portion of the a URI after hash symbol
  @Axon static Str? uriFrag(Uri val) { val.frag }

  ** Return if the query portion of the a URI after question mark
  @Axon static Str? uriQueryStr(Uri val) { val.queryStr }

  ** Adding trailing slash to the URI.  See `sys::Uri.plusSlash`
  @Axon static Uri uriPlusSlash(Uri val) { val.plusSlash }

  ** Return the percent encoded string for this Uri according to RFC 3986.
  ** Each section of the Uri is UTF-8 encoded into octects and then percent
  ** encoded according to its valid character set. Spaces in the query
  ** section are encoded as '+'.
  **
  ** Examples:
  **   `foo bar`.uriEncode  >>  "foo%20bar"
  @Axon static Str uriEncode(Uri val) { val.encode }

  ** Parse an ASCII percent encoded string into a Uri according to RFC 3986.
  ** All %HH escape sequences are translated into octects, and then the octect
  ** sequence is UTF-8 decoded into a Str. The '+' character in the query section
  ** is unescaped into a space. If checked if true then throw ParseErr if the
  ** string is a malformed URI or if not encoded correctly, otherwise return
  ** null.  Use `parseUri` to parse from standard form.  See `sys::Uri` for
  ** a detailed discussion on standard and encoded forms.
  **
  ** Examples:
  **   "foo bar".parseUri     >>  `foo bar`
  **   "foo%20bar".uriDecode  >>  `foo bar`
  @Axon static Uri uriDecode(Str val, Bool checked := true) { Uri.decode(val, checked) }

//////////////////////////////////////////////////////////////////////////
// Ref
//////////////////////////////////////////////////////////////////////////

  ** Generate a new unique Ref identifier
  @Axon static Ref refGen() { Ref.gen }

  ** Given a ref return `haystack::Ref.dis`
  @Axon static Str refDis(Ref ref) { ref.dis }

//////////////////////////////////////////////////////////////////////////
// Coord
//////////////////////////////////////////////////////////////////////////

  ** Construct a Coord from two Numbers in decimal degrees
  @Axon static Coord coord(Number lat, Number lng) { Coord(lat.toFloat, lng.toFloat) }

  ** Latitude of a Coord as a Number
  @Axon static Number coordLat(Coord coord) { Number(coord.lat) }

  ** Longitude of a Coord as a Number
  @Axon static Number coordLng(Coord coord) { Number(coord.lng) }

  ** Compute the great-circle distance between two Coords.
  ** The result is a distance in meters using the haversine forumula.
  @Axon static Number coordDist(Coord c1, Coord c2) { Number(c1.dist(c2), Unit("m")) }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  ** Do nothing no-op
  @NoDoc @Axon
  static Obj? noop() { "noop" }

  ** Write the str represenation of 'x' to stdout and return 'x'.
  @Axon { admin = true }
  static Obj? _echo(Obj? x) { s := x?.toStr ?: "null"; echo(s); return s }

  ** Dump respresentation of 'x' standard out.  Return 'x' as result.
  @NoDoc @Axon { admin = true }
  static Obj? dump(Obj? x)
  {
    m := x?.typeof?.method("dump", false)
    if (m != null) m.call(x)
    else echo(x)
    return x
  }

  ** Reflectively call a function with the given arguments.  The func
  ** may be a Str name or an expression that evaluates to a function.
  ** Args is a positional list for each argument.  Examples:
  **
  **   call("today")
  **   call("replace", ["hi there", "hi", "hello"])
  **   call("parseDate", ["2021-03-15"])
  **   call("parseDate", ["15-Mar-21", "DD-MMM-YY"])
  **   call(parseDate, ["15-Mar-21", "DD-MMM-YY"])
  **   call(parseDate(_, "DD-MMM-YY"), ["15-Mar-21"])
  @Axon
  static Obj? call(Obj func, Obj?[]? args := null)
  {
    cx := AxonContext.curAxon
    fn := func is Str ? cx.findTop(func) : (Fn)func
    if (args == null) args = Obj#.emptyList
    return fn.callx(cx, args, Loc("call"))
  }

  ** Convert a scalar, list, or dict value to its Axon code representation
  **
  **   toAxonCode(123)        =>   "123"
  **   toAxonCode([1, 2, 3])  =>   "[1, 2, 3]"
  **   toAxonCode({x:123})    =>   "{x:123}"
  @Axon static Obj? toAxonCode(Obj? val) { Etc.toAxon(val) }

  ** Parse Axon source code into an abstract syntax tree modeled as a
  ** tree of dicts.  Each node has a 'type' tag which specified the node type.
  ** Common AST shapes:
  **
  **    123    =>  {type:"literal", val:123}
  **    a      =>  {type:"var", name:"a"}
  **    not a  =>  {type:"not", operand:{type:"var", name:"a"}}
  **    a + b  =>  {type:"add", lhs:{type:"var", name:"a"}, rhs:{type:"var", name:"b"}}
  **
  ** NOTE: the keys and structure of the AST is subject to change over time.
  @Axon static Dict parseAst(Str src)
  {
    AxonContext.curAxon.parse(src).encode
  }

  ** Dump current context stack to standard out
  @NoDoc @Axon { admin = true }
  static Obj? trace()
  {
    cx := AxonContext.curAxon
    str := cx.traceToStr(cx.curFunc?.loc ?: Loc.unknown)
    echo(str)
    return str
  }

  ** Given an axon expression, validate the syntax.  If there are no errors
  ** then return an empty grid.  If there are errors then return a grid
  ** with the "err" tag and a "line" and "dis" column for each error found.
  @NoDoc @Axon static Grid checkSyntax(Str src)
  {
    try
    {
      Parser(Loc("checkSyntax"), src.in).parseTop("checkSyntax")
      return Etc.makeEmptyGrid
    }
    catch (SyntaxErr e)
    {
      meta := ["err":Marker.val, "dis":"Syntax errors"]
      row  := ["line":Number.makeInt(e.loc.line), "dis": e.msg]
      return Etc.makeMapGrid(meta, row)
    }
    catch (Err e)
    {
      e.trace
      meta := ["err":Marker.val, "dis":"Parser failed"]
      row  := ["line":Number.makeInt(1), "dis": "Parser failed: $e.msg"]
      return Etc.makeMapGrid(meta, row)
    }
  }

//////////////////////////////////////////////////////////////////////////
// Private
//////////////////////////////////////////////////////////////////////////

  internal static Err argErr(Str name, Obj? val)
  {
    t := val == null ? "null" : val.typeof.qname
    return ArgErr("Invalid arg '$t' to 'core::$name'")
  }

  private const static Unit unitYear  := Unit("year")
  private const static Unit unitMo    := Unit("mo")
  private const static Unit unitDay   := Unit("day")
  private const static Unit unitHour  := Unit("h")
  private const static Unit unitMin   := Unit("min")
  private const static Unit unitSec   := Unit("s")
}