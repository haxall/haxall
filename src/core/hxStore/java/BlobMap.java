//
// Copyright (c) 2016, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   11 Feb 2016  Brian Frank  Creation
//

package fan.hxStore;

import java.security.SecureRandom;
import fan.sys.Func;

/**
 * BlobMap stores in the in-memory index of Blobs which are
 * indexed to an array by the low 4 bytes of the handle
 */
final class BlobMap
{

  BlobMap(int initialCapacity)
  {
    this(initialCapacity, Store.maxNumBlobs);
  }

  BlobMap(int initialCapacity, int max)
  {
    int n = 32;
    while (n < initialCapacity) n = n << 1;

    this.max = max;
    this.array = new Blob[n];
    this.cursor = 0;
  }

  final int size() { return size; }

  final int deletedSize() { return deletedSize; }

  final int capacity() { return array.length; }

  final int cursor() { return cursor; }

  final BlobMap reset() { cursor = 0; return this; }

  final Blob get(long handle, boolean checked)
  {
    int index = handleToIndex(handle);
    Blob[] array = this.array;
    if (index < array.length)
    {
      Blob b = array[index];
      if (b != null && b.handle == handle && b.isActive()) return b;
    }
    if (checked) throw UnknownBlobErr.make("Unknown handle " + Blob.handleToStr(handle));
    return null;
  }

  final Blob deletedGet(long handle, boolean checked)
  {
    int index = handleToIndex(handle);
    Blob[] array = this.array;
    if (index < array.length)
    {
      Blob b = array[index];
      if (b != null && b.isDeleted()) return b;
    }
    if (checked) throw UnknownBlobErr.make("Unknown handle " + Blob.handleToStr(handle));
    return null;
  }

  final Blob getIndex(long handle, boolean checked)
  {
    int index = handleToIndex(handle);
    Blob[] array = this.array;
    if (index < array.length)
    {
      Blob b = array[index];
      if (b != null) return b;
    }
    if (checked) throw UnknownBlobErr.make("Unknown handle " + Blob.handleToStr(handle));
    return null;
  }

  final void each(Func func)
  {
    Blob[] array = this.array;
    for (int i=0; i<array.length; ++i)
    {
      Blob b = array[i];
      if (b != null && b.isActive()) func.call(b);
    }
  }

  final void deletedEach(Func func)
  {
    Blob[] array = this.array;
    for (int i=0; i<array.length; ++i)
    {
      Blob b = array[i];
      if (b != null && b.isDeleted()) func.call(b);
    }
  }

  final long allocHandle()  // must be used with 'set'
  {
    return IO.join(allocHandleVar(), allocHandleIndex());
  }

  final Blob set(Blob blob) // used after 'allocHandle'
  {
    int index = handleToIndex(blob.handle);
    if (index >= array.length) grow(index+1);
    Blob old = array[index];
    if (old != null)
    {
      if (old.isActive()) throw Store.err(blob.toStr());
      deletedSize--;
    }
    array[index] = blob;
    cursor = index;
    if (blob.isActive()) size++;
    else deletedSize++;
    return old;
  }

  final void free(Blob blob)
  {
    int index = handleToIndex(blob.handle);
    if (array[index] != blob || !blob.isDeleted()) throw Store.err(blob.toStr());
    if (index < cursor) cursor = index;
    size--;
    deletedSize++;
  }

  private int allocHandleVar()
  {
    int var = rand.nextInt();
    while (var == 0 || var == -1) var = rand.nextInt();
    return var;
  }

  private int allocHandleIndex()
  {
    Blob[] a = this.array;

    // loop from cursor to end
    for (int i=cursor; i<a.length; ++i)
      if (a[i] == null || a[i].isDeleted()) return i;

    // loop from start to cursor
    for (int i=0; i<cursor; ++i)
      if (a[i] == null || a[i].isDeleted()) return i;

    // need to grow array
    grow(a.length + 1);
    return a.length;
  }

  private void grow(int newMinSize)
  {
    Blob[] a = this.array;
    if (a.length >= max) throw Store.err("Max number of blobs exceeded: " + max);
    int newSize = a.length * 2;
    while (newSize < newMinSize) newSize *= 2;
    if (newSize > max) newSize = max;
    Blob[] temp = new Blob[newSize];
    System.arraycopy(a, 0, temp, 0, a.length);
    this.array = temp;
  }

  static int handleToIndex(long handle)
  {
    return IO.lo4(handle);
  }

  Blob[] snapshot()
  {
    Blob[] copy = new Blob[array.length];
    for (int i=0; i<copy.length; ++i)
    {
      Blob b = array[i];
      if (b != null) copy[i] = b.snapshot();
    }
    return copy;
  }

  Blob[] cloneArray()
  {
    Blob[] temp = new Blob[array.length];
    System.arraycopy(array, 0, temp, 0, array.length);
    return temp;
  }

  private final int max;
  private final SecureRandom rand = new SecureRandom();
  private Blob[] array;
  private int size;
  private int deletedSize;
  private int cursor;
}