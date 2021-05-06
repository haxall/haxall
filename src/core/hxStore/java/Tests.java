//
// Copyright (c) 2016, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   11 Feb 2016  Brian Frank  Creation
//

package fan.hxStore;

import fan.sys.*;

/**
 * Tests
 */
public final class Tests extends FanObj
{
  static Tests make(JavaTestBridge bridge) { return new Tests(bridge); }

  public final Type typeof() { return typeof; }
  private static final Type typeof = Type.find("hxStore::Tests");

  Tests(JavaTestBridge b) { this.bridge = b; }

  final JavaTestBridge bridge;

  void verify(boolean cond) { bridge.verify(cond); }

  void verifyEq(boolean a, boolean b)
  {
    if (a == b) verify(true);
    else throw err(a + " != " + b);
  }

  void verifyEq(int a, int b)
  {
    if (a == b) verify(true);
    else throw err(a + " != " + b + " (" + hex(a) + " != " + hex(b) + ")");
  }

  void verifyEq(long a, long b)
  {
    if (a == b) verify(true);
    else throw err(a + " != " + b + " (" + hex(a) + " != " + hex(b) + ")");
  }

  void verifySame(Object a, Object b)
  {
    if (a == b) verify(true);
    else throw err(a + " !== " + b);
  }

  void verifyErr(Code code)
  {
    try
    {
      code.run();
    }
    catch (Exception e)
    {
      //System.out.println("ERROR: " + e);
      verify(true);
      return;
    }
    throw err("No err thrown");
  }

  abstract class Code {  abstract void run(); }

  RuntimeException err(String msg) { return new RuntimeException(msg); }

  String hex(int i) { return "0x" + Integer.toHexString(i); }

  String hex(long i) { return "0x" + Long.toHexString(i); }

//////////////////////////////////////////////////////////////////////////
// IO
//////////////////////////////////////////////////////////////////////////

  void testIO()
  {
    verifyEq(IO.join(0xaa, 0xbb), 0x000000aa000000bbL);
    verifyEq(IO.join(0xf000007e, 0xac0000cd), 0xf000007eac0000cdL);

    verifyEq(IO.hi4(0x0012346700abcdefL), 0x00123467);
    verifyEq(IO.lo4(0x0012346700abcdefL), 0x00abcdef);
    verifyEq(IO.hi4(0xfedcba9876543210L), 0xfedcba98);
    verifyEq(IO.lo4(0xfedcba9876543210L), 0x76543210);
    verifyEq(IO.hi4(0xffeeddccbbaa9988L), 0xffeeddcc);
    verifyEq(IO.lo4(0xffeeddccbbaa9988L), 0xbbaa9988);

    byte[] buf = new byte[256];
    IO.write1(buf, 0, 'x');
    IO.write1(buf, 1, 0xfa);
    IO.write2(buf, 2, 0x0302);
    IO.write2(buf, 4, 0xf0e0);
    IO.write4(buf, 6, 0xaabbccdd);
    IO.write8(buf, 10, 0xffeeddccbbaa9988L);
    IO.write8(buf, 18, 0xffffffff00000000L);
    IO.write8(buf, 26, 0x00000000ffffffffL);
    IO.write8(buf, 34, 0xfedcba9876543210L);

    verifyEq(IO.read1(buf, 0), 'x');
    verifyEq(IO.read1(buf, 1), 0xfa);
    verifyEq(IO.read2(buf, 2), 0x0302);
    verifyEq(IO.read2(buf, 4), 0xf0e0);
    verifyEq(IO.read4(buf, 6), 0xaabbccdd);
    verifyEq(IO.read8(buf, 10), 0xffeeddccbbaa9988L);
    verifyEq(IO.read8(buf, 18), 0xffffffff00000000L);
    verifyEq(IO.read8(buf, 26), 0x00000000ffffffffL);
    verifyEq(IO.read8(buf, 34), 0xfedcba9876543210L);

    for (int i=0; i<buf.length; ++i) buf[i] = (byte)i;
    IO.writeZ(buf, 3, 3);
    verifyEq(buf[1], 1);
    verifyEq(buf[2], 2);
    verifyEq(buf[3], 0);
    verifyEq(buf[4], 0);
    verifyEq(buf[5], 0);
    verifyEq(buf[6], 6);
    verifyEq(buf[7], 7);
  }

//////////////////////////////////////////////////////////////////////////
// FreeMap
//////////////////////////////////////////////////////////////////////////

  void testFreeMap()
  {
    // constructor tests
    verifyErr(new Code() { void run() { new FreeMap(0xff); } });
    verifyErr(new Code() { void run() { new FreeMap(63); } });

    boolean[] used = new boolean[64];
    int max = 64;

    // initial state
    final FreeMap f = new FreeMap(max);
    verifyFreeMap(f, used);

    // alloc free past one byte
    for (int i=0; i<11; ++i) verifyAlloc(f, used, i);

    // free couple in first byte
    verifyFree(f, used, 3);
    verifyFree(f, used, 7);
    verifyErr(new Code() { void run() { f.free(7); } });

    // verify allocs back fill first byte
    verifyAlloc(f, used, 3);
    verifyAlloc(f, used, 7);
    verifyAlloc(f, used, 11);
    verifyAlloc(f, used, 12);

    // alloc from 12 up to full max number
    for (int i=13; i<max; ++i) verifyAlloc(f, used, i);
    verifyEq(f.numUsed(), max);
    verifyEq(f.alloc(), -1);
    verifyEq(f.alloc(), -1);

    // now  freeing and re-allocating n pageIds in random order
    for (int n=0; n<max; ++n)
    {
      List freed = List.makeObj(n);
      for (int j=0; j<n; ++j)
      {
        // free n random pageIds
        int pageId;
        while (true)
        {
          pageId = (int)FanInt.random(Range.makeExclusive(0, max));
          if (used[pageId]) break;
        }
        verifyFree(f, used, pageId);
        freed.add(Long.valueOf(pageId));
      }

      // now re-alloc back up to max
      freed.sort();
      for (int i=0; i<freed.sz(); ++i) verifyAlloc(f, used, ((Long)freed.get(i)).intValue());
      verifyEq(f.numUsed(), max);
      verifyEq(f.alloc(), -1);
      verifyEq(f.alloc(), -1);
    }

    // free all
    verifyEq(f.numUsed(), max);
    for (int i=0; i<max; ++i) verifyFree(f, used, i);
    verifyEq(f.numUsed(), 0);

    // markUsed
    for (int i=0; i<20; ++i)
    {
      final int pageId = (int)FanInt.random(Range.makeExclusive(0, max));
      if (used[pageId]) continue;
      f.markUsed(pageId);
      used[pageId] = true;
      verifyErr(new Code() { void run() { f.markUsed(pageId); } });
      verifyFreeMap(f, used);
    }
  }

