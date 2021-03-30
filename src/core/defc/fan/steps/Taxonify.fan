//
// Copyright (c) 2018, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//    9 Jan 2019  Brian Frank  Creation
//

using haystack

**
** Taxonify builds the supertyper/subtype taxonomy tree.
** It sets the following fields on each CDef:
**   - supertypes
**   - inheritance
**
internal class Taxonify : DefCompilerStep
{
  new make(DefCompiler c) : super(c) {}

  override Void run()
  {
    eachDef |def| { taxonify(def) }
  }

  private Void taxonify(CDef def)
  {
    // short circuit if already taxonified
    if (def.inheritance != null) return

    // check stack for recursion
    if (stack.contains(def)) throw err("Circular dependency: " + stack.join(", "), def.loc)
    stack.push(def)

    // compute supertypes recusively
    try
    {
      // determine the implied "is" tag
      impliedIs(def)

      // compute inheritance (flattened is defs)
      computeInheritance(def)
    }
    catch (CompilerErr e)
    {
      def.fault = true
    }
    catch (Err e)
    {
      err("Cannot taxonify def: $def", def.loc, e)
      def.fault = true
    }

    // ensure we have fields set even if there was an error
    if (def.fault)
    {
      def.supertypes = CDef#.emptyList
      def.inheritance = [def]
      def.flags = CDefFlags.compute(def)
    }

    // pop recursion stack
    stack.pop
  }

//////////////////////////////////////////////////////////////////////////
// Implied Is
//////////////////////////////////////////////////////////////////////////

  private Void impliedIs(CDef def)
  {
    if (def.type.isKey) return impliedKeyIs(def)
  }

  private Void impliedKeyIs(CDef def)
  {
    // keys are implied to be a subtype of their feature
    feature := def.key.feature
    taxonify(feature)

    // if "is" is not declared, then imply it
    declaredList := declaredIs(def)
    if (declaredList.isEmpty)
    {
      def.set(etc.isDef, [feature])
      return
    }

    // ensure only one supertype declared
    if (declaredList.size != 1) return err("Declared 'is' must be one symbol: $def", def.loc)
    declared := declaredList.first

    // allow a feature subtype to be used
    taxonify(declared)
    if (!declared.isFeature) err("Declared 'is' is does not fit feature $feature: $def", def.loc)
  }

  private CDef[] declaredIs(CDef def)
  {
    // declared "is" attribute should already be CDef[] from Resolve
    def.meta["is"]?.val as CDef[] ?: CDef#.emptyList
  }

//////////////////////////////////////////////////////////////////////////
// Compute Inheritance
//////////////////////////////////////////////////////////////////////////

  private Void computeInheritance(CDef def)
  {
    // declared "is" attribute
    declared := declaredIs(def)

    // start off with myself and declared
    acc := CSymbol:CDef[:]
    acc.ordered = true
    if (def.type.isTerm) acc.add(def.symbol, def)
    declared.each |base| { acc.add(base.symbol, base) }

    // compute flatten is list
    computeInherited(acc, def)

    // store
    def.supertypes = declared
    def.inheritance = acc.vals
    def.flags = CDefFlags.compute(def)
  }

  private Void computeInherited(CSymbol:CDef acc, CDef def)
  {
    if (def.type.isKey) return
    acc.dup.each |base|
    {
      if (base == def) return
      doComputeIsInherit(acc, base)
    }
  }

  private Void doComputeIsInherit(CSymbol:CDef acc, CDef base)
  {
    // recurse to ensure base is normalized
    taxonify(base)

    // inherit any type from base not already in my meta
    base.inheritance.each |x|
    {
      if (acc[x.symbol] == null) acc[x.symbol] = x
    }
  }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  CDef[] stack := [,]
}

