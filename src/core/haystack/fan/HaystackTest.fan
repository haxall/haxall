//
// Copyright (c) 2010, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   05 Jan 2010  Brian Frank  Creation
//   03 Jan 2016  Brian Frank  Refactor for 3.0
//

using concurrent
using xeto

**
** HaystackTest provides convenience methods for testing
** common Haystack data structures.
**
@Js
abstract class HaystackTest : Test
{

  ** Convenience for constructing a `haystack::Number` where
  ** unit may be either a Str name or a Unit instance.
  static Number? n(Num? val, Obj? unit := null)
  {
    if (val == null) return null
    if (unit is Str) unit = Number.loadUnit(unit)
    return Number(val.toFloat, unit)
  }

  ** Convenience for `Marker.val`
  static const Marker m := Marker.val

  ** Access test namespace.  We assume running in a
  ** SkySpark test environment and route to ProjTest
  @NoDoc virtual DefNamespace ns()
  {
    ns := nsDefaultRef.val as DefNamespace
    if (ns == null)
    {
      // try as SkySpark environment first
      try
      {
        ns = Type.find("skyarcd::ProjTest").method("sysBoot").callOn(null, [this, null])->ns
      }
      catch (Err e) {}

      // next try as Haxall environment
      try
      {
        if (ns == null)
        {
          oldcx := Actor.locals[ActorContext.actorLocalsKey]
          Actor.locals.remove(ActorContext.actorLocalsKey)
          ns = Type.find("hxd::HxdTestSpi").method("boot").callOn(null, [this])->ns
          Actor.locals.addNotNull(ActorContext.actorLocalsKey, oldcx)
       }
      }
      catch (Err e) {}

      // fallback to standard Haystack namespace
      if (ns == null)
        ns = Type.find("defc::DefCompiler").make->compileNamespace

      nsDefaultRef.val = ns
    }
    return ns
  }
  private const static AtomicRef nsDefaultRef := AtomicRef()

  ** Verify two Dictts have same name/val pairs
  Void verifyDictEq(Dict a, Obj b, Str? msg := null)
  {
    if (b isnot Dict) b = Etc.makeDict(b)

    bd := (Dict)b
    bnames := Str:Str[:]; bd.each |v, n| { bnames[n] = n }

    a.each |v, n|
    {
      try
      {
        nmsg := msg == null ? n : "$msg -> $n"
        verifyValEq(v, bd[n], nmsg)
      }
      catch (TestErr e)
      {
        echo("TAG FAILED: $n")
        throw e
      }
      bnames.remove(n)
    }
    verifyEq(bnames.size, 0, bnames.keys.toStr)
    verifyEq(Etc.dictHashKey(a), Etc.dictHashKey(b))
  }


  ** Verify list of dicts are equal
  @NoDoc Void verifyDictsEq(Dict?[] a, Obj?[] b, Bool ordered := true)
  {
    verifyEq(a.size, b.size)
    if (!ordered)
    {
      b = b.map { it is Dict ? it : Etc.makeDict(it) }
      a = a.dup.sort |x, y| { x?->id <=> y?->id }
      b = b.dup.sort |x, y| { x?->id <=> y?->id }
    }
    verifyEq(a.size, b.size)
    a.each |ar, i|
    {
      br := b[i]
      if (ar == null)
        verifyEq(ar, br)
      else
        verifyDictEq(ar, br)
    }
  }

  ** Verify that given grid is empty (has no rows)
  Void verifyGridIsEmpty(Grid g)
  {
    verifyEq(g.size, 0)
    verifyEq(g.isEmpty, true)
    verifyEq(g.first, null)
    rows := Dict[,]; g.each |row| { rows.add(row) }
    verifyEq(rows.size, 0)
  }

  ** Verify that two grids are equal (meta, cols, and rows)
  Void verifyGridEq(Grid a, Grid b)
  {
    verifyEq(a.size, b.size)
    verifyEq(Etc.dictToMap(a.meta), Etc.dictToMap(b.meta))
    verifyEq(a.cols.size, b.cols.size)
    a.cols.each |ac, i|
    {
      verifyEq(a.has(ac.name), true, ac.name)
      verifyEq(a.missing(ac.name), false, ac.name)
      verifyColEq(ac, b.cols[i])
    }
    arows := Row[,]; a.each |r| { arows.add(r) }
    brows := Row[,]; b.each |r| { brows.add(r) }
    verifyEq(arows.size, brows.size)
    arows.each |ar, i|
    {
      br := brows[i]
      verifySame(a, ar.grid)
      verifySame(b, br.grid)
      try
      {
        verifyRowEq(ar, br)
      }
      catch (TestErr e)
      {
        echo("ROW FAILED: $i")
        throw e
      }
    }
  }

  ** Verify two grid columns are equal
  @NoDoc Void verifyColEq(Col a, Col b)
  {
    verifyEq(a.name, b.name)
    verifyEq(a.dis, b.dis)
    verifyDictEq(a.meta, b.meta)
  }

  ** Verify two grid rows are equal
  @NoDoc Void verifyRowEq(Row a, Row b)
  {
    verifyDictEq(a, b)
    a.grid.cols.each |ac, i|
    {
      try
      {
        bc := b.grid.cols[i]
        verifyValEq(a.val(ac), b.val(bc))
      }
      catch (TestErr e)
      {
        echo("COL FAILED: $ac.name")
        throw e
      }
    }
  }

  ** Verify two Haystack values are equal.  This method provides
  ** additional checking for types which don't support equal including:
  **    - Ref.dis
  **    - Dict
  **    - Grid
  Void verifyValEq(Obj? a, Obj? b, Str? msg := null)
  {
    if (a is Ref && b is Ref)   return verifyRefEq(a, b, msg)
    if (a is List && b is List) return verifyListEq(a, b, msg)
    if (a is Dict && b is Dict) return verifyDictEq(a, b, msg)
    if (a is Grid && b is Grid) return verifyGridEq(a, b)
    if (a is Buf && b is Buf)   return verifyBufEq(a, b, msg)
    verifyEq(a, b, msg)
  }

  ** Verify two Refs are equal for both id and dis
  Void verifyRefEq(Ref a, Ref b, Str? msg := null)
  {
    verifyEq(a.id, b.id, msg)
    verifyEq(a.dis, b.dis, msg)
  }

  ** Verify contents of two lists using `verifyValEq`
  virtual Void verifyListEq(List a, List b, Str? msg := null)
  {
    verifyEq(a.typeof, b.typeof, msg)
    verifyEq(a.size, b.size, msg)
    a.each |v, i| { verifyValEq(v, b[i], msg) }
  }

  ** Verify two buffers are equal
  @NoDoc Void verifyBufEq(Buf a, Buf b, Str? msg := null)
  {
    verifyEq(a.toHex, b.toHex, msg)
  }

  ** Verify grid row ids match given ids
  @NoDoc Void verifyRecIds(Grid grid, Ref[] ids)
  {
    gridIds := Ref?[,]
    grid.each |row| { gridIds.add(row.id) }
    if (ids.typeof != Ref?[]#) ids = Ref?[,].addAll(ids)
    verifyEq(gridIds.sort, ids.sort)
  }

  ** Verify two Numbers are approx
  @NoDoc Void verifyNumApprox(Number? a, Obj? b, Float? tolerance := null)
  {
    bn := b as Number ?: Number((Float)b)
    if ((a == null && b != null) ||
        (a != null && b == null)) fail("$a != $b")
    if (!a.toFloat.approx(bn.toFloat, tolerance)) fail("$a ~= $b")
    verify(true)
  }
}