  void verifyAlloc(FreeMap f, boolean[] used, int expected)
  {
    verifyEq(f.alloc(), expected);
    used[expected] = true;
    verifyFreeMap(f, used);
  }

  void verifyFree(FreeMap f, boolean[] used, int pageId)
  {
    f.free(pageId);
    used[pageId] = false;
    verifyFreeMap(f, used);
  }

  void verifyFreeMap(FreeMap f, boolean[] used)
  {
    int total = 0;
    for (int i=0; i<used.length; ++i)
    {
      boolean u = used[i];
      verifyEq(f.isUsed(i), u);
      if (u) total++;
    }
    verifyEq(f.numUsed(), total);
  }

//////////////////////////////////////////////////////////////////////////
// Blob Map
//////////////////////////////////////////////////////////////////////////

  void testBlobMap()
  {
    final BlobMap m = new BlobMap(3, 100);
    Blob[] blobs = new Blob[100];

    verifyEq(m.capacity(), 32);
    verifyEq(m.size(), 0);
    verifyEq(m.cursor(), 0);

    for (int i=0; i<32; ++i)
    {
      verifyAlloc(m, blobs, i);
      verifyEq(m.capacity(), 32);
    }
    for (int i=32; i<64; ++i)
    {
      verifyAlloc(m, blobs, i);
      verifyEq(m.capacity(), 64);
    }
    for (int i=64; i<100; ++i)
    {
      verifyAlloc(m, blobs, i);
      verifyEq(m.capacity(), 100);
    }

    verifyErr(new Code() { void run() { m.allocHandle(); } });
    verifyErr(new Code() { void run() { m.allocHandle(); } });
    verifyErr(new Code() { void run() { m.set(new Blob(4)); } });
    verifyErr(new Code() { void run() { m.free(new Blob(4)); } });

    // free
    verifyFree(m, blobs, 21);  verifyEq(m.cursor(), 21);
    verifyFree(m, blobs, 3);   verifyEq(m.cursor(), 3);
    verifyFree(m, blobs, 11);  verifyEq(m.cursor(), 3);
    verifyEq(m.capacity(), 100);

    // re-alloc those slots
    verifyAlloc(m, blobs, 3);
    verifyAlloc(m, blobs, 11);
    verifyAlloc(m, blobs, 21);
    verifyErr(new Code() { void run() { m.allocHandle(); } });
    verifyEq(m.capacity(), 100);

    // now freeing and re-allocating n in random order
    for (int n=1; n<100; ++n)
    {
      // free n random
      List freed = List.makeObj(n);
      for (int j=0; j<n; ++j)
      {
        int index;
        while (true)
        {
          index = (int)FanInt.random(Range.makeExclusive(0, 100));
          if (blobs[index] != null && !blobs[index].isDeleted()) break;
        }
        verifyFree(m, blobs, index);
        freed.add(Long.valueOf(index));
      }

      // now re-alloc back up to max
      freed.sort();
      for (int i=0; i<freed.sz(); ++i) verifyAlloc(m, blobs, ((Long)freed.get(i)).intValue());
      verifyEq(m.size(), 100);
      verifyErr(new Code() { void run() { m.allocHandle(); } });
      verifyErr(new Code() { void run() { m.allocHandle(); } });
    }
  }

  void verifyAlloc(BlobMap m, Blob[] blobs, int expected)
  {
    long h = m.allocHandle();
    int i = BlobMap.handleToIndex(h);
    verifyEq(i, expected);
    blobs[i] = new Blob(h);
    m.set(blobs[i]);
    verifyEq(m.cursor(), i);
    verifyBlobMap(m, blobs);
  }

  void verifyFree(BlobMap m, Blob[] blobs, int index)
  {
    Blob b = blobs[index];
    b.size = -1;
    m.free(blobs[index]);
    verifyBlobMap(m, blobs);
  }

  void verifyBlobMap(BlobMap m, Blob[] blobs)
  {
    int active = 0;
    int deleted = 0;
    for (int i=0; i<blobs.length; ++i)
    {
      Blob b = blobs[i];
      if (b != null && b.isActive())
      {
        verify(m.get(b.handle, false) == b);
        active++;
      }
      else if (b != null && b.isDeleted())
      {
        verify(m.deletedGet(b.handle, false) == b);
        deleted++;
      }
      else
      {
        verify(m.get(i, false) == null);
      }
    }
    verifyEq(m.size(), active);
    verifyEq(m.deletedSize(), deleted);
  }
}