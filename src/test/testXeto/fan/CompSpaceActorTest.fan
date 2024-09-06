//
// Copyright (c) 2024, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   6 Sep 2024  Brian Frank  Creation
//

using concurrent
using xeto
using xetoEnv
using haystack

**
** CompSpaceActorTest
**
class CompSpaceActorTest: AbstractXetoTest
{
  Void test()
  {
    ns := createNamespace(CompTest.loadTestLibs)
    xeto := CompTest.loadTestXeto

    a := CompSpaceActor(ActorPool())
    a.init(CompSpace#, [ns]).get
    a.load(xeto).get
    a.checkTimers.get
  }
}

