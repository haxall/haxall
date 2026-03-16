//
// Copyright (c) 2024, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   6 Sep 2024  Brian Frank  Creation
//

using concurrent
using xeto
using xetom
using haystack

**
** CompSpaceMiscTest **without** standard setup/teardown
**
class CompSpaceMiscTest: AbstractXetoTest
{

//////////////////////////////////////////////////////////////////////////
// ActorCompSpace
//////////////////////////////////////////////////////////////////////////

  Void testInstall()
  {
    // verify no comp space installed
    verifyErrMsg(Err#, "No CompSpace installed for current thread") { x := CompObj() }

    // create
    ns := createNamespace(["hx.test.xeto"])
    cs := CompSpace(ns)
    verifySame(cs.ns, ns)
    verifyEq(cs.isRunning, false)
    verifyErrMsg(Err#, "Must call load") { cs.root }

    // still not installed
    verifyErrMsg(Err#, "No CompSpace installed for current thread") { x := CompObj() }

    // now install
    verifyEq(Actor.locals[CompSpace.actorKey], null)
    cs.install
    verifySame(Actor.locals[CompSpace.actorKey], cs)
    verifyEq(CompObj().spec.qname, "sys.comp::Comp")
    verifyEq(cs.root.spec.qname, "sys.comp::Comp") // default root to CompObj

    // cannot install another
    verifyErrMsg(Err#, "CompSpace already installed for current thread") { CompSpace(ns).install }

    // still not started
    verifyEq(cs.isRunning, false)
    verifyErrMsg(Err#, "CompSpace not running") { cs.execute }

    // now start
    cs.start
    verifyEq(cs.isRunning, true)
    verifyErr(ContextUnavailableErr#) { cs.execute }

    // uninstall, verify stopped and no more CompObj make support
    CompSpace.uninstall
    verifyEq(Actor.locals[CompSpace.actorKey], null)
    verifyEq(cs.isRunning, false)
    verifyErrMsg(Err#, "No CompSpace installed for current thread") { x := CompObj() }
  }

//////////////////////////////////////////////////////////////////////////
// ActorCompSpace
//////////////////////////////////////////////////////////////////////////

  Void testActorCompSpace()
  {
    ns := createNamespace(CompTest.loadTestLibs)
    xeto := CompTest.loadTestXeto

    a := CompSpaceActor(ActorPool())
    a.init(CompSpace(ns)).get
    a.loadXeto(xeto).get
    a.execute.get
  }
}

