//
// Copyright (c) 2023, Brian Frank
// All Rights Reserved
//
// History:
//   26 Mar 2023  Brian Frank  Creation
//

package fan.xeto;

import fan.sys.*;

/**
 * NameTable
 */
public final class NameTable extends FanObj
{

//////////////////////////////////////////////////////////////////////////
// Construction
//////////////////////////////////////////////////////////////////////////

  public static NameTable make()
  {
    return new NameTable();
  }

  private NameTable()
  {
    this.byCode = new String[1024];
    this.byHash = new Entry[byHashSize];
    this.emptyCode = this.put("");    // always 1
    this.idCode    = this.put("id");  // always 2
  }

  public static long initSize() { return 2L; }

//////////////////////////////////////////////////////////////////////////
// Fantom API
//////////////////////////////////////////////////////////////////////////

  public final Type typeof() { return typeof; }

  public static final Type typeof$() { return typeof; }
  private static final Type typeof = Type.find("xeto::NameTable");

  public final String toStr() { return "NameTable"; }

  public final boolean isSparse() { return isSparse; }

  public final long size() { return size; }

  public final long maxCode() { return size; }

  public final long toCode(String name) { return code(name); }

  public final String toName(long code) { return name((int)code); }

  public final long add(String name) { return put(name); }

  public final void set(long code, String name)
  {
    // if already set, then ignore (we don't actually check name though)
    int c = (int)code;
    if (c < byCode.length && byCode[c] != null) return;

    // add to lookup tables
    put(c, name);
  }

//////////////////////////////////////////////////////////////////////////
// Implementation
//////////////////////////////////////////////////////////////////////////

  public final String name(int code)
  {
    String name = byCode[code];
    if (name == null) throw Err.make("Invalid name code: " + code);
    return name;
  }

  public final int code(String name)
  {
    int index = name.hashCode() & hashMask;
    Entry entry = byHash[index];
    while (entry != null)
    {
      if (entry.name.equals(name)) return entry.code;
      entry = entry.next;
    }
    return 0;
  }

  public final int put(String name)
  {
    // lookup outside of synchronized block
    int code = code(name);
    if (code > 0) return code;

    // add to lookup tables
    return put(-1, name);
  }

  private synchronized int put(int code, String name)
  {
    // find last entry in bucket; double check if
    // added now that we are in synchronzied block
    int index = name.hashCode() & hashMask;
    Entry last = byHash[index];
    while (last != null)
    {
      if (last.name.equals(name)) return last.code;
      if (last.next == null) break;
      last = last.next;
    }

    // allocate code unless this is a set
    if (code < 0)
    {
      if (isSparse) throw Err.make("Cannot call add once set has been called");
      ++size;
      code = size;
    }
    else
    {
      isSparse = true;
      ++size;
    }

    // grow byCode array if needed
    if (size >= maxSize) throw Err.make("Max names exceeded: " + maxSize);
    if (code >= byCode.length)
    {
      int newSize = byCode.length * 2;
      while (code >= newSize) newSize *= 2;
      String[] temp = new String[newSize];
      System.arraycopy(byCode, 0, temp, 0, byCode.length);
      byCode = temp;
    }

    // create new entry
    Entry entry = new Entry(code, name);
    byCode[code] = name;
    if (last == null)
      byHash[index] = entry;
    else
      last.next = entry;
    return code;
  }

  public final void dump(OutStream out)
  {
    out.printLine("=== NameTable [" + size + "] ===");
    for (int i=0; i<size; ++i)
    {
      out.printLine("  " + i + ": " + byCode[i]);
    }
    /*
    out.printLine("  --- byHash ---");
    for (int i=0; i<byHash.length; ++i)
    {
      Entry entry = byHash[i];
      if (entry == null) continue;
      // uncomment to print only dups
      // if (entry.next == null) continue;
      out.print("  " + FanInt.toHex(i, Long.valueOf(3)) + ": ");
      while (entry != null)
      {
        out.print(" " + entry.code + ":" + entry.name);
        entry = entry.next;
      }
      out.printLine();
    }
    */
  }

//////////////////////////////////////////////////////////////////////////
// NameDict Factories
//////////////////////////////////////////////////////////////////////////

  public final NameDict dict1(String n0, Object v0)
  {
    return new NameDict.D1(this, put(n0), ci(v0));
  }

  public final NameDict dict2(String n0, Object v0, String n1, Object v1)
  {
    return new NameDict.D2(this, put(n0), ci(v0), put(n1), ci(v1));
  }

  public final NameDict dict3(String n0, Object v0, String n1, Object v1, String n2, Object v2)
  {
    return new NameDict.D3(this, put(n0), ci(v0), put(n1), ci(v1), put(n2), ci(v2));
  }

  public final NameDict dict4(String n0, Object v0, String n1, Object v1, String n2, Object v2, String n3, Object v3)
  {
    return new NameDict.D4(this, put(n0), ci(v0), put(n1), ci(v1), put(n2), ci(v2), put(n3), ci(v3));
  }

  public final NameDict dict5(String n0, Object v0, String n1, Object v1, String n2, Object v2, String n3, Object v3, String n4, Object v4)
  {
    return new NameDict.D5(this, put(n0), ci(v0), put(n1), ci(v1), put(n2), ci(v2), put(n3), ci(v3), put(n4), ci(v4));
  }

  public final NameDict dict6(String n0, Object v0, String n1, Object v1, String n2, Object v2, String n3, Object v3, String n4, Object v4, String n5, Object v5)
  {
    return new NameDict.D6(this, put(n0), ci(v0), put(n1), ci(v1), put(n2), ci(v2), put(n3), ci(v3), put(n4), ci(v4), put(n5), ci(v5));
  }

  public final NameDict dict7(String n0, Object v0, String n1, Object v1, String n2, Object v2, String n3, Object v3, String n4, Object v4, String n5, Object v5, String n6, Object v6)
  {
    return new NameDict.D7(this, put(n0), ci(v0), put(n1), ci(v1), put(n2), ci(v2), put(n3), ci(v3), put(n4), ci(v4), put(n5), ci(v5), put(n6), ci(v6));
  }

  public final NameDict dict8(String n0, Object v0, String n1, Object v1, String n2, Object v2, String n3, Object v3, String n4, Object v4, String n5, Object v5, String n6, Object v6, String n7, Object v7)
  {
    return new NameDict.D8(this, put(n0), ci(v0), put(n1), ci(v1), put(n2), ci(v2), put(n3), ci(v3), put(n4), ci(v4), put(n5), ci(v5), put(n6), ci(v6), put(n7), ci(v7));
  }

  public final NameDict dictMap(Map map)
  {
    int size = map.sz();
    if (size == 0) return NameDict.empty();

    int[] names = new int[size];
    Object[] vals = new Object[size];
    java.util.Iterator it = map.pairsIterator();
    int i = 0;
    while (it.hasNext())
    {
      java.util.Map.Entry e = (java.util.Map.Entry)it.next();
      names[i] = put((String)e.getKey());
      vals[i] = ci(e.getValue());
      ++i;
    }

    if (size <= 8)
    {
      switch (size)
      {
        case 1: return new NameDict.D1(this, names[0], vals[0]);
        case 2: return new NameDict.D2(this, names[0], vals[0], names[1], vals[1]);
        case 3: return new NameDict.D3(this, names[0], vals[0], names[1], vals[1], names[2], vals[2]);
        case 4: return new NameDict.D4(this, names[0], vals[0], names[1], vals[1], names[2], vals[2], names[3], vals[3]);
        case 5: return new NameDict.D5(this, names[0], vals[0], names[1], vals[1], names[2], vals[2], names[3], vals[3], names[4], vals[4]);
        case 6: return new NameDict.D6(this, names[0], vals[0], names[1], vals[1], names[2], vals[2], names[3], vals[3], names[4], vals[4], names[5], vals[5]);
        case 7: return new NameDict.D7(this, names[0], vals[0], names[1], vals[1], names[2], vals[2], names[3], vals[3], names[4], vals[4], names[5], vals[5], names[6], vals[6]);
        case 8: return new NameDict.D8(this, names[0], vals[0], names[1], vals[1], names[2], vals[2], names[3], vals[3], names[4], vals[4], names[5], vals[5], names[6], vals[6], names[7], vals[7]);
      }
    }

    return new NameDict.Map(this, names, vals, size);
  }

  public final NameDict dictDict(Dict dict)
  {
    if (dict.isEmpty()) return NameDict.empty();

    if (dict instanceof NameDict)
    {
      NameDict nameDict = (NameDict)dict;
      if (nameDict.table == this) return nameDict;
    }

    // we can trust dict values are already immutable
    DictEachAcc acc = new DictEachAcc(this);
    dict.each(acc);
    int[] names = acc.names;
    Object[] vals = acc.vals;
    int size = acc.size;

    if (size <= 8)
    {
      switch (size)
      {
        case 1: return new NameDict.D1(this, names[0], vals[0]);
        case 2: return new NameDict.D2(this, names[0], vals[0], names[1], vals[1]);
        case 3: return new NameDict.D3(this, names[0], vals[0], names[1], vals[1], names[2], vals[2]);
        case 4: return new NameDict.D4(this, names[0], vals[0], names[1], vals[1], names[2], vals[2], names[3], vals[3]);
        case 5: return new NameDict.D5(this, names[0], vals[0], names[1], vals[1], names[2], vals[2], names[3], vals[3], names[4], vals[4]);
        case 6: return new NameDict.D6(this, names[0], vals[0], names[1], vals[1], names[2], vals[2], names[3], vals[3], names[4], vals[4], names[5], vals[5]);
        case 7: return new NameDict.D7(this, names[0], vals[0], names[1], vals[1], names[2], vals[2], names[3], vals[3], names[4], vals[4], names[5], vals[5], names[6], vals[6]);
        case 8: return new NameDict.D8(this, names[0], vals[0], names[1], vals[1], names[2], vals[2], names[3], vals[3], names[4], vals[4], names[5], vals[5], names[6], vals[6], names[7], vals[7]);
      }
    }

    return new NameDict.Map(this, names, vals, size);
  }

