//
// Copyright (c) 2016, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   9 Feb 2016  Brian Frank  Creation
//

package fan.hxStore;

import fan.sys.*;

/**
 * FreeMap manages a bit mask for free/used pages
 */
final class FreeMap
{

  FreeMap(int max)
  {
    if (max % 8 != 0) throw Store.err("invalid max: " + max);
    this.max = max;
    this.bits = new byte[max/8];
  }

  public final int numUsed()
  {
    return numUsed;
  }

  public final boolean isUsed(int pageId)
  {
    int index = pageId / 8;
    int bit = 1 << (pageId % 8);
    return (bits[index] & bit) != 0;
  }

  public final int alloc()
  {
    // if full, then short circuit
    if (numUsed >= max) return -1;

    // loop through free byte masks
    int i = cursor;
    int loops = 0;
    while (true)
    {
      // if all bits allocated in this byte, keep looking
      int mask = bits[i] & 0xff;
      if (mask == 0xff)
      {
        // advance to next byte, or potentially loop back to beginning
        i++;
        if (i >= bits.length)
        {
          // sanity check to prevent infinity loop
          if (++loops > 2) throw Store.err("numUsed: " + numUsed);
          i = 0;
        }
        continue;
      }

      // find which of the bits if free
      int bit = 0;
      while ((mask & (1 << bit)) != 0) bit++;

      // update page file
      bits[i] |= (1 << bit);  // mark that page used
      cursor = i;             // remember index where we found last free
      numUsed++;              // update used count
      return (i * 8) + bit;
    }
  }

  public final void free(int pageId)
  {
    int index = pageId / 8;
    int bit = 1 << (pageId % 8);
    if ((bits[index] & bit) == 0) throw Store.err("dup free: " + pageId);
    bits[index] &= ~bit;
    if (index < cursor) cursor = index;
    numUsed--;
  }

  public final void markUsed(int pageId)
  {
    int index = pageId / 8;
    int bit = 1 << (pageId % 8);
    if ((bits[index] & bit) != 0) throw Store.err("dup markUsed: " + pageId);
    bits[index] |= bit;
    numUsed++;
  }

  private final int max;
  private final byte[] bits;
  private int numUsed;
  private int cursor;
}