// auto-generated 10-Aug-2023 Thu 8:23:38AM EDT

package fan.xeto;

import fan.sys.*;

/**
 * NameDict
 */
public abstract class NameDict extends FanObj implements Dict
{
  public static NameDict empty() { return empty; }
  private static final NameDict empty = new D0();

  NameDict(NameTable table, Spec spec)
  {
    this.table = table;
    this.spec = spec;
  }

  final NameTable table;

  final Spec spec;

  public final Type typeof() { return typeof; }
  private static final Type typeof = Type.find("xeto::NameDict");

  public Spec spec()
  {
    if (spec != null) return spec;
    return XetoEnv.cur().dictSpec();
  }

  public Ref id()
  {
    Object val = get(table.idCode, null);
    if (val != null) return (Ref)val;
    throw UnresolvedErr.make("id");
  }

  public boolean isEmpty() { return false; }

  public abstract long size();

  public final boolean has(String name) { return get(name) != null; }

  public final boolean missing(String name) { return get(name) == null; }

  public Object get(String name) { return get(table.code(name), null); }

  public Object get(String name, Object def) { return get(table.code(name), def); }

  public abstract Object get(int name, Object def);

  public abstract void each(Func f);

  public abstract Object eachWhile(Func f);

  public abstract NameDict map(Func f);

  public long fixedSize() { return size(); }

  public final Object trap(String name) { return trap(name, (List)null); }
  public final Object trap(String name, List args)
  {
    Object val = get(name, null);
    if (val != null) return val;
    throw UnresolvedErr.make(name);
  }

  public final long nameAt(long i) { return nameAt((int)i); }

  public final Object valAt(long i) { return valAt((int)i); }

  public long nameAt(int i) { throw IndexErr.make(); }

  public Object valAt(int i) { throw IndexErr.make(); }

  static Object ci(Object v)
  {
    // check immutable
    return FanObj.toImmutable(v);
  }

//////////////////////////////////////////////////////////////////////////
// Map
//////////////////////////////////////////////////////////////////////////

  static final class Map extends NameDict {
    Map(NameTable table, int[] names, Object[] vals, int size, Spec spec)
    {
      super(table, spec);
      this.names = names;
      this.vals = vals;
      this.size = size;
    }

    public final long size() { return size; }

    public final long fixedSize() { return -1L; }

    public final Object get(int n, Object def)
    {
      for (int i=0; i<size; ++i)
        if (names[i] == n) return vals[i];
      return def;
    }

    public final void each(Func f)
    {
      for (int i=0; i<size; ++i)
        f.call(vals[i], table.name(names[i]));
    }

    public final Object eachWhile(Func f)
    {
      for (int i=0; i<size; ++i)
      {
        Object r = f.call(vals[i], table.name(names[i]));
        if (r != null) return r;
      }
      return null;
    }

    public final NameDict map(Func f)
    {
      Object[] newVals = new Object[size];
      for (int i=0; i<size; ++i)
        newVals[i] = ci(f.call(vals[i], table.name(names[i])));
      return new Map(table, names, newVals, size, spec);
    }

    public final long nameAt(int i) { return names[i]; }

    public final Object valAt(int i) { return vals[i]; }

    final int[] names;
    final Object[] vals;
    final int size;
  }

//////////////////////////////////////////////////////////////////////////
// D0
//////////////////////////////////////////////////////////////////////////

  static final class D0 extends NameDict {

    D0() { super(null, null); }

    public final boolean isEmpty() { return true; }

    public final long size() { return 0L; }

    public final Ref id() { throw UnresolvedErr.make("id"); }

    public final Object get(String name) { return null; }

    public final Object get(String name, Object def) { return def; }

    public final Object get(int n, Object def) { return def; }

    public final void each(Func f) {}

    public final Object eachWhile(Func f) { return null; }

    public final NameDict map(Func f) { return this; }
  }

//////////////////////////////////////////////////////////////////////////
// D1
//////////////////////////////////////////////////////////////////////////

  static final class D1 extends NameDict {

    D1(NameTable table, int n0, Object v0, Spec spec)
    {
      super(table, spec);
      this.n0 = n0;
      this.v0 = v0;
    }

    public final long size() { return 1L; }

    public final Object get(int n, Object def)
    {
      if (n == 0) return def;
      if (n == n0) return v0;
      return def;
    }

    public final void each(Func f)
    {
      f.call(v0, table.name(n0));
    }

    public final Object eachWhile(Func f)
    {
      Object r;
      r = f.call(v0, table.name(n0)); if (r != null) return r;
      return null;
    }

    public final NameDict map(Func f)
    {
      return new D1(table, 
        n0, ci(f.call(v0, table.name(n0))), 
        spec);
    }

    public final long nameAt(int i)
    {
      if (i == 0) return n0;
      return super.nameAt(i);
    }

    public final Object valAt(int i)
    {
      if (i == 0) return v0;
      return super.nameAt(i);
    }

    final int n0;
    final Object v0;
  }

//////////////////////////////////////////////////////////////////////////
// D2
//////////////////////////////////////////////////////////////////////////

  static final class D2 extends NameDict {

    D2(NameTable table, int n0, Object v0, int n1, Object v1, Spec spec)
    {
      super(table, spec);
      this.n0 = n0;
      this.v0 = v0;
      this.n1 = n1;
      this.v1 = v1;
    }

    public final long size() { return 2L; }

    public final Object get(int n, Object def)
    {
      if (n == 0) return def;
      if (n == n0) return v0;
      if (n == n1) return v1;
      return def;
    }

    public final void each(Func f)
    {
      f.call(v0, table.name(n0));
      f.call(v1, table.name(n1));
    }

    public final Object eachWhile(Func f)
    {
      Object r;
      r = f.call(v0, table.name(n0)); if (r != null) return r;
      r = f.call(v1, table.name(n1)); if (r != null) return r;
      return null;
    }

    public final NameDict map(Func f)
    {
      return new D2(table, 
        n0, ci(f.call(v0, table.name(n0))), 
        n1, ci(f.call(v1, table.name(n1))), 
        spec);
    }

    public final long nameAt(int i)
    {
      if (i == 0) return n0;
      if (i == 1) return n1;
      return super.nameAt(i);
    }

    public final Object valAt(int i)
    {
      if (i == 0) return v0;
      if (i == 1) return v1;
      return super.nameAt(i);
    }

    final int n0;
    final Object v0;
    final int n1;
    final Object v1;
  }

//////////////////////////////////////////////////////////////////////////
// D3
//////////////////////////////////////////////////////////////////////////

  static final class D3 extends NameDict {

    D3(NameTable table, int n0, Object v0, int n1, Object v1, int n2, Object v2, Spec spec)
    {
      super(table, spec);
      this.n0 = n0;
      this.v0 = v0;
      this.n1 = n1;
      this.v1 = v1;
      this.n2 = n2;
      this.v2 = v2;
    }

    public final long size() { return 3L; }

    public final Object get(int n, Object def)
    {
      if (n == 0) return def;
      if (n == n0) return v0;
      if (n == n1) return v1;
      if (n == n2) return v2;
      return def;
    }

    public final void each(Func f)
    {
      f.call(v0, table.name(n0));
      f.call(v1, table.name(n1));
      f.call(v2, table.name(n2));
    }

    public final Object eachWhile(Func f)
    {
      Object r;
      r = f.call(v0, table.name(n0)); if (r != null) return r;
      r = f.call(v1, table.name(n1)); if (r != null) return r;
      r = f.call(v2, table.name(n2)); if (r != null) return r;
      return null;
    }

    public final NameDict map(Func f)
    {
      return new D3(table, 
        n0, ci(f.call(v0, table.name(n0))), 
        n1, ci(f.call(v1, table.name(n1))), 
        n2, ci(f.call(v2, table.name(n2))), 
        spec);
    }