  private static Object ci(Object v)
  {
    // check immutable
    return FanObj.toImmutable(v);
  }

  private static final Type eachFuncType = Type.makeFunc(new Type[] { Sys.ObjType, Sys.StrType }, Sys.ObjType);

  static final class DictEachAcc extends Func.Indirect2
  {
    DictEachAcc(NameTable table)
    {
      super(eachFuncType);
      this.table = table;
    }

    public Object call(Object a, Object b)
    {
      if (size >= names.length) grow();
      names[size] = table.put((String)b);
      vals[size] = a;
      ++size;
      return null;
    }

    private void grow()
    {
      int[] tempNames = new int[names.length*2];
      System.arraycopy(names, 0, tempNames, 0, names.length);
      names = tempNames;

      Object[] tempVals = new Object[vals.length*2];
      System.arraycopy(vals, 0, tempVals, 0, vals.length);
      vals = tempVals;
    }

    NameTable table;
    int[] names = new int[16];
    Object[] vals = new Object[16];
    int size = 0;
  }

  public final NameDict readDict(long size, NameDictReader r)
  {
    int sz = (int)size;
    switch (sz)
    {
      case 0: return NameDict.empty();
      case 1: return new NameDict.D1(this, (int)r.readName(), ci(r.readVal()));
      case 2: return new NameDict.D2(this, (int)r.readName(), ci(r.readVal()), (int)r.readName(), ci(r.readVal()));
      case 3: return new NameDict.D3(this, (int)r.readName(), ci(r.readVal()), (int)r.readName(), ci(r.readVal()), (int)r.readName(), ci(r.readVal()));
      case 4: return new NameDict.D4(this, (int)r.readName(), ci(r.readVal()), (int)r.readName(), ci(r.readVal()), (int)r.readName(), ci(r.readVal()), (int)r.readName(), ci(r.readVal()));
      case 5: return new NameDict.D5(this, (int)r.readName(), ci(r.readVal()), (int)r.readName(), ci(r.readVal()), (int)r.readName(), ci(r.readVal()), (int)r.readName(), ci(r.readVal()), (int)r.readName(), ci(r.readVal()));
      case 6: return new NameDict.D6(this, (int)r.readName(), ci(r.readVal()), (int)r.readName(), ci(r.readVal()), (int)r.readName(), ci(r.readVal()), (int)r.readName(), ci(r.readVal()), (int)r.readName(), ci(r.readVal()), (int)r.readName(), ci(r.readVal()));
      case 7: return new NameDict.D7(this, (int)r.readName(), ci(r.readVal()), (int)r.readName(), ci(r.readVal()), (int)r.readName(), ci(r.readVal()), (int)r.readName(), ci(r.readVal()), (int)r.readName(), ci(r.readVal()), (int)r.readName(), ci(r.readVal()), (int)r.readName(), ci(r.readVal()));
      case 8: return new NameDict.D8(this, (int)r.readName(), ci(r.readVal()), (int)r.readName(), ci(r.readVal()), (int)r.readName(), ci(r.readVal()), (int)r.readName(), ci(r.readVal()), (int)r.readName(), ci(r.readVal()), (int)r.readName(), ci(r.readVal()), (int)r.readName(), ci(r.readVal()), (int)r.readName(), ci(r.readVal()));
    }

    int[] names = new int[sz];
    Object[] vals = new Object[sz];
    for (int i=0; i<sz; ++i)
    {
      names[i] = (int)r.readName();
      vals[i] = r.readVal();
    }
    return new NameDict.Map(this, names, vals, sz);
  }

//////////////////////////////////////////////////////////////////////////
// Entry
//////////////////////////////////////////////////////////////////////////

  static class Entry
  {
    Entry(int code, String name) { this.code = code; this.name = name; }
    final int code;
    final String name;
    Entry next;
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  private static final int hashMask   = 0xFFFF;
  private static final int byHashSize = hashMask + 1;
  private static final int maxSize    = 1_000_000;

  public final int emptyCode;
  public final int idCode;
  private String[] byCode;
  private Entry[] byHash;
  private int size;
  private boolean isSparse;
}

