//
// Copyright (c) 2011, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   20 Jan 2011  Andy Frank   Creation
//   02 Feb 2012  Brian Frank  Merge with DateRange for server side
//

**
** DateSpan models a span of time between two dates.
**
@Js
@Serializable { simple=true }
const final class DateSpan
{

//////////////////////////////////////////////////////////////////////////
// Construction
//////////////////////////////////////////////////////////////////////////

  ** Convenience for 'make(start, DateSpan.week)'.
  static DateSpan makeWeek(Date start) { make(start, week) }

  ** Convenience for 'make(Date(year, month, 1), DateSpan.month)'.
  static DateSpan makeMonth(Int year, Month month) { make(Date(year, month, 1), DateSpan.month) }

  ** Convenience for 'make(Date(year, Month.jan, 1), DateSpan.year)'.
  static DateSpan makeYear(Int year) { make(Date(year, Month.jan, 1), DateSpan.year) }

  ** Convenience for 'make(Date.today)'.
  static DateSpan today() { make(Date.today, day) }

  ** Convenience for 'make(Date.today-1day)'.
  static DateSpan yesterday() { make(Date.today-1day, day) }

  ** Construct for this week as 'sun..sat' (uses locale start of week)
  static DateSpan thisWeek() { make(Date.today, week) }

  ** Construct for this month as '1..28-31'
  static DateSpan thisMonth() { make(Date.today, month) }

  ** Construct for this year 'Jan-1..Dec-31'
  static DateSpan thisYear() { make(Date.today, year) }

  ** Construct for last 7 days as 'today-7days..today'
  static DateSpan pastWeek()
  {
    today := Date.today
    return make(today - 7day, today)
  }

  ** Construct for last 30days 'today-30days..today'
  static DateSpan pastMonth()
  {
    today := Date.today
    return make(today-30day, today)
  }

  ** Construct for this past 'today-365days..today'
  static DateSpan pastYear()
  {
    today := Date.today
    year  := today.year - 1
    mon   := today.month
    day   := today.day.min(mon.numDays(year))
    return make(Date(year, mon, day), today)
  }

  ** Construct for week previous to this week 'sun..sat' (uses locale start of week)
  static DateSpan lastWeek()
  {
    make(Date.today-7day, week)
  }

  ** Construct for month previous to this month '1..28-31'
  static DateSpan lastMonth()
  {
    make(Date.today.firstOfMonth-1day, month)
  }

  ** Construct for year previous to this year 'Jan-1..Dec-31'
  static DateSpan lastYear()
  {
    make(Date(Date.today.year-1, Month.jan, 1), year)
  }

  **
  ** Construct a new DateSpan using a start date and period, or an
  ** explicit start date and end date. If a period of 'week', 'month',
  ** 'quarter', or 'year' is used, then the start date will be adjusted,
  ** if necessary, to the first of week, first of month, first of quarter,
  ** or first of year, respectively.  If a date is passed as end, then the
  ** period is implicitly 'range'.
  **
  new make(Date start := Date.today, Obj endOrPer := DateSpan.day)
  {
    if (endOrPer is Date)
    {
      this.start   = start
      this.end     = endOrPer
      this.period  = range
      this.numDays = (this.end - this.start).toDay + 1
    }
    else if (endOrPer is Str)
    {
      switch (endOrPer)
      {
        case day:
          this.start   = start
          this.end     = start
          this.period  = day
          this.numDays = 1

        case week:
          sow := Weekday.localeStartOfWeek
          while (start.weekday !== sow) start = start-1day
          this.start   = start
          this.end     = start + 6day
          this.period  = week
          this.numDays = 7

        case month:
          this.start   = start.firstOfMonth
          this.end     = start.lastOfMonth
          this.period  = month
          this.numDays = start.month.numDays(start.year)

        case quarter:
          this.start   = toQuarterStart(start.year, start.month)
          this.end     = toQuarterEnd(start.year, start.month)
          this.period  = quarter
          this.numDays = toQuarterNumDays(start.year, start.month)

        case year:
          this.start   = Date(start.year, Month.jan, 1)
          this.end     = Date(start.year, Month.dec, 31)
          this.period  = year
          this.numDays = DateTime.isLeapYear(start.year) ? 366 : 365

        default: throw ArgErr("Invalid period '$endOrPer'")
      }
    }
    else if (endOrPer is Duration || endOrPer is Number)
    {
      num := endOrPer as Number
      if (num != null)
      {
        if (num.unit != Number.day) throw ArgErr("DateSpan period unit must be day, not $num.unit")
        endOrPer = num.toDuration
      }
      this.start   = start
      this.end     = start + ((Duration)endOrPer - 1day)
      this.period  = range
      this.numDays = (this.end - this.start).toDay + 1
    }
    else
    {
      throw ArgErr("endOrPer must be Date, Str, Duration [$endOrPer.typeof]")
    }
  }

  private static Date toQuarterStart(Int y, Month m)
  {
    switch (m.ordinal / 3)
    {
      case 0: return Date(y, Month.jan, 1)
      case 1: return Date(y, Month.apr, 1)
      case 2: return Date(y, Month.jul, 1)
      case 3: return Date(y, Month.oct, 1)
      default: throw Err(m.name)
    }
  }

  private static Date toQuarterEnd(Int y, Month m)
  {
    switch (m.ordinal / 3)
    {
      case 0: return Date(y, Month.mar, 31)
      case 1: return Date(y, Month.jun, 30)
      case 2: return Date(y, Month.sep, 30)
      case 3: return Date(y, Month.dec, 31)
      default: throw Err(m.name)
    }
  }

  private static Int toQuarterNumDays(Int y, Month m)
  {
    switch (m.ordinal / 3)
    {
      case 0: return 31 + (DateTime.isLeapYear(y) ? 29 : 28) + 31
      case 1: return 30 + 31 + 30
      case 2: return 31 + 31 + 30
      case 3: return 31 + 30 + 31
      default: throw Err(m.name)
    }
  }

//////////////////////////////////////////////////////////////////////////
// Identity
//////////////////////////////////////////////////////////////////////////

  ** Start date for this span.
  const Date start

  ** Inclusive end date for this span.
  const Date end

  ** The period: `day`, `week`, `month`, `quarter`, `year`, or `range`.
  const Str period

  ** Get number of days in this span.
  const Int numDays

  ** Hash is based on start/end/period.
  override Int hash()
  {
    start.hash.xor(end.hash.shiftl(7)).xor(period.hash.shiftl(14))
  }

  ** Objects are equal if start, end, and period match.
  override Bool equals(Obj? obj)
  {
    that := obj as DateSpan
    if (that == null) return false
    return this.start  == that.start &&
           this.end    == that.end &&
           this.period == that.period
  }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  ** Convert this instance to a Span instance
  Span toSpan(TimeZone tz)
  {
    Span(start.midnight(tz), end.plus(1day).midnight(tz))
  }

  ** Does this span inclusively contain the given Date inclusively
  Bool contains(Date? val) { start <= val && val <= end }

  ** Shift start and end by the given number of days.
  @Operator DateSpan plus(Duration d)
  {
    make(start+d, end+d)
  }

  ** Shift start and end by the given number of days.
  @Operator DateSpan minus(Duration d)
  {
    make(start-d, end-d)
  }

//////////////////////////////////////////////////////////////////////////
// Iterators
//////////////////////////////////////////////////////////////////////////

  ** To flattened list of dates
  @NoDoc Date[] toDateList()
  {
    acc := Date[,]
    eachDay |d| { acc.add(d) }
    return acc
  }

  ** Iterate each day in this DateSpan.
  Void eachDay(|Date,Int| func)
  {
    date := start
    index := 0
    while (date <= end)
    {
      func(date, index)
      date = date + 1day
      index++
    }
  }

  ** Iterate each month in this date range as a range
  ** of first to last day in each month.
  Void eachMonth(|DateSpan| f)
  {
    Month? curMonth := null
    d := start
    while (d <= end)
    {
      if (d.month != curMonth)
      {
        curMonth = d.month
        f(makeMonth(d.year, d.month))
      }
      d += 1day
    }
  }


//////////////////////////////////////////////////////////////////////////
// Prev/Next
//////////////////////////////////////////////////////////////////////////

  **
  ** Return the previous DateSpan based on the period:
  **  - day:   previous day
  **  - week:  previous week
  **  - month: previous month
  **  - quarter:  previous quarter
  **  - year:  previous year
  **  - range: roll start/end back one day
  **
  DateSpan prev()
  {
    switch (period)
    {
      case day:
        return DateSpan(start-1day)

      case week:
        return DateSpan.makeWeek(start-7day)

      case month:
        y := start.year
        m := start.month.decrement
        if (m == Month.dec) y--
        return DateSpan.makeMonth(y, m)

      case quarter:
        return start.month == Month.jan ?
        make(Date(start.year-1, Month.oct, 1), "quarter") :
        make(Date(start.year, Month.vals[start.month.ordinal-3], 1), "quarter")

      case year:
        return DateSpan.makeYear(start.year-1)

      default:
        return DateSpan(start-1day, end-1day)
    }
  }

  **
  ** Return the next DateSpan based on the period:
  **  - day:   next day
  **  - week:  next week
  **  - month: next month
  **  - year:  next year
  **  - range: roll start/end forward one day
  **
  DateSpan next()
  {
    switch (period)
    {
      case day:
        return DateSpan(start+1day)

      case week:
        return DateSpan.makeWeek(start+7day)

      case month:
        y := start.year
        m := start.month.increment
        if (m == Month.jan) y++
        return DateSpan.makeMonth(y, m)

      case quarter:
        return start.month == Month.oct ?
          make(Date(start.year+1, Month.jan, 1), "quarter") :
         make(Date(start.year, Month.vals[start.month.ordinal+3], 1), "quarter")

      case year:
        return DateSpan.makeYear(start.year+1)

      default:
        return DateSpan(start+1day, end+1day)
    }
  }

//////////////////////////////////////////////////////////////////////////
// Serialization
//////////////////////////////////////////////////////////////////////////

  ** For 'format' handling using '->toLocale'
  @NoDoc Str toLocale() { dis }

  ** Return display name for this span.  If 'explicit' is true,
  ** display actual dates, as opposed to 'Today' or 'Yesterday'.
  Str dis(Bool explicit := false)
  {
    switch (period)
    {
      case day:
         if (!explicit)
         {
           if (start.isToday) return "$<today>"
           if (start.isYesterday) return "$<yesterday>"
         }
         return "$start.weekday.localeAbbr $start.toLocale"

      case week:  return "$<weekOf> $start.toLocale"
      case month: return start.toLocale("MMM-YYYY")
      case year:  return start.toLocale("YYYY")
      default:    return start.toLocale("D-MMM-YY") + ".." + end.toLocale("D-MMM-YY")
    }
  }

  ** Return axon representation for this span.
  Str toCode()
  {
    switch (period)
    {
      case day:   return start.toLocale("YYYY-MM-DD")
      case month: return start.toLocale("YYYY-MM")
      case year:  return start.toLocale("YYYY")
      default:    return "${start.toStr}..${end.toStr}"
    }
  }

  ** Str representation is "<start>,<end|period>".
  override Str toStr()
  {
    endOrPer := period=="range" ? end.toStr : period
    return "$start,$endOrPer"
  }

  **
  ** Construct DateSpan from Str.  This method supports
  ** parsing from the following formats:
  **   - "<start>,<period>"
  **   - "<start>,<end>"
  **   - "today", "yesterday"
  **   - "thisWeek", "thisMonth", "thisYear"
  **   - "pastWeek", "pastMonth", "pastYear"
  **   - "lastWeek", "lastMonth", "lastYear"
  **
  ** Where <start> and <end> are YYYY-MM-DD date formats and
  ** period is "day", "week", "month", or "year".
  **
  static new fromStr(Str s, Bool checked := true)
  {
    try
    {
      factory := factories[s]
      if (factory != null) return DateSpan#.method(factory).call
      parts := s.split(',')
      start := Date(parts[0])
      endOrPer := Date.fromStr(parts[1], false) ?: parts[1]
      return DateSpan(start, endOrPer)
    }
    catch (Err err)
    {
      if (!checked) return null
      throw ParseErr("Invalid DateSpan format '$s'", err)
    }
  }

  private static const Str:Str factories := Str:Str[:].setList(
  [
    "today", "yesterday",
    "thisWeek",  "lastWeek",  "pastWeek",
    "thisMonth", "lastMonth", "pastMonth",
    "thisYear",  "lastYear",  "pastYear"
  ])

//////////////////////////////////////////////////////////////////////////
// Period
//////////////////////////////////////////////////////////////////////////

  ** Convenience for period == DateSpan.day
  Bool isDay() { period == DateSpan.day }

  ** Convenience for period == DateSpan.week
  Bool isWeek() { period == DateSpan.week }

  ** Convenience for period == DateSpan.month
  Bool isMonth() { period == DateSpan.month }

  ** Convenience for period == DateSpan.quarter
  Bool isQuarter() { period == DateSpan.quarter }

  ** Convenience for period == DateSpan.year
  Bool isYear() { period == DateSpan.year }

  ** Convenience for period == DateSpan.range
  Bool isRange() { period == DateSpan.range }

  ** Constant for a day period.
  static const Str day := "day"

  ** Constant for a week period.
  static const Str week := "week"

  ** Constant for a month period.
  static const Str month := "month"

  ** Constant for a quarter period.
  static const Str quarter := "quarter"

  ** Constant for a month period.
  static const Str year := "year"

  ** Constant for an arbitrary period.
  static const Str range := "range"

}