    public final long nameAt(int i)
    {
      if (i == 0) return n0;
      if (i == 1) return n1;
      if (i == 2) return n2;
      return super.nameAt(i);
    }

    public final Object valAt(int i)
    {
      if (i == 0) return v0;
      if (i == 1) return v1;
      if (i == 2) return v2;
      return super.nameAt(i);
    }

    final int n0;
    final Object v0;
    final int n1;
    final Object v1;
    final int n2;
    final Object v2;
  }

//////////////////////////////////////////////////////////////////////////
// D4
//////////////////////////////////////////////////////////////////////////

  static final class D4 extends NameDict {

    D4(NameTable table, int n0, Object v0, int n1, Object v1, int n2, Object v2, int n3, Object v3, Spec spec)
    {
      super(table, spec);
      this.n0 = n0;
      this.v0 = v0;
      this.n1 = n1;
      this.v1 = v1;
      this.n2 = n2;
      this.v2 = v2;
      this.n3 = n3;
      this.v3 = v3;
    }

    public final long size() { return 4L; }

    public final Object get(int n, Object def)
    {
      if (n == 0) return def;
      if (n == n0) return v0;
      if (n == n1) return v1;
      if (n == n2) return v2;
      if (n == n3) return v3;
      return def;
    }

    public final void each(Func f)
    {
      f.call(v0, table.name(n0));
      f.call(v1, table.name(n1));
      f.call(v2, table.name(n2));
      f.call(v3, table.name(n3));
    }

    public final Object eachWhile(Func f)
    {
      Object r;
      r = f.call(v0, table.name(n0)); if (r != null) return r;
      r = f.call(v1, table.name(n1)); if (r != null) return r;
      r = f.call(v2, table.name(n2)); if (r != null) return r;
      r = f.call(v3, table.name(n3)); if (r != null) return r;
      return null;
    }

    public final NameDict map(Func f)
    {
      return new D4(table, 
        n0, ci(f.call(v0, table.name(n0))), 
        n1, ci(f.call(v1, table.name(n1))), 
        n2, ci(f.call(v2, table.name(n2))), 
        n3, ci(f.call(v3, table.name(n3))), 
        spec);
    }

    public final long nameAt(int i)
    {
      if (i == 0) return n0;
      if (i == 1) return n1;
      if (i == 2) return n2;
      if (i == 3) return n3;
      return super.nameAt(i);
    }

    public final Object valAt(int i)
    {
      if (i == 0) return v0;
      if (i == 1) return v1;
      if (i == 2) return v2;
      if (i == 3) return v3;
      return super.nameAt(i);
    }

    final int n0;
    final Object v0;
    final int n1;
    final Object v1;
    final int n2;
    final Object v2;
    final int n3;
    final Object v3;
  }

//////////////////////////////////////////////////////////////////////////
// D5
//////////////////////////////////////////////////////////////////////////

  static final class D5 extends NameDict {

    D5(NameTable table, int n0, Object v0, int n1, Object v1, int n2, Object v2, int n3, Object v3, int n4, Object v4, Spec spec)
    {
      super(table, spec);
      this.n0 = n0;
      this.v0 = v0;
      this.n1 = n1;
      this.v1 = v1;
      this.n2 = n2;
      this.v2 = v2;
      this.n3 = n3;
      this.v3 = v3;
      this.n4 = n4;
      this.v4 = v4;
    }

    public final long size() { return 5L; }

    public final Object get(int n, Object def)
    {
      if (n == 0) return def;
      if (n == n0) return v0;
      if (n == n1) return v1;
      if (n == n2) return v2;
      if (n == n3) return v3;
      if (n == n4) return v4;
      return def;
    }

    public final void each(Func f)
    {
      f.call(v0, table.name(n0));
      f.call(v1, table.name(n1));
      f.call(v2, table.name(n2));
      f.call(v3, table.name(n3));
      f.call(v4, table.name(n4));
    }

    public final Object eachWhile(Func f)
    {
      Object r;
      r = f.call(v0, table.name(n0)); if (r != null) return r;
      r = f.call(v1, table.name(n1)); if (r != null) return r;
      r = f.call(v2, table.name(n2)); if (r != null) return r;
      r = f.call(v3, table.name(n3)); if (r != null) return r;
      r = f.call(v4, table.name(n4)); if (r != null) return r;
      return null;
    }

    public final NameDict map(Func f)
    {
      return new D5(table, 
        n0, ci(f.call(v0, table.name(n0))), 
        n1, ci(f.call(v1, table.name(n1))), 
        n2, ci(f.call(v2, table.name(n2))), 
        n3, ci(f.call(v3, table.name(n3))), 
        n4, ci(f.call(v4, table.name(n4))), 
        spec);
    }

    public final long nameAt(int i)
    {
      if (i == 0) return n0;
      if (i == 1) return n1;
      if (i == 2) return n2;
      if (i == 3) return n3;
      if (i == 4) return n4;
      return super.nameAt(i);
    }

    public final Object valAt(int i)
    {
      if (i == 0) return v0;
      if (i == 1) return v1;
      if (i == 2) return v2;
      if (i == 3) return v3;
      if (i == 4) return v4;
      return super.nameAt(i);
    }

    final int n0;
    final Object v0;
    final int n1;
    final Object v1;
    final int n2;
    final Object v2;
    final int n3;
    final Object v3;
    final int n4;
    final Object v4;
  }

//////////////////////////////////////////////////////////////////////////
// D6
//////////////////////////////////////////////////////////////////////////

  static final class D6 extends NameDict {

    D6(NameTable table, int n0, Object v0, int n1, Object v1, int n2, Object v2, int n3, Object v3, int n4, Object v4, int n5, Object v5, Spec spec)
    {
      super(table, spec);
      this.n0 = n0;
      this.v0 = v0;
      this.n1 = n1;
      this.v1 = v1;
      this.n2 = n2;
      this.v2 = v2;
      this.n3 = n3;
      this.v3 = v3;
      this.n4 = n4;
      this.v4 = v4;
      this.n5 = n5;
      this.v5 = v5;
    }

    public final long size() { return 6L; }

    public final Object get(int n, Object def)
    {
      if (n == 0) return def;
      if (n == n0) return v0;
      if (n == n1) return v1;
      if (n == n2) return v2;
      if (n == n3) return v3;
      if (n == n4) return v4;
      if (n == n5) return v5;
      return def;
    }

    public final void each(Func f)
    {
      f.call(v0, table.name(n0));
      f.call(v1, table.name(n1));
      f.call(v2, table.name(n2));
      f.call(v3, table.name(n3));
      f.call(v4, table.name(n4));
      f.call(v5, table.name(n5));
    }

    public final Object eachWhile(Func f)
    {
      Object r;
      r = f.call(v0, table.name(n0)); if (r != null) return r;
      r = f.call(v1, table.name(n1)); if (r != null) return r;
      r = f.call(v2, table.name(n2)); if (r != null) return r;
      r = f.call(v3, table.name(n3)); if (r != null) return r;
      r = f.call(v4, table.name(n4)); if (r != null) return r;
      r = f.call(v5, table.name(n5)); if (r != null) return r;
      return null;
    }

    public final NameDict map(Func f)
    {
      return new D6(table, 
        n0, ci(f.call(v0, table.name(n0))), 
        n1, ci(f.call(v1, table.name(n1))), 
        n2, ci(f.call(v2, table.name(n2))), 
        n3, ci(f.call(v3, table.name(n3))), 
        n4, ci(f.call(v4, table.name(n4))), 
        n5, ci(f.call(v5, table.name(n5))), 
        spec);
    }

    public final long nameAt(int i)
    {
      if (i == 0) return n0;
      if (i == 1) return n1;
      if (i == 2) return n2;
      if (i == 3) return n3;
      if (i == 4) return n4;
      if (i == 5) return n5;
      return super.nameAt(i);
    }

    public final Object valAt(int i)
    {
      if (i == 0) return v0;
      if (i == 1) return v1;
      if (i == 2) return v2;
      if (i == 3) return v3;
      if (i == 4) return v4;
      if (i == 5) return v5;
      return super.nameAt(i);
    }

    final int n0;
    final Object v0;
    final int n1;
    final Object v1;
    final int n2;
    final Object v2;
    final int n3;
    final Object v3;
    final int n4;
    final Object v4;
    final int n5;
    final Object v5;
  }

//////////////////////////////////////////////////////////////////////////
// D7
//////////////////////////////////////////////////////////////////////////

  static final class D7 extends NameDict {

    D7(NameTable table, int n0, Object v0, int n1, Object v1, int n2, Object v2, int n3, Object v3, int n4, Object v4, int n5, Object v5, int n6, Object v6, Spec spec)
    {
      super(table, spec);
      this.n0 = n0;
      this.v0 = v0;
      this.n1 = n1;
      this.v1 = v1;
      this.n2 = n2;
      this.v2 = v2;
      this.n3 = n3;
      this.v3 = v3;
      this.n4 = n4;
      this.v4 = v4;
      this.n5 = n5;
      this.v5 = v5;
      this.n6 = n6;
      this.v6 = v6;
    }

    public final long size() { return 7L; }

    public final Object get(int n, Object def)
    {
      if (n == 0) return def;
      if (n == n0) return v0;
      if (n == n1) return v1;
      if (n == n2) return v2;
      if (n == n3) return v3;
      if (n == n4) return v4;
      if (n == n5) return v5;
      if (n == n6) return v6;
      return def;
    }

    public final void each(Func f)
    {
      f.call(v0, table.name(n0));
      f.call(v1, table.name(n1));
      f.call(v2, table.name(n2));
      f.call(v3, table.name(n3));
      f.call(v4, table.name(n4));
      f.call(v5, table.name(n5));
      f.call(v6, table.name(n6));
    }

    public final Object eachWhile(Func f)
    {
      Object r;
      r = f.call(v0, table.name(n0)); if (r != null) return r;
      r = f.call(v1, table.name(n1)); if (r != null) return r;
      r = f.call(v2, table.name(n2)); if (r != null) return r;
      r = f.call(v3, table.name(n3)); if (r != null) return r;
      r = f.call(v4, table.name(n4)); if (r != null) return r;
      r = f.call(v5, table.name(n5)); if (r != null) return r;
      r = f.call(v6, table.name(n6)); if (r != null) return r;
      return null;
    }

    public final NameDict map(Func f)
    {
      return new D7(table, 
        n0, ci(f.call(v0, table.name(n0))), 
        n1, ci(f.call(v1, table.name(n1))), 
        n2, ci(f.call(v2, table.name(n2))), 
        n3, ci(f.call(v3, table.name(n3))), 
        n4, ci(f.call(v4, table.name(n4))), 
        n5, ci(f.call(v5, table.name(n5))), 
        n6, ci(f.call(v6, table.name(n6))), 
        spec);
    }

    public final long nameAt(int i)
    {
      if (i == 0) return n0;
      if (i == 1) return n1;
      if (i == 2) return n2;
      if (i == 3) return n3;
      if (i == 4) return n4;
      if (i == 5) return n5;
      if (i == 6) return n6;
      return super.nameAt(i);
    }

    public final Object valAt(int i)
    {
      if (i == 0) return v0;
      if (i == 1) return v1;
      if (i == 2) return v2;
      if (i == 3) return v3;
      if (i == 4) return v4;
      if (i == 5) return v5;
      if (i == 6) return v6;
      return super.nameAt(i);
    }

