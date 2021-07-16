//
// Copyright (c) 2014, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   17 Dec 2014  Brian Frank  Creation
//

**
** CircularBuf provides a list of items with a fixed size.  Once
** the fixed size is reached, newer elements replace the oldest items.
**
class CircularBuf
{
  ** Construct with max size
  new make(Int max)
  {
    this.max = max
    this.items.size = max
  }

  ** Max size
  Int max { private set }

  ** Number of items in buffer
  Int size { private set }

  ** Resize this buffer with the new max size
  Void resize(Int newMax)
  {
    if (this.max == newMax) return

    // copy items into temp list
    temp := Obj?[,]
    each |item| { temp.add(item) }

    // reset
    this.max   = newMax
    this.size  = 0
    this.items = Obj?[,] { it.size = newMax }
    this.tail  = -1

    // re-add items
    temp.eachr |item| { add(item) }
  }

  ** Newest item added to the buffer
  Obj? newest() { tail < 0 ? null : items.getSafe(tail) }

  ** Olest item in the buffer
  Obj? oldest() { tail + 1 >= size ? items.getSafe(0) : items.getSafe(tail+1) }

  ** Iterate from newest to oldest as long as given func
  ** returns null.  If non-null is returned then break and
  ** return the value.
  Obj? eachWhile(|Obj?->Obj?| f)
  {
    end := size
    i := tail
    n := 0
    while (n < end)
    {
      r := f(items[i])
      if (r != null) return r
      n++
      i--
      if (i < 0) i = max - 1
    }
    return null
  }

  ** Iterate from oldest to newest as long as given func
  ** returns null.  If non-null is returned then break and
  ** return the value.
  Obj? eachrWhile(|Obj?->Obj?| f)
  {
    end := size
    i := tail+1; if (i >= size) i = 0
    n := 0
    while (n < end)
    {
      r := f(items[i])
      if (r != null) return r
      n++
      i++
      if (i >= max) i = 0
    }
    return null
  }

  ** Iterate from newest to oldest
  Void each(|Obj?| f)
  {
    end := size
    i := tail
    n := 0
    while (n < end)
    {
      f(items[i])
      n++
      i--
      if (i < 0) i = max - 1
    }
  }

  ** Iterate from oldest to newest
  Void eachr(|Obj?| f)
  {
    end := size
    i := tail+1; if (i >= size) i = 0
    n := 0
    while (n < end)
    {
      f(items[i])
      n++
      i++
      if (i >= max) i = 0
    }
  }

  ** Add new item to the buffer; if size is
  ** is at max remove the oldest item
  Void add(Obj? item)
  {
    tail = tail + 1
    if (tail >= max) tail = 0
    items[tail] = item
    size = (size + 1).min(max)
  }

  ** Clear all items
  Void clear()
  {
    this.items = Obj?[,] { it.size = this.max }
    this.size = 0
    this.tail = -1
  }

  private Obj?[] items := [,]
  private Int tail := -1
}