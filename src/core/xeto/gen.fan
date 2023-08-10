#! /usr/bin/env fan
//
// Copyright (c) 2023, Brian Frank
// All Rights Reserved
//
// History:
//   26 Mar 2023  Brian Frank  Creation
//

using build

**
** Build: xeto
**
class Gen : BuildScript
{
  @Target { help="Generate code" }
  Void gen()
  {
    echo("GENERATE CODE $scriptDir")
    genNameDictJava(scriptDir+`java/NameDict.java`)
  }

  Void genNameDictJava(File file)
  {
    out := file.out

    out.printLine("// auto-generated $DateTime.now.toLocale\n")

    out.printLine(
       """package fan.xeto;

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
          """);

    for (i := 1; i<=8; ++i)
    {
      out.printLine("//////////////////////////////////////////////////////////////////////////")
      out.printLine("// D${i}")
      out.printLine("//////////////////////////////////////////////////////////////////////////")
      out.printLine
      out.printLine("  static final class D${i} extends NameDict {")
      out.printLine

      // constructor
      out.print("    D${i}(NameTable table")
      for (j:=0; j<i; ++j)
      {
        out.print(", int n" + j + ", Object v" + j)
      }
      out.printLine(", Spec spec)")
      out.printLine("    {")
      out.printLine("      super(table, spec);")
      for (j:=0; j<i; ++j)
      {
        out.printLine("      this.n${j} = n${j};")
        out.printLine("      this.v${j} = v${j};")
      }
      out.printLine("    }")
      out.printLine

      // size
      out.printLine("    public final long size() { return ${i}L; }")
      out.printLine

      // get
      out.printLine("    public final Object get(int n, Object def)")
      out.printLine("    {")
      out.printLine("      if (n == 0) return def;")
      for (j:=0; j<i; ++j)
      {
        out.printLine("      if (n == n${j}) return v${j};")
      }
      out.printLine("      return def;")
      out.printLine("    }")
      out.printLine

      // each
      out.printLine("    public final void each(Func f)")
      out.printLine("    {")
      for (j:=0; j<i; ++j)
      {
        out.printLine("      f.call(v${j}, table.name(n${j}));")
      }
      out.printLine("    }")
      out.printLine

      // eachWhile
      out.printLine("    public final Object eachWhile(Func f)")
      out.printLine("    {")
      out.printLine("      Object r;")
      for (j:=0; j<i; ++j)
      {
        out.printLine("      r = f.call(v${j}, table.name(n${j})); if (r != null) return r;")
      }
      out.printLine("      return null;")
      out.printLine("    }")
      out.printLine

      // map
      out.printLine("    public final NameDict map(Func f)")
      out.printLine("    {")
      out.printLine("      return new D${i}(table, ")
      for (j:=0; j<i; ++j)
      {
        out.printLine("        n${j}, ci(f.call(v${j}, table.name(n${j}))), ")
      }
      out.printLine("        spec);")
      out.printLine("    }")
      out.printLine

      // nameAt
      out.printLine("    public final long nameAt(int i)")
      out.printLine("    {")
      for (j:=0; j<i; ++j)
      {
        out.printLine("      if (i == $j) return n${j};")
      }
      out.printLine("      return super.nameAt(i);")
      out.printLine("    }")
      out.printLine

      // valAt
      out.printLine("    public final Object valAt(int i)")
      out.printLine("    {")
      for (j:=0; j<i; ++j)
      {
        out.printLine("      if (i == $j) return v${j};")
      }
      out.printLine("      return super.nameAt(i);")
      out.printLine("    }")
      out.printLine

      // fields
      for (j:=0; j<i; ++j)
      {
        out.printLine("    final int n${j};")
        out.printLine("    final Object v${j};")
      }

      out.printLine("  }");
      out.printLine
    }

    out.printLine("}\n")
    out.close
  }
}