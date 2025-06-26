//
// Copyright (c) 2016, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   1 Feb 2016  Brian Frank  Creation
//

using haystack

**
** SpanTest
**
@Js
class SpanTest : HaystackTest
{

//////////////////////////////////////////////////////////////////////////
// Abs
//////////////////////////////////////////////////////////////////////////

  Void testAbs()
  {
    verifyAbs(ts("2016-01-03 2:34:56.789"), ts("2016-01-04 16:44:00"), "none", "3-Jan-2016 2:34am..4-Jan-2016 4:44pm")
    verifyAbs(ts("2016-01-03 2:34:56.789"), ts("2016-01-03 2:34:56.789"), "none", "3-Jan-2016 2:34am..3-Jan-2016 2:34am")
    verifyAbs(ts("2018-07-18T21:53:00+02:00 Paris"), ts("2018-07-18T22:53:00+02:00 Paris"), "none", "18-Jul-2018 9:53pm..18-Jul-2018 10:53pm", TimeZone("Paris"))

    verifyAbs(ts("2016-01-03"), ts("2016-01-04"), "day",    "3-Jan-2016")
    verifyAbs(ts("2016-01-03"), ts("2016-01-05"), "dates",  "3-Jan-2016..4-Jan-2016")
    verifyAbs(ts("2013-07-07"), ts("2013-07-14"), "week",   "Week of 7-Jul-2013")
    verifyAbs(ts("2013-07-01"), ts("2013-08-01"), "month",  "Jul-2013")
    verifyAbs(ts("2013-01-01"), ts("2013-04-01"), "quarter", "Q1 2013")
    verifyAbs(ts("2013-04-01"), ts("2013-07-01"), "quarter", "Q2 2013")
    verifyAbs(ts("2013-07-01"), ts("2013-10-01"), "quarter", "Q3 2013")
    verifyAbs(ts("2013-10-01"), ts("2014-01-01"), "quarter", "Q4 2013")
    verifyAbs(ts("2013-01-01"), ts("2014-01-01"), "year",    "2013")
    verifyAbs(ts("2013-01-01"), ts("2015-01-01"), "days",    "1-Jan-2013..31-Dec-2014")

    // zero day at midnight
    s := verifyAbs(ts("2025-06-25"), ts("2025-06-25"), "day", "25-Jun-2025")
    dates := Date?[,]
    s.eachDay |d| { dates.add(d) }
    verifyEq(dates, [Date("2025-06-25")])

    // day + timezone
    s = Span(Date("2023-05-15"), TimeZone("Chicago"))
    verifyEq(s.start, DateTime("2023-05-15T00:00:00-05:00 Chicago"))
    verifyEq(s.end, DateTime("2023-05-16T00:00:00-05:00 Chicago"))

    verifyErr(ArgErr#) { x := Span(ts("2016-01-03"), ts("2016-01-03")-1ms) }
    verifyErr(ArgErr#) { x := Span(ts("2016-01-04"), ts("2016-01-03")) }
    verifyErr(ArgErr#) { x := Span(DateTime.now - 1day, DateTime.nowUtc) }
  }

  Span verifyAbs(DateTime start, DateTime end, Str align, Str dis, TimeZone tz := this.tz)
  {
    span := Span(start, end)
    verifySame(span.mode, SpanMode.abs)
    verifyEq(span.start, start)
    verifyEq(span.start.tz, tz)
    verifyEq(span.end, end)
    verifyEq(span.end.tz, tz)
    verifyEq(span.dis, dis)
    verifyEq(Span.fromStr(span.toStr, tz), span)

    verifyEq(span.alignsToDates,   align != "none")
    verifyEq(span.alignsToDay,     align == "day")
    verifyEq(span.alignsToWeek,    align == "week")
    verifyEq(span.alignsToMonth,   align == "month")
    verifyEq(span.alignsToQuarter, align == "quarter")
    verifyEq(span.alignsToYear,    align == "year")

    return span
  }

//////////////////////////////////////////////////////////////////////////
// Rel
//////////////////////////////////////////////////////////////////////////

  Void testRelative()
  {
    this.tz = TimeZone.utc
    t1 := DateTime("2016-02-05T04:05:06Z UTC")
    t2 := DateTime("2015-12-28T04:05:06Z UTC")
    t3 := DateTime("2016-01-01T04:05:06Z UTC")
    t4 := DateTime("2016-03-07T04:05:06Z UTC")
    t5 := DateTime("2016-04-01T04:05:06Z UTC")
    t6 := DateTime("2016-06-30T04:05:06Z UTC")
    t7 := DateTime("2016-07-01T04:05:06Z UTC")
    t8 := DateTime("2016-07-01T04:05:06Z UTC")
    t9 := DateTime("2016-10-31T04:05:06Z UTC")
    tA := DateTime("2016-11-01T04:05:06Z UTC")
    rel := TimeZone.rel

    // today/yesterday
    verifyRel(SpanMode.today, t1,     ts("2016-02-05"), ts("2016-02-06"))
    verifyRel(SpanMode.yesterday, t1, ts("2016-02-04"), ts("2016-02-05"))

    // week (sunday)
    verifyRel(SpanMode.thisWeek, t1,  ts("2016-01-31"), ts("2016-02-07"))
    verifyRel(SpanMode.thisWeek, t2,  ts("2015-12-27"), ts("2016-01-03"))
    verifyRel(SpanMode.thisWeek, t3,  ts("2015-12-27"), ts("2016-01-03"))
    verifyRel(SpanMode.lastWeek, t1,  ts("2016-01-24"), ts("2016-01-31"))
    verifyRel(SpanMode.lastWeek, t2,  ts("2015-12-20"), ts("2015-12-27"))
    verifyRel(SpanMode.lastWeek, t3,  ts("2015-12-20"), ts("2015-12-27"))

    // week (monday)
    Locale("es").use
    {
      verifyRel(SpanMode.thisWeek, t1,  ts("2016-02-01"), ts("2016-02-08"))
      verifyRel(SpanMode.thisWeek, t2,  ts("2015-12-28"), ts("2016-01-04"))
      verifyRel(SpanMode.thisWeek, t3,  ts("2015-12-28"), ts("2016-01-04"))
      verifyRel(SpanMode.lastWeek, t1,  ts("2016-01-25"), ts("2016-02-01"))
      verifyRel(SpanMode.lastWeek, t2,  ts("2015-12-21"), ts("2015-12-28"))
      verifyRel(SpanMode.lastWeek, t3,  ts("2015-12-21"), ts("2015-12-28"))
    }

    // month
    verifyRel(SpanMode.thisMonth, t1,  ts("2016-02-01"), ts("2016-03-01"))
    verifyRel(SpanMode.thisMonth, t2,  ts("2015-12-01"), ts("2016-01-01"))
    verifyRel(SpanMode.thisMonth, t3,  ts("2016-01-01"), ts("2016-02-01"))
    verifyRel(SpanMode.thisMonth, t4,  ts("2016-03-01"), ts("2016-04-01"))
    verifyRel(SpanMode.lastMonth, t1,  ts("2016-01-01"), ts("2016-02-01"))
    verifyRel(SpanMode.lastMonth, t2,  ts("2015-11-01"), ts("2015-12-01"))
    verifyRel(SpanMode.lastMonth, t3,  ts("2015-12-01"), ts("2016-01-01"))
    verifyRel(SpanMode.lastMonth, t4,  ts("2016-02-01"), ts("2016-03-01"))

    // quarter
    verifyRel(SpanMode.thisQuarter, t1,  ts("2016-01-01"), ts("2016-04-01"))
    verifyRel(SpanMode.thisQuarter, t4,  ts("2016-01-01"), ts("2016-04-01"))
    verifyRel(SpanMode.thisQuarter, t5,  ts("2016-04-01"), ts("2016-07-01"))
    verifyRel(SpanMode.thisQuarter, t6,  ts("2016-04-01"), ts("2016-07-01"))
    verifyRel(SpanMode.thisQuarter, t7,  ts("2016-07-01"), ts("2016-10-01"))
    verifyRel(SpanMode.thisQuarter, t8,  ts("2016-07-01"), ts("2016-10-01"))
    verifyRel(SpanMode.thisQuarter, t9,  ts("2016-10-01"), ts("2017-01-01"))
    verifyRel(SpanMode.thisQuarter, tA,  ts("2016-10-01"), ts("2017-01-01"))
    verifyRel(SpanMode.lastQuarter, t1,  ts("2015-10-01"), ts("2016-01-01"))
    verifyRel(SpanMode.lastQuarter, t4,  ts("2015-10-01"), ts("2016-01-01"))
    verifyRel(SpanMode.lastQuarter, t5,  ts("2016-01-01"), ts("2016-04-01"))
    verifyRel(SpanMode.lastQuarter, t6,  ts("2016-01-01"), ts("2016-04-01"))
    verifyRel(SpanMode.lastQuarter, t7,  ts("2016-04-01"), ts("2016-07-01"))
    verifyRel(SpanMode.lastQuarter, t8,  ts("2016-04-01"), ts("2016-07-01"))
    verifyRel(SpanMode.lastQuarter, t9,  ts("2016-07-01"), ts("2016-10-01"))
    verifyRel(SpanMode.lastQuarter, tA,  ts("2016-07-01"), ts("2016-10-01"))

    // year
    verifyRel(SpanMode.thisYear, t1,  ts("2016-01-01"), ts("2017-01-01"))
    verifyRel(SpanMode.thisYear, tA,  ts("2016-01-01"), ts("2017-01-01"))
    verifyRel(SpanMode.lastYear, t1,  ts("2015-01-01"), ts("2016-01-01"))
    verifyRel(SpanMode.lastYear, tA,  ts("2015-01-01"), ts("2016-01-01"))
  }

  Void verifyRel(SpanMode mode, DateTime ts, DateTime start, DateTime end)
  {
    span := Span.doMakeRel(mode, ts)

    verifySame(span.mode, mode)
    verifyEq(span.start, start)
    verifyEq(span.start.time, Time.defVal)
    verifyEq(span.start.tz, TimeZone.utc)
    verifyEq(span.end, end)
    verifyEq(span.end.time, Time.defVal)
    verifyEq(span.end.tz, TimeZone.utc)
    verifyEq(span.toStr, span.mode.name)
    verifyEq(span.dis, mode.name.toDisplayName)
    verifyEq(Span(span.mode.name, ts.tz), span)
    verifyEq(span, Span.fromStr(span.toStr))

    verifyRelAlign(span, true, mode)
    verifyRelAlign(Span(start, end),      true,  mode)
    verifyRelAlign(Span(start, end+2day), true,  SpanMode.abs)
    verifyRelAlign(Span(start-2day, end), true,  SpanMode.abs)
    verifyRelAlign(Span(start+1ms, end),  false, SpanMode.abs)
    verifyRelAlign(Span(start, end-1ms),  false, SpanMode.abs)

  }

  Void verifyRelAlign(Span span, Bool alignsToDates, SpanMode mode)
  {
    verifyEq(span.alignsToDates,   alignsToDates)
    verifyEq(span.alignsToDay,     mode == SpanMode.today || mode == SpanMode.yesterday)
    verifyEq(span.alignsToWeek,    mode.name.contains("Week"))
    verifyEq(span.alignsToMonth,   mode.name.contains("Month"))
    verifyEq(span.alignsToQuarter, mode.name.contains("Quarter"))
    verifyEq(span.alignsToYear,    mode.name.contains("Year"))
  }

//////////////////////////////////////////////////////////////////////////
// SpanModePeriod
//////////////////////////////////////////////////////////////////////////

 Void testSpanModePeriod()
 {
    verifySame(SpanMode.today.period,       SpanModePeriod.day)
    verifySame(SpanMode.yesterday.period,   SpanModePeriod.day)

    verifySame(SpanMode.lastWeek.period,    SpanModePeriod.week)
    verifySame(SpanMode.thisWeek.period,    SpanModePeriod.week)
    verifySame(SpanMode.pastWeek.period,    SpanModePeriod.week)

    verifySame(SpanMode.thisMonth.period,   SpanModePeriod.month)
    verifySame(SpanMode.lastMonth.period,   SpanModePeriod.month)
    verifySame(SpanMode.pastMonth.period,   SpanModePeriod.month)

    verifySame(SpanMode.thisQuarter.period, SpanModePeriod.quarter)
    verifySame(SpanMode.lastQuarter.period, SpanModePeriod.quarter)
    verifySame(SpanMode.pastQuarter.period, SpanModePeriod.quarter)

    verifySame(SpanMode.thisYear.period,    SpanModePeriod.year)
    verifySame(SpanMode.lastYear.period,    SpanModePeriod.year)
    verifySame(SpanMode.pastYear.period,    SpanModePeriod.year)
 }

//////////////////////////////////////////////////////////////////////////
// Contains
//////////////////////////////////////////////////////////////////////////

  Void testContains()
  {
    // x and y are same absolute time
    x := DateTime("2016-02-24T09:44:03-05:00 New_York")
    y := DateTime("2016-02-24T08:44:03-06:00 Chicago")

    e := x
    s := e - 2min
    span := Span(s, e)

    verifyContains(span, s, e)
    verifyContains(span, x-2min, x)
    verifyContains(span, y-2min, y)
  }

  Void verifyContains(Span span, DateTime s, DateTime e)
  {
    verifyEq(span.contains(s-1ns), false)
    verifyEq(span.contains(s),     true)
    verifyEq(span.contains(s+1ns), true)
    verifyEq(span.contains(e-1ns), true)
    verifyEq(span.contains(e),     false)
    verifyEq(span.contains(e+1ns), false)
  }

//////////////////////////////////////////////////////////////////////////
// ToDateSpan
//////////////////////////////////////////////////////////////////////////

  Void testToDateSpan()
  {
    verifyToDateSpan(Span.today, DateSpan.today)
    verifyToDateSpan(Span("2017-09-01,2017-09-05"), DateSpan("2017-09-01,2017-09-04"))
    verifyToDateSpan(Span("2017-09-01,2017-09-30"), DateSpan("2017-09-01,2017-09-29"))
    verifyToDateSpan(Span("2017-09-03,2017-09-10"), DateSpan.makeWeek(Date("2017-09-03")))
    verifyToDateSpan(Span("2017-09-01,2017-10-01"), DateSpan.makeMonth(2017, Month.sep))
    verifyToDateSpan(Span("2017-01-01,2018-01-01"), DateSpan.makeYear(2017))

    tsA := Date("2017-08-30").toDateTime(Time(2, 00))
    tsB := Date("2017-09-02").toDateTime(Time(2, 00))
    verifyToDateSpan(Span(tsA, tsB), DateSpan("2017-08-30,2017-09-02"))
  }

  Void verifyToDateSpan(Span span, DateSpan expected)
  {
    actual := span.toDateSpan
    // echo("-- $span | $span.dis | $actual ?= $expected " + actual.toSpan(TimeZone.cur))
    verifyEq(actual, expected)
    if (span.mode.isAbs && span.start.hour == 0) verifyEq(actual.toSpan(TimeZone.cur), span)
  }

//////////////////////////////////////////////////////////////////////////
// Next/Prev
//////////////////////////////////////////////////////////////////////////

  Void testNextPrev()
  {
    today := Date.today
    sun := Date.today; while (sun.weekday != Weekday.sun) sun = sun - 1day
    first := today.firstOfMonth
    lastFirst := first.minus(1day).firstOfMonth
    lastLastFirst := lastFirst.minus(1day).firstOfMonth
    y := today.year

    // day, relative
    verifyNextPrev(
      [span(today-4day),
       span(today-3day),
       span(today-2day),
       span(SpanMode.yesterday),
       span(SpanMode.today)])

    // day, absolute
    verifyNextPrev(
      [span(today-4day),
       span(today-3day),
       span(today-2day),
       span(today-1day),
       span(today)])

    // week, relative
    verifyNextPrev(
      [span(sun-28day, sun-21day),
       span(sun-21day, sun-14day),
       span(sun-14day, sun-7day),
       span(SpanMode.lastWeek),
       span(SpanMode.thisWeek)])

    // week, abs
    verifyNextPrev(
      [span(sun-28day, sun-21day),
       span(sun-21day, sun-14day),
       span(sun-14day, sun-7day),
       span(sun-7day, sun),
       span(sun, sun+7day),
       span(sun+7day, sun+14day),])

    // week, abs
    verifyNextPrev(
      [span(d("2015-12-27"), d("2016-01-03")),
       span(d("2016-01-03"), d("2016-01-10")),
       span(d("2016-01-10"), d("2016-01-17")),
       span(d("2016-01-17"), d("2016-01-24")),
       span(d("2016-01-24"), d("2016-01-31")),
       span(d("2016-01-31"), d("2016-02-07")),
       span(d("2016-02-07"), d("2016-02-14"))])

    // month, relative
    verifyNextPrev(
      [span(lastLastFirst, lastFirst),
       span(SpanMode.lastMonth),
       span(SpanMode.thisMonth)])

    // month, abs
    verifyNextPrev(
      [span(lastLastFirst, lastFirst),
       span(lastFirst, first),
       span(first, first.lastOfMonth+1day)])

    // month, abs
    verifyNextPrev(
      [span(d("2015-11-01"), d("2015-12-01")),
       span(d("2015-12-01"), d("2016-01-01")),
       span(d("2016-01-01"), d("2016-02-01")),
       span(d("2016-02-01"), d("2016-03-01"))])

    // quarter, relative
    verifyNextPrev(
      [span(SpanMode.lastQuarter),
       span(SpanMode.thisQuarter)])

    // quarter, abs
    verifyNextPrev(
      [span(d("2015-10-01"), d("2016-01-01")),
       span(d("2016-01-01"), d("2016-04-01")),
       span(d("2016-04-01"), d("2016-07-01")),
       span(d("2016-07-01"), d("2016-10-01")),
       span(d("2016-10-01"), d("2017-01-01")),
       span(d("2017-01-01"), d("2017-04-01"))])

    // year, relative
    verifyNextPrev(
      [span(d("${y-2}-01-01"), d("${y-1}-01-01")),
       span(SpanMode.lastYear),
       span(SpanMode.thisYear)])

    // year, abs
    verifyNextPrev(
      [span(d("2013-01-01"), d("2014-01-01")),
       span(d("2014-01-01"), d("2015-01-01")),
       span(d("2015-01-01"), d("2016-01-01")),
       span(d("2016-01-01"), d("2017-01-01")),
       span(d("2017-01-01"), d("2018-01-01"))])

    // aligmnent to dates
    verifyNextPrev(
      [span(d("2016-02-24"), d("2016-02-28")),
       span(d("2016-02-28"), d("2016-03-03")),
       span(d("2016-03-03"), d("2016-03-07")),
       span(d("2016-03-07"), d("2016-03-11"))])

    // aligmnent to hour
    verifyNextPrev(
      [Span(ts("2016-02-28 23:00:00"), ts("2016-02-29 0:00:00")),
       Span(ts("2016-02-29 0:00:00"),  ts("2016-02-29 1:00:00")),
       Span(ts("2016-02-29 1:00:00"),  ts("2016-02-29 2:00:00")),
       Span(ts("2016-02-29 2:00:00"),  ts("2016-02-29 3:00:00")),
       Span(ts("2016-02-29 3:00:00"),  ts("2016-02-29 4:00:00"))])
   }

  Void verifyNextPrev(Span[] spans)
  {
    // previous
    for (i:=spans.size-1; i>=1; --i)
    {
      verifyEq(spans[i].prev, spans[i-1])
    }

    // don't text next on relatives
    rel := spans.any |s| { s.mode.isRel }
    if (rel) return
    for (i:=0; i<spans.size-1; ++i)
    {
      verifyEq(spans[i].next, spans[i+1])
    }
  }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  TimeZone tz := TimeZone.cur

  Span span(Obj? startOrMode, Date? end := null)
  {
    if (startOrMode is SpanMode) return Span((SpanMode)startOrMode, tz)
    start := (Date)startOrMode
    if (end == null) end = start + 1day
    return Span(start.midnight(tz), end.midnight(tz))
  }

  Date d(Str d)
  {
    Date.fromStr(d)
  }

  DateTime ts(Str d)
  {
    if (d.contains("T") && d.contains(" "))
      return DateTime.fromStr(d)
    if (d.contains(" "))
      return DateTime.fromLocale(d, "YYYY-MM-DD h:mm:ss.FFF", tz)
    else
      return Date.fromStr(d).midnight(tz)
  }
}

