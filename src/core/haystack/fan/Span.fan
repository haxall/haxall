//
// Copyright (c) 2016, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   1 Feb 2016  Brian Frank  Reboot DateSpan
//

**
** Span models a range of time using an inclusive starting
** timestamp and exclusive ending timestamp.
**
@Js
const final class Span
{
  ** Decode from string format:
  **   - relative `SpanMode` mode name
  **   - absolute single date: 'YYYY-MM-DD'
  **   - absolute date span: 'YYYY-MM-DD,YYYY-MM-DD'
  **   - absolute date time span: 'YYYY-MM-DDThh:mm:ss.FFF zzzz,YYYY-MM-DDThh:mm:ss.FFF zzzz'
  static new fromStr(Str str, TimeZone tz := TimeZone.cur, Bool checked := true)
  {
    try
    {
      rel := SpanMode.fromStr(str, false)
      if (rel != null && rel.isRel) return makeRel(rel, tz)

      toks := str.split(',')
      if (toks.size == 1)
      {
        d := Date.fromStr(toks[0])
        return makeDates(SpanMode.abs, d, d.plus(1day), tz)
      }

      if (toks.size != 2) throw Err()
      return makeDateTimes(SpanMode.abs, parseDateTime(toks[0], tz), parseDateTime(toks[1], tz))
    }
    catch (Err e) {}
    if (checked) throw ParseErr(str)
    return null
  }

  private static DateTime parseDateTime(Str s, TimeZone tz)
  {
    // TODO in 3.0.16 we started encoding the tz into non-aligned start,end;
    // but for the backward compatible window we can't expect that all
    // strings contain a timezone (once we get to 3.0.18+ or so, we can assume
    // that all Spans are encoded correctly with a tz)
    if (s.size == 10) return Date.fromStr(s).midnight(tz)
    if (s.contains(" ")) return DateTime.fromStr(s)
    return DateTime.fromLocale(s, "YYYY-MM-DD'T'hh:mm:ss.FFF", tz)
  }

  ** Make an absolute span for two date times which must
  ** be defined in the 'Rel' timezone
  static new makeAbs(DateTime start, DateTime end)
  {
    if (start.tz !== end.tz) throw ArgErr("Mismatched tz: $start.tz != $end.tz")
    if (start > end) throw ArgErr("start > end")
    return makeDateTimes(SpanMode.abs, start, end)
  }

  ** Make an absolute span for the given date
  static new makeDate(Date date, TimeZone tz := TimeZone.cur)
  {
    return makeDateTimes(SpanMode.abs, date.midnight(tz), date.plus(1day).midnight(tz))
  }

  ** Make a relative span for given mode using current time
  ** and current locale for starting weekday
  static new makeRel(SpanMode mode, TimeZone tz := TimeZone.cur)
  {
    doMakeRel(mode, DateTime.now.toTimeZone(tz))
  }

  ** Convenience for 'Span(SpanMode.today)'
  static Span today(TimeZone tz := TimeZone.cur) { Span(SpanMode.today, tz) }

  ** Default value is `today` for current timezone
  @NoDoc static Span defVal() { today(TimeZone.cur) }

  @NoDoc static new doMakeRel(SpanMode mode, DateTime now)
  {
    if (mode.isAbs) throw ArgErr("Mode not relative: $mode")
    today := now.date
    tz := now.tz
    switch (mode)
    {
      case SpanMode.today:
        return makeDates(mode, today, today.plus(1day), tz)

      case SpanMode.yesterday:
        return makeDates(mode, today.minus(1day), today, tz)

      case SpanMode.thisWeek:
        sow := Weekday.localeStartOfWeek
        start := today
        while (start.weekday !== sow) start = start - 1day
        return makeDates(mode, start, start.plus(7day), tz)

      case SpanMode.lastWeek:
        sow := Weekday.localeStartOfWeek
        start := today
        while (start.weekday !== sow) start = start - 1day
        start = start - 7day
        return makeDates(mode, start, start.plus(7day), tz)

      case SpanMode.pastWeek:
        return makeDates(mode, today - 7day, today, tz)

      case SpanMode.thisMonth:
        first := today.firstOfMonth
        return makeDates(mode, first, first.lastOfMonth.plus(1day), tz)

      case SpanMode.lastMonth:
        first := today.firstOfMonth.minus(1day).firstOfMonth
        return makeDates(mode, first, first.lastOfMonth.plus(1day), tz)

      case SpanMode.pastMonth:
        return makeDates(mode, today - 28day, today, tz)

      case SpanMode.thisQuarter:
        return makeDates(mode, toQuarterStart(today), toQuarterEnd(today), tz)

      case SpanMode.lastQuarter:
        lastQuarter := toQuarterStart(today).minus(1day)
        return makeDates(mode, toQuarterStart(lastQuarter), toQuarterEnd(lastQuarter), tz)

      case SpanMode.pastQuarter:
        return makeDates(mode, today - 90day, today, tz)

      case SpanMode.thisYear:
        return makeDates(mode, Date(today.year, Month.jan, 1),  Date(today.year+1, Month.jan, 1), tz)

      case SpanMode.lastYear:
        return makeDates(mode, Date(today.year-1, Month.jan, 1),  Date(today.year, Month.jan, 1), tz)

      case SpanMode.pastYear:
        return makeDates(mode, today - 365day, today, tz)

      default: throw Err("TODO: $mode")
    }
  }

  private static Date toQuarterStart(Date d)
  {
    switch (d.month.ordinal / 3)
    {
      case 0: return Date(d.year, Month.jan, 1)
      case 1: return Date(d.year, Month.apr, 1)
      case 2: return Date(d.year, Month.jul, 1)
      case 3: return Date(d.year, Month.oct, 1)
      default: throw Err(d.toStr)
    }
  }

  private static Date toQuarterEnd(Date d)
  {
    switch (d.month.ordinal / 3)
    {
      case 0: return Date(d.year, Month.apr, 1)
      case 1: return Date(d.year, Month.jul, 1)
      case 2: return Date(d.year, Month.oct, 1)
      case 3: return Date(d.year+1, Month.jan, 1)
      default: throw Err(d.toStr)
    }
  }

  private new makeDates(SpanMode mode, Date start, Date end, TimeZone tz)
  {
    this.mode = mode
    this.start = start.midnight(tz)
    this.end = end.midnight(tz)
    this.alignsToDates = true
  }

  private new makeDateTimes(SpanMode mode, DateTime start, DateTime end)
  {
    this.mode = mode
    this.start = start
    this.end = end
    this.alignsToDates = start.time == Time.defVal && end.time == Time.defVal
  }

//////////////////////////////////////////////////////////////////////////
// Identity
//////////////////////////////////////////////////////////////////////////

  ** Absolute or relative mode
  const SpanMode mode

  ** Inclusive starting timestamp
  const DateTime start

  ** Exclusive ending timestamp
  const DateTime end

  ** Timezone for this span
  TimeZone tz() { start.tz }

  ** Hash code is based on mode only for relative, start/end for abs
  override Int hash()
  {
    mode.isRel ? mode.hash : start.hash.xor(end.hash)
  }

  ** Equality is based on mode only for relative, start/end for abs
  override Bool equals(Obj? obj)
  {
    that := obj as Span
    if (that == null) return false
    if (this.mode != that.mode) return false
    if (mode.isRel) return true
    return this.start == that.start && this.end == that.end
  }

  ** Encode to string, see `fromStr`
  override Str toStr()
  {
    if (mode.isRel) return mode.name
    if (alignsToDates)
    {
      if (alignsToDay) return start.date.toStr
      return "$start.date,$end.date"
    }
    return "$start,$end"
  }

  ** For 'format' handling using '->toLocale'
  @NoDoc Str toLocale() { dis }

  ** Display string for current locale
  Str dis()
  {
    try
    {
      // if not aligned to dates, use full date time
      if (!alignsToDates)
        return start.toLocale("$<span.dateTime>") + ".." + end.toLocale("$<span.dateTime>")

      // handle relative
      if (mode.isRel) return mode.dis

      // handle alignments
      if (alignsToDay)     return start.toLocale("$<span.date>")
      if (alignsToWeek)    return "$<weekOf> " + start.toLocale("$<span.date>")
      if (alignsToMonth)   return start.toLocale("$<span.month>")
      if (alignsToQuarter) return typeof.pod.locale("quarter$quarter") + " " + start.toLocale("$<span.year>")
      if (alignsToYear)    return start.toLocale("$<span.year>")
      return start.date.toLocale("$<span.date>") + ".." + end.date.minus(1day).toLocale("$<span.date>")
    }
    catch (Err e) return toStr
  }

  ** Convert to timezone using `sys::DateTime.toTimeZone` on both start, end
  Span toTimeZone(TimeZone tz)
  {
    if (this.tz === tz) return this
    return makeAbs(start.toTimeZone(tz), end.toTimeZone(tz))
  }

  ** Convert this span to a DateSpan attempting to use aligned dates
  DateSpan toDateSpan()
  {
    if (!alignsToDates) return DateSpan(start.date, end.date)
    if (alignsToDay)    return DateSpan(start.date, DateSpan.day)
    if (alignsToWeek)   return DateSpan(start.date, DateSpan.week)
    if (alignsToMonth)  return DateSpan(start.date, DateSpan.month)
    if (alignsToYear)   return DateSpan(start.date, DateSpan.year)
    return DateSpan(start.date, end.date - 1day)
  }

  ** Iterate each day in this span.
  @NoDoc Void eachDay(|Date,Int| func)
  {
    toDateSpan.eachDay(func)
  }

  ** Return if this span contains the give timestamp with inclusive
  ** start and exclusive end.  Comparison is based on absolute ticks.
  @NoDoc Bool contains(DateTime ts)
  {
    start <= ts && ts < end
  }

  ** If this is a relative, then make copy to ensure start/end are correct
  @NoDoc This fresh()
  {
    mode.isAbs ? this : makeRel(mode, tz)
  }

  ** Return axon representation for this span.
  Str toCode() { "toSpan(${toStr.toCode})" }

//////////////////////////////////////////////////////////////////////////
// Alignment
//////////////////////////////////////////////////////////////////////////

  ** Does this span align to midnight date boundaries
  @NoDoc const Bool alignsToDates

  ** Number of whole days this span includes
  @NoDoc Int numDays()
  {
    end.date.minusDate(start.date).toDay
  }

  ** Return quarter number as 1, 2, 3, or 4
  @NoDoc Int quarter() { 1 + start.month.ordinal / 3 }

  ** Does span align to a single day
  @NoDoc Bool alignsToDay()
  {
    alignsToDates && numDays == 1
  }

  ** Does span align to a single week starting on
  ** first of week in current locale
  @NoDoc Bool alignsToWeek()
  {
    alignsToDates && start.date.weekday == Weekday.localeStartOfWeek && numDays == 7
  }

  ** Does span align to a single month starting on
  ** first of month, and ending on first day of next month
  @NoDoc Bool alignsToMonth()
  {
    if (!alignsToDates) return false
    if (start.month == Month.dec)
    {
      if (start.year + 1 != end.year) return false
      if (end.month != Month.jan) return false
    }
    else
    {
      if (start.year != end.year) return false
      if (start.month.ordinal + 1 != end.month.ordinal) return false
    }
    return start.day == 1 && end.day == 1
  }

  ** Does span align to a single month starting on
  ** first of month, and ending on last day of month
  @NoDoc Bool alignsToQuarter()
  {
    if (!alignsToDates) return false
    if (start.day != 1 || end.day != 1) return false
    if (start.month.ordinal % 3 != 0) return false
    if (start.month == Month.oct)
    {
      if (start.year + 1 != end.year) return false
      return end.month == Month.jan
    }
    else
    {
      if (start.year != end.year) return false
      return start.month.ordinal + 3 == end.month.ordinal
    }
  }

  ** Does span align to a single year
  @NoDoc Bool alignsToYear()
  {
    if (!alignsToDates) return false
    if (start.year +1 != end.year) return false
    if (start.day != 1 || end.day != 1) return false
    return start.month == Month.jan && end.month == Month.jan
  }

//////////////////////////////////////////////////////////////////////////
// Navigation
//////////////////////////////////////////////////////////////////////////

  ** Move to the previous period relative to current alignment
  @NoDoc Span prev()
  {
    switch (mode)
    {
      case SpanMode.today:       return makeRel(SpanMode.yesterday, tz)
      case SpanMode.thisWeek:    return makeRel(SpanMode.lastWeek, tz)
      case SpanMode.thisMonth:   return makeRel(SpanMode.lastMonth, tz)
      case SpanMode.thisQuarter: return makeRel(SpanMode.lastQuarter, tz)
      case SpanMode.thisYear:    return makeRel(SpanMode.lastYear, tz)
    }

    abs := SpanMode.abs
    if (alignsToDay)
    {
      return makeDates(abs, start.date-1day, end.date-1day, tz)
    }

    if (alignsToWeek)
    {
      return makeDates(abs,start.date-7day, end.date-7day, tz)
    }

    if (alignsToMonth)
    {
      monthEnd := this.start
      monthStart := monthEnd.date.minus(1day).firstOfMonth.midnight(tz)
      return makeDateTimes(abs, monthStart, monthEnd)
    }

    if (alignsToQuarter)
    {
      qEnd := this.start.date
      qStart := qEnd.month == Month.jan ?
                Date(qEnd.year-1, Month.oct, 1) :
                Date(qEnd.year, Month.vals[qEnd.month.ordinal-3], 1)
      return makeDates(abs, qStart, qEnd, tz)
    }

    if (alignsToYear)
    {
      y := start.year
      return makeDates(abs, Date(y-1, Month.jan, 1), Date(y, Month.jan, 1), tz)
    }

    if (alignsToDates)
    {
      diffDays := 1day * numDays
      return makeDates(abs, start.date-diffDays, end.date-diffDays, tz)
    }

    diffTicks := end - start
    return makeDateTimes(abs, start-diffTicks, end-diffTicks)
  }

  ** Move to the next period relative to current alignment
  @NoDoc Span next()
  {
    switch (mode)
    {
      case SpanMode.yesterday:   return makeRel(SpanMode.today, tz)
      case SpanMode.lastWeek:    return makeRel(SpanMode.thisWeek, tz)
      case SpanMode.lastMonth:   return makeRel(SpanMode.thisMonth, tz)
      case SpanMode.lastQuarter: return makeRel(SpanMode.thisQuarter, tz)
      case SpanMode.lastYear:    return makeRel(SpanMode.thisYear, tz)
    }

    abs := SpanMode.abs
    if (alignsToDay)
    {
      return makeDates(abs, start.date+1day, end.date+1day, tz)
    }

    if (alignsToWeek)
    {
      return makeDates(abs,start.date+7day, end.date+7day, tz)
    }

    if (alignsToMonth)
    {
      monthStart := this.end
      monthEnd   := monthStart.date.lastOfMonth.plus(1day).midnight(tz)
      return makeDateTimes(abs, monthStart, monthEnd)
    }

    if (alignsToQuarter)
    {
      qStart := this.end.date
      qEnd := qStart.month == Month.oct ?
                Date(qStart.year+1, Month.jan, 1) :
                Date(qStart.year, Month.vals[qStart.month.ordinal+3], 1)
      return makeDates(abs, qStart, qEnd, tz)
    }

    if (alignsToYear)
    {
      y := start.year
      return makeDates(abs, Date(y+1, Month.jan, 1), Date(y+2, Month.jan, 1), tz)
    }

    if (alignsToDates)
    {
      diffDays := 1day * numDays
      return makeDates(abs, start.date+diffDays, end.date+diffDays, tz)
    }

    diffTicks := end - start
    return makeDateTimes(abs, start+diffTicks, end+diffTicks)
  }
}

**************************************************************************
** SpanMode
**************************************************************************

**
** SpanMode enumerates relative or absolute span modes
**
@Js
enum class SpanMode
{
  abs         (0),
  today       (1),
  yesterday   (1),
  thisWeek    (2),
  lastWeek    (2),
  pastWeek    (2),
  thisMonth   (3),
  lastMonth   (3),
  pastMonth   (3),
  thisQuarter (4),
  lastQuarter (4),
  pastQuarter (4),
  thisYear    (5),
  lastYear    (5),
  pastYear    (5)

  ** Private constructor
  private new make(Int periodOrdinal)
  {
    this.periodOrdinal = periodOrdinal
  }

  ** Is this an absolute mode
  Bool isAbs() { this == abs }

  ** Is this a relative mode
  Bool isRel() { this != abs }

  ** Display name for relative period
  Str dis() { typeof.pod.locale(name) }

  ** Period for this mode: day, week, month, quarter, year
  @NoDoc SpanModePeriod period() { SpanModePeriod.vals[periodOrdinal] }
  private const Int periodOrdinal
}

**************************************************************************
** SpanModePeriod
**************************************************************************

@NoDoc @Js
enum class SpanModePeriod
{
  abs, day, week, month, quarter, year
}

