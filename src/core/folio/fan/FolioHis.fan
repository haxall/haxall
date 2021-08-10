//
// Copyright (c) 2017, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   6 Sep 2017  Brian Frank  Break out of Folio
//

using haystack

**
** FolioHis provides APIs associated with reading/writing history data.
** NOTE: these are undocumented APIs for the storage layer only.
** Applications should use the HxHisService API
**
@NoDoc
const mixin FolioHis
{

  **
  ** Read the history items stored for given record id.  If span is
  ** null then all items are read, otherwise the span's inclusive
  ** start/exclusive end are used, but we always include the previous
  ** item before span and next two items after the span.
  **
  ** Options:
  **   - 'limit': if specified this caps the total number of items read
  **   - 'clipFuture': perform clipping of any data after current time
  **   - 'forecast': append forecast items
  **   - 'forecastOnly': read only forecast items
  **
  abstract Void read(Ref id, Span? span, Dict? opts, |HisItem| f)

  **
  ** Write history items to the given record id.  The items must have
  ** have a matching timezone, value kind, and unit (or be unitless).
  ** Before writing the timestamps are normalized to 1sec or 1ms precision;
  ** items with duplicate normalized timestamps are removed.  If there is
  ** existing history data with a given timestamp then the new data overwrites
  ** the current value, or if the new item's value is `haystack::Remove.val`
  ** then that item is removed.
  **
  ** The 'clear' and 'clearAll' options may be used clear a batch of
  ** exisiting items from the database.  These options may be used in
  ** conjunction with new items to write - in which case the clear is
  ** performed first on existing data, and then the new data items
  ** are written.
  **
  ** Options:
  **   - 'clear': Span for existing items to clear (inclusive start/exclusive end)
  **   - 'clearAll': marker to remove all existing items
  **   - 'noWarn': marker to suppress warnings
  **   - 'forecast': replace forecast items
  **
  abstract FolioFuture write(Ref id, HisItem[] items, Dict? opts := null)

}



