//
// Copyright (c) 2015, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   28 Oct 2015  Brian Frank  Creation
//   11 Aug 2020  Brian Frank  Rename FolioTracker to FolioHooks, add ns
//

using haystack

**
** Callback hooks including Namespace support and monitoring all committed diffs.
** All callbacks are on folio actor, so processing must be fast and anything
** expensive should be dispatched to other actors
**
@NoDoc
const mixin FolioHooks
{
  ** Def namespace is available
  abstract Namespace? ns(Bool checked := true)

  ** Callback before diff is committed during verify
  ** phase. An exception will cancel entire commit.
  ** Pass through FolioContext.commitInfo if available.
  abstract Void preCommit(Diff diff, Obj? cxInfo)

  ** Callback after diff has been committed.
  ** Pass through FolioContext.commitInfo if available.
  abstract Void postCommit(Diff diff, Obj? cxInfo)
}

**************************************************************************
** NilTracker
**************************************************************************

**
** NilHooks is the default no-op for all callbacks
**
internal const class NilHooks : FolioHooks
{
  override Namespace? ns(Bool checked := true) { if (checked) throw UnsupportedErr("Namespace not availble"); return null }
  override Void preCommit(Diff d, Obj? cxInfo) {}
  override Void postCommit(Diff d, Obj? cxInfo) {}
}



