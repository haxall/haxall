//
// Copyright (c) 2019, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   3 Aug 2019  Brian Frank  Creation
//

using haystack

**
** SourceStream is base class streams which source data
**
@NoDoc @Js
abstract class SourceStream : MStream
{
  new make() : super(null)
  {
  }

  override final Bool isSource() { true }

  override final Bool isTerminal() { false }

}

**************************************************************************
** RangeStream
**************************************************************************

@Js
internal class RangeStream : SourceStream
{
  new make(Range range) { this.range = range }

  override Str funcName() { "stream" }

  override Obj?[] funcArgs() { [range] }

  override Void onStart(Signal sig)
  {
    range.eachWhile |i|
    {
      submit(Number(i))
      return isComplete ? "break" : null
    }
  }

  private const Range range
}

**************************************************************************
** ListStream
**************************************************************************

@Js
internal class ListStream : SourceStream
{
  new make(Obj?[] list) { this.list = list }

  override Str funcName() { "stream" }

  override Obj?[] funcArgs() { [list] }

  override Void onStart(Signal sig) { submitAll(list) }

  private Obj?[] list
}