    final int n0;
    final Object v0;
    final int n1;
    final Object v1;
    final int n2;
    final Object v2;
    final int n3;
    final Object v3;
    final int n4;
    final Object v4;
    final int n5;
    final Object v5;
    final int n6;
    final Object v6;
  }

//////////////////////////////////////////////////////////////////////////
// D8
//////////////////////////////////////////////////////////////////////////

  static final class D8 extends NameDict {

    D8(NameTable table, int n0, Object v0, int n1, Object v1, int n2, Object v2, int n3, Object v3, int n4, Object v4, int n5, Object v5, int n6, Object v6, int n7, Object v7, Spec spec)
    {
      super(table, spec);
      this.n0 = n0;
      this.v0 = v0;
      this.n1 = n1;
      this.v1 = v1;
      this.n2 = n2;
      this.v2 = v2;
      this.n3 = n3;
      this.v3 = v3;
      this.n4 = n4;
      this.v4 = v4;
      this.n5 = n5;
      this.v5 = v5;
      this.n6 = n6;
      this.v6 = v6;
      this.n7 = n7;
      this.v7 = v7;
    }

    public final long size() { return 8L; }

    public final Object get(int n, Object def)
    {
      if (n == 0) return def;
      if (n == n0) return v0;
      if (n == n1) return v1;
      if (n == n2) return v2;
      if (n == n3) return v3;
      if (n == n4) return v4;
      if (n == n5) return v5;
      if (n == n6) return v6;
      if (n == n7) return v7;
      return def;
    }

    public final void each(Func f)
    {
      f.call(v0, table.name(n0));
      f.call(v1, table.name(n1));
      f.call(v2, table.name(n2));
      f.call(v3, table.name(n3));
      f.call(v4, table.name(n4));
      f.call(v5, table.name(n5));
      f.call(v6, table.name(n6));
      f.call(v7, table.name(n7));
    }

    public final Object eachWhile(Func f)
    {
      Object r;
      r = f.call(v0, table.name(n0)); if (r != null) return r;
      r = f.call(v1, table.name(n1)); if (r != null) return r;
      r = f.call(v2, table.name(n2)); if (r != null) return r;
      r = f.call(v3, table.name(n3)); if (r != null) return r;
      r = f.call(v4, table.name(n4)); if (r != null) return r;
      r = f.call(v5, table.name(n5)); if (r != null) return r;
      r = f.call(v6, table.name(n6)); if (r != null) return r;
      r = f.call(v7, table.name(n7)); if (r != null) return r;
      return null;
    }

    public final NameDict map(Func f)
    {
      return new D8(table, 
        n0, ci(f.call(v0, table.name(n0))), 
        n1, ci(f.call(v1, table.name(n1))), 
        n2, ci(f.call(v2, table.name(n2))), 
        n3, ci(f.call(v3, table.name(n3))), 
        n4, ci(f.call(v4, table.name(n4))), 
        n5, ci(f.call(v5, table.name(n5))), 
        n6, ci(f.call(v6, table.name(n6))), 
        n7, ci(f.call(v7, table.name(n7))), 
        spec);
    }

    public final long nameAt(int i)
    {
      if (i == 0) return n0;
      if (i == 1) return n1;
      if (i == 2) return n2;
      if (i == 3) return n3;
      if (i == 4) return n4;
      if (i == 5) return n5;
      if (i == 6) return n6;
      if (i == 7) return n7;
      return super.nameAt(i);
    }

    public final Object valAt(int i)
    {
      if (i == 0) return v0;
      if (i == 1) return v1;
      if (i == 2) return v2;
      if (i == 3) return v3;
      if (i == 4) return v4;
      if (i == 5) return v5;
      if (i == 6) return v6;
      if (i == 7) return v7;
      return super.nameAt(i);
    }

    final int n0;
    final Object v0;
    final int n1;
    final Object v1;
    final int n2;
    final Object v2;
    final int n3;
    final Object v3;
    final int n4;
    final Object v4;
    final int n5;
    final Object v5;
    final int n6;
    final Object v6;
    final int n7;
    final Object v7;
  }

}

