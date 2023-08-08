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
    this.emptyCode = this.put("");
    this.idCode    = this.put("id");
  }

//////////////////////////////////////////////////////////////////////////
// Fantom API
//////////////////////////////////////////////////////////////////////////

  public final Type typeof() { return typeof; }
  private static final Type typeof = Type.find("xeto::NameTable");

  public final String toStr() { return "NameTable"; }

  public final long size() { return size; }

  public final long maxCode() { return size; }

  public final long toCode(String name) { return code(name); }

  public final String toName(long code) { return name((int)code); }

  public final long add(String name) { return put(name); }

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

    synchronized (this)
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

      // grow byCode array if needed
      if (size >= maxSize) throw Err.make("Max names exceeded: " + maxSize);
      code = ++size;
      if (code >= byCode.length)
      {
        String[] temp = new String[byCode.length * 2];
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
  }

  public final void dump(OutStream out)
  {
    out.printLine("=== NameTable [" + size + "] ===");
    /*
    for (int i=0; i<size; ++i)
    {
      out.printLine("  " + i + ": " + byCode[i]);
    }
    */
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
  }

  public final NameDict dict1(String n0, Object v0) { return dict1(n0, v0, null); }
  public final NameDict dict1(String n0, Object v0, Spec spec)
  {
    return new NameDict.D1(this, put(n0), v0, spec);
  }

  public final NameDict dict2(String n0, Object v0, String n1, Object v1) { return dict2(n0, v0, n1, v1, null); }
  public final NameDict dict2(String n0, Object v0, String n1, Object v1, Spec spec)
  {
    return new NameDict.D2(this, put(n0), v0, put(n1), v1, spec);
  }

  public final NameDict dict3(String n0, Object v0, String n1, Object v1, String n2, Object v2) { return dict3(n0, v0, n1, v1, n2, v2, null); }
  public final NameDict dict3(String n0, Object v0, String n1, Object v1, String n2, Object v2, Spec spec)
  {
    return new NameDict.D3(this, put(n0), v0, put(n1), v1, put(n2), v2, spec);
  }

  public final NameDict dict4(String n0, Object v0, String n1, Object v1, String n2, Object v2, String n3, Object v3) { return dict4(n0, v0, n1, v1, n2, v2, n3, v3, null); }
  public final NameDict dict4(String n0, Object v0, String n1, Object v1, String n2, Object v2, String n3, Object v3, Spec spec)
  {
    return new NameDict.D4(this, put(n0), v0, put(n1), v1, put(n2), v2, put(n3), v3, spec);
  }

  public final NameDict dict5(String n0, Object v0, String n1, Object v1, String n2, Object v2, String n3, Object v3, String n4, Object v4) { return dict5(n0, v0, n1, v1, n2, v2, n3, v3, n4, v4, null); }
  public final NameDict dict5(String n0, Object v0, String n1, Object v1, String n2, Object v2, String n3, Object v3, String n4, Object v4, Spec spec)
  {
    return new NameDict.D5(this, put(n0), v0, put(n1), v1, put(n2), v2, put(n3), v3, put(n4), v4, spec);
  }

  public final NameDict dict6(String n0, Object v0, String n1, Object v1, String n2, Object v2, String n3, Object v3, String n4, Object v4, String n5, Object v5) { return dict6(n0, v0, n1, v1, n2, v2, n3, v3, n4, v4, n5, v5, null); }
  public final NameDict dict6(String n0, Object v0, String n1, Object v1, String n2, Object v2, String n3, Object v3, String n4, Object v4, String n5, Object v5, Spec spec)
  {
    return new NameDict.D6(this, put(n0), v0, put(n1), v1, put(n2), v2, put(n3), v3, put(n4), v4, put(n5), v5, spec);
  }

  public final NameDict dict7(String n0, Object v0, String n1, Object v1, String n2, Object v2, String n3, Object v3, String n4, Object v4, String n5, Object v5, String n6, Object v6) { return dict7(n0, v0, n1, v1, n2, v2, n3, v3, n4, v4, n5, v5, n6, v6, null); }
  public final NameDict dict7(String n0, Object v0, String n1, Object v1, String n2, Object v2, String n3, Object v3, String n4, Object v4, String n5, Object v5, String n6, Object v6, Spec spec)
  {
    return new NameDict.D7(this, put(n0), v0, put(n1), v1, put(n2), v2, put(n3), v3, put(n4), v4, put(n5), v5, put(n6), v6, spec);
  }

  public final NameDict dict8(String n0, Object v0, String n1, Object v1, String n2, Object v2, String n3, Object v3, String n4, Object v4, String n5, Object v5, String n6, Object v6, String n7, Object v7) { return dict8(n0, v0, n1, v1, n2, v2, n3, v3, n4, v4, n5, v5, n6, v6, n7, v7, null); }
  public final NameDict dict8(String n0, Object v0, String n1, Object v1, String n2, Object v2, String n3, Object v3, String n4, Object v4, String n5, Object v5, String n6, Object v6, String n7, Object v7, Spec spec)
  {
    return new NameDict.D8(this, put(n0), v0, put(n1), v1, put(n2), v2, put(n3), v3, put(n4), v4, put(n5), v5, put(n6), v6, put(n7), v7, spec);
  }

  public final NameDict dictMap(Map map) { return dictMap(map, null); }
  public final NameDict dictMap(Map map, Spec spec)
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
      vals[i] = e.getValue();
      ++i;
    }

    if (size <= 8)
    {
      switch (size)
      {
        case 1: return new NameDict.D1(this, names[0], vals[0], spec);
        case 2: return new NameDict.D2(this, names[0], vals[0], names[1], vals[1], spec);
        case 3: return new NameDict.D3(this, names[0], vals[0], names[1], vals[1], names[2], vals[2], spec);
        case 4: return new NameDict.D4(this, names[0], vals[0], names[1], vals[1], names[2], vals[2], names[3], vals[3], spec);
        case 5: return new NameDict.D5(this, names[0], vals[0], names[1], vals[1], names[2], vals[2], names[3], vals[3], names[4], vals[4], spec);
        case 6: return new NameDict.D6(this, names[0], vals[0], names[1], vals[1], names[2], vals[2], names[3], vals[3], names[4], vals[4], names[5], vals[5], spec);
        case 7: return new NameDict.D7(this, names[0], vals[0], names[1], vals[1], names[2], vals[2], names[3], vals[3], names[4], vals[4], names[5], vals[5], names[6], vals[6], spec);
        case 8: return new NameDict.D8(this, names[0], vals[0], names[1], vals[1], names[2], vals[2], names[3], vals[3], names[4], vals[4], names[5], vals[5], names[6], vals[6], names[7], vals[7], spec);
      }
    }

    return new NameDict.Map(this, names, vals, size, spec);
  }

  public final NameDict dictDict(Dict dict) { return dictDict(dict, null); }
  public final NameDict dictDict(Dict dict, Spec spec)
  {
    if (dict.isEmpty()) return NameDict.empty();

    if (dict instanceof NameDict)
    {
      NameDict nameDict = (NameDict)dict;
      if (nameDict.table == this) return nameDict;
    }

    DictEachAcc acc = new DictEachAcc(this);
    dict.each(acc);
    int[] names = acc.names;
    Object[] vals = acc.vals;
    int size = acc.size;

    if (size <= 8)
    {
      switch (size)
      {
        case 1: return new NameDict.D1(this, names[0], vals[0], spec);
        case 2: return new NameDict.D2(this, names[0], vals[0], names[1], vals[1], spec);
        case 3: return new NameDict.D3(this, names[0], vals[0], names[1], vals[1], names[2], vals[2], spec);
        case 4: return new NameDict.D4(this, names[0], vals[0], names[1], vals[1], names[2], vals[2], names[3], vals[3], spec);
        case 5: return new NameDict.D5(this, names[0], vals[0], names[1], vals[1], names[2], vals[2], names[3], vals[3], names[4], vals[4], spec);
        case 6: return new NameDict.D6(this, names[0], vals[0], names[1], vals[1], names[2], vals[2], names[3], vals[3], names[4], vals[4], names[5], vals[5], spec);
        case 7: return new NameDict.D7(this, names[0], vals[0], names[1], vals[1], names[2], vals[2], names[3], vals[3], names[4], vals[4], names[5], vals[5], names[6], vals[6], spec);
        case 8: return new NameDict.D8(this, names[0], vals[0], names[1], vals[1], names[2], vals[2], names[3], vals[3], names[4], vals[4], names[5], vals[5], names[6], vals[6], names[7], vals[7], spec);
      }
    }

    return new NameDict.Map(this, names, vals, size, spec);
  }

  private static final FuncType eachFuncType = new FuncType(new Type[] { Sys.ObjType, Sys.StrType }, Sys.ObjType);

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
}