//
// Copyright (c) 2026, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   17 Sep 2026  Brian Frank  Split from InheritSpecs
//

using util
using xeto
using xetom
using haystack

**
** InheritBase walks all top specs to resolve the following ASpec fields:
**   - base
**   - typeRef
**   - flags
**
** We also use this step to create a list of types orderd by inheritance
** for subsequent steps to use in lib.types.
**
@Js
internal class InheritBase : InheritFlags
{
  override Void run()
  {
    lib.tops.each |spec| { inherit(spec) }
    bombIfErr
    lib.ast.topsInInheritOrder = mixins.addAll(types)
  }

//////////////////////////////////////////////////////////////////////////
// Spec
//////////////////////////////////////////////////////////////////////////

  ** Process inheritance of given spec with cyclic checks
  private Void inherit(ASpec spec)
  {
    // check if already processed
    if (spec.ast.flags >= 0) return

    // check for cyclic inheritance
    if (isCyclicInheritance(spec) && !isSys)
    {
      // report error for every type in the cycle
      types := Str:Str[:]
      stack.each |s| { if (s.isType) types[s.qname] = s.qname }
      err("Cyclic inheritance: " + types.vals.sort.join(", "), spec.loc)
      spec.flags = 0
      spec.setNoMembers
      return
    }

    // push onto stack to keep track of cycles
    stack.push(spec)

    // process
    doInherit(spec)

    // pop from stack
    stack.pop
  }

  private Bool isCyclicInheritance(ASpec spec)
  {
    // walk stack backwards checking if spec is already on the stack
    // via a pure type inheritance path (not thru slot references)
    for (i := stack.size - 1; i >= 0; --i)
    {
      s := stack[i]
      if (s === spec) return true

      /*
      // if we turn this on we can have slots that forward refernce
      // subtypes of the parent type; however enabling that will
      // break RemoteLoader which requires a single pass; see the
      // hx.test.xeto test for "TestWidget" and "TestTool"
      if (!s.isType) return false
      */
    }
    return false
  }

  private Void doInherit(ASpec spec)
  {
    // special handling for sys::Obj
    if (spec.isObj)
    {
      spec.flags = 0
      spec.setNoMembers
      types.add(spec)
      return
    }

    // if inheritance type was omitted we assume dict
    if (spec.typeRef == null) spec.typeRef = sys.dict

    // base is always same as type
    spec.ast.base = spec.typeRef.deref

    // if base is in my AST, then recursively process it first
    if (spec.base.isAst) inherit(spec.base)

    // compute effective flags
    inheritFlags(spec)

    // keep track of tops in order now that inheritance has been processed
    if (spec.isType) types.add(spec)
    if (spec.isMixin) mixins.add(spec)
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  private ASpec[] stack  := [,]
  private ASpec[] types  := [,]
  private ASpec[] mixins := [,]
}

