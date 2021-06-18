//
// Copyright (c) 2011, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   20 Jan 2011  Andy Frank   Creation
//   03 Feb 2012  Brian Frank  Beef up tests for new functionality
//

using haystack

@Js
class DateSpanTest : Test
{

//////////////////////////////////////////////////////////////////////////
// Day
//////////////////////////////////////////////////////////////////////////

  Void testDay()
  {
    s := DateSpan()
    verifySpan(s, Date.today, Date.today, DateSpan.day, Date.today.toStr)
    verifyEq(s,    DateSpan())
    verifyEq(s,    DateSpan(Date.today))
    verifyNotEq(s, DateSpan(Date.today-1day))
    verifyEq(s.numDays, 1)

    d := Date(2010, Month.may, 4)
    s = DateSpan(d)
    verifySpan(s, d, d, DateSpan.day, "2010-05-04")
    verifyEq(s, DateSpan(d))
    verifyEq(s.numDays, 1)

    d = Date(2020, Month.jan, 5)
    s = DateSpan(d, DateSpan.day)
    verifySpan(s, d, d, DateSpan.day, "2020-01-05")
    verifyEq(s,    DateSpan(d))
    verifyNotEq(s, DateSpan())
    verifyEq(s.numDays, 1)
  }

//////////////////////////////////////////////////////////////////////////
// Week
//////////////////////////////////////////////////////////////////////////

  Void testWeek()
  {
    d := Date(2010, Month.nov, 7)
    s := DateSpan(d, DateSpan.week)
    verifySpan(s, d, Date(2010, Month.nov, 13), DateSpan.week, "2010-11-07..2010-11-13")
    verifyEq(s.numDays, 7)

    s = DateSpan.makeWeek(d)
    verifySpan(s, d, Date(2010, Month.nov, 13), DateSpan.week, "2010-11-07..2010-11-13")
    verifyEq(s,    DateSpan.makeWeek(d))
    verifyNotEq(s, DateSpan.makeWeek(Date(2011, Month.nov,13)))
    verifyEq(s.numDays, 7)

    s = DateSpan.makeWeek(Date(2010, Month.nov, 8))
    verifySpan(s, d, Date(2010, Month.nov, 13), DateSpan.week, "2010-11-07..2010-11-13")
    verifyEq(s.numDays, 7)

    s = DateSpan.makeWeek(Date(2010, Month.nov, 13))
    verifySpan(s, d, Date(2010, Month.nov, 13), DateSpan.week, "2010-11-07..2010-11-13")
    verifyEq(s.numDays, 7)
  }

//////////////////////////////////////////////////////////////////////////
// Month
//////////////////////////////////////////////////////////////////////////

  Void testMonth()
  {
    d := Date(2010, Month.oct, 1)
    s := DateSpan(d, DateSpan.month)
    verifySpan(s, d, Date(2010, Month.oct, 31), DateSpan.month, "2010-10")
    verifyEq(s.numDays, 31)

    s = DateSpan.makeMonth(2010, Month.oct)
    verifySpan(s, d, Date(2010, Month.oct, 31), DateSpan.month, "2010-10")
    verifyEq(s,    DateSpan.makeMonth(2010, Month.oct))
    verifyNotEq(s, DateSpan.makeMonth(2011, Month.feb))
    verifyEq(s.numDays, 31)

    s = DateSpan(Date(2010, Month.oct, 2), DateSpan.month)
    verifySpan(s, d, Date(2010, Month.oct, 31), DateSpan.month, "2010-10")
    verifyEq(s.numDays, 31)

    s = DateSpan(Date(2010, Month.oct, 31), DateSpan.month)
    verifySpan(s, d, Date(2010, Month.oct, 31), DateSpan.month, "2010-10")
    verifyEq(s.numDays, 31)

    verifyEq(DateSpan.makeMonth(2010, Month.sep).numDays, 30)
    verifyEq(DateSpan.makeMonth(2010, Month.feb).numDays, 28)
  }

//////////////////////////////////////////////////////////////////////////
// Quarter
//////////////////////////////////////////////////////////////////////////

  Void testQuarter()
  {
    d := Date(2016, Month.feb, 3)
    s := DateSpan(d, DateSpan.quarter)
    verifySpan(s, Date(2016, Month.jan, 1), Date(2016, Month.mar, 31), DateSpan.quarter, "2016-01-01..2016-03-31")

    s = s.prev
    verifySpan(s, Date(2015, Month.oct, 1), Date(2015, Month.dec, 31), DateSpan.quarter, "2015-10-01..2015-12-31")

    s = s.prev
    verifySpan(s, Date(2015, Month.jul, 1), Date(2015, Month.sep, 30), DateSpan.quarter, "2015-07-01..2015-09-30")

    s = DateSpan(Date(2014, Month.jun, 7), DateSpan.quarter)
    verifySpan(s, Date(2014, Month.apr, 1), Date(2014, Month.jun, 30), DateSpan.quarter, "2014-04-01..2014-06-30")

    s = DateSpan(Date(2014, Month.dec, 2), DateSpan.quarter)
    verifySpan(s, Date(2014, Month.oct, 1), Date(2014, Month.dec, 31), DateSpan.quarter, "2014-10-01..2014-12-31")

    s = s.next
    verifySpan(s, Date(2015, Month.jan, 1), Date(2015, Month.mar, 31), DateSpan.quarter, "2015-01-01..2015-03-31")

    s = s.next
    verifySpan(s, Date(2015, Month.apr, 1), Date(2015, Month.jun, 30), DateSpan.quarter, "2015-04-01..2015-06-30")
  }

//////////////////////////////////////////////////////////////////////////
// Year
//////////////////////////////////////////////////////////////////////////

  Void testYear()
  {
    d := Date(2010, Month.jan, 1)
    s := DateSpan(d, DateSpan.year)
    verifySpan(s, d, Date(2010, Month.dec, 31), DateSpan.year, "2010")
    verifyEq(s.numDays, 365)

    s = DateSpan.makeYear(2010)
    verifySpan(s, d, Date(2010, Month.dec, 31), DateSpan.year, "2010")
    verifyEq(s,    DateSpan.makeYear(2010))
    verifyNotEq(s, DateSpan.makeYear(20110))
    verifyEq(s.numDays, 365)

    s = DateSpan(Date(2010, Month.jan, 2), DateSpan.year)
    verifySpan(s, d, Date(2010, Month.dec, 31), DateSpan.year, "2010")
    verifyEq(s.numDays, 365)

    s = DateSpan(Date(2010, Month.jan, 31), DateSpan.year)
    verifySpan(s, d, Date(2010, Month.dec, 31), DateSpan.year, "2010")
    verifyEq(s.numDays, 365)

    s = DateSpan(Date(2010, Month.aug, 15), DateSpan.year)
    verifySpan(s, d, Date(2010, Month.dec, 31), DateSpan.year, "2010")
    verifyEq(s.numDays, 365)

    s = DateSpan(Date(2010, Month.dec, 31), DateSpan.year)
    verifySpan(s, d, Date(2010, Month.dec, 31), DateSpan.year, "2010")
    verifyEq(s.numDays, 365)
  }

//////////////////////////////////////////////////////////////////////////
// Range
//////////////////////////////////////////////////////////////////////////

  Void testRange()
  {
    a := Date(2010, Month.jan, 1)
    b := Date(2010, Month.jan, 1)
    s := DateSpan(a, b)
    verifySpan(s, a, b, DateSpan.range, "2010-01-01..2010-01-01")
    verifyEq(s.numDays, 1)

    a = Date(2010, Month.jan, 6)
    b = Date(2010, Month.may, 17)
    s = DateSpan(a, b)
    verifySpan(s, a, b, DateSpan.range, "2010-01-06..2010-05-17")
    verifyEq(s.numDays, 132)

    a = Date(2010, Month.jan, 1)
    b = Date(2010, Month.dec, 31)
    s = DateSpan(a, b)
    verifySpan(s, a, b, DateSpan.range, "2010-01-01..2010-12-31")
    verifyEq(s.numDays, 365)

    a = Date(2011, Month.dec, 31)
    b = Date(2012, Month.jan, 3)
    s = DateSpan(a, Number(4f, Unit("day")))
    verifySpan(s, a, b, DateSpan.range, "2011-12-31..2012-01-03")
    verifyEq(s.numDays, 4)

    a = Date(2012, Month.feb, 28)
    b = Date(2012, Month.feb, 29)
    s = DateSpan(a, 2day)
    verifySpan(s, a, b, DateSpan.range, "2012-02-28..2012-02-29")
    verifyEq(s.numDays, 2)

    verifyErr(ArgErr#) { x := DateSpan(a, 4sec) }
    verifyErr(ArgErr#) { x := DateSpan(a, Number(4f)) }
    verifyErr(ArgErr#) { x := DateSpan(a, Number(4f, Unit("week"))) }
    verifyErr(ArgErr#) { x := DateSpan(a, this) }
  }

  private Void verifySpan(DateSpan s, Date start, Date end, Str per, Str axon)
  {
    verifyEq(s.start,  start)
    verifyEq(s.end,    end)
    verifyEq(s.period, per)
    verifyEq(s.toCode, axon)

    acc := Date[,]
    s.eachDay { acc.add(it) }
    verifyEq(acc.first, start)
    verifyEq(acc.last,  end)
    verifyEq(acc.size,  s.numDays)

    x := s + 1day
    verifyEq(x.start,  s.start + 1day)
    verifyEq(x.end,    s.end + 1day)
    verifyEq(x.period, DateSpan.range)
    verifyEq(x.numDays, s.numDays)

    x = s - 2day
    verifyEq(x.start, s.start - 2day)
    verifyEq(x.end,   s.end - 2day)
    verifyEq(x.period, DateSpan.range)
    verifyEq(x.numDays, s.numDays)
  }

//////////////////////////////////////////////////////////////////////////
// Relative
//////////////////////////////////////////////////////////////////////////

  Void testRelative()
  {
    // calculate all days we'll use for thisX, pastX, lastX
    today := Date.today
    year  := today.year
    month := today.month
    yesterday := today - 1day
    sun := today; while (sun.weekday != Weekday.sun) sun = sun - 1day
    lastMonEnd := today.firstOfMonth-1day
    pastYear := Date(today.year-1, today.month, today.day)

    // calculate quarter dates
    qsm := today.month; while (qsm.ordinal % 3 != 0) qsm = qsm.decrement  // start month
    qem := qsm.increment.increment // end month
    qs := Date(year, qsm, 1) // this quarter start date
    qe := Date(year, qem, qem.numDays(year)) // this quarter end date
    lqs := qs.month == Month.jan ? Date(year-1, Month.oct, 1) : Date(year, qs.month.decrement.decrement.decrement, 1) // last quarter start date
    lqem := lqs.month.increment.increment // last quarter end month
    lqe := Date(lqs.year, lqem, lqem.numDays(lqs.year))  // last quarter end date

    // thisWeek, thisMonth, thisQuarter, thisYear
    verifySpan(DateSpan.yesterday, yesterday, yesterday, "day", yesterday.toStr)
    verifySpan(DateSpan.thisWeek,  sun, sun+6day, "week", "${sun}..${sun+6day}")
    verifySpan(DateSpan.thisMonth, Date(year, month, 1),  Date(year, month, month.numDays(year)), "month", today.toLocale("YYYY-MM"))
    verifySpan(DateSpan.thisQuarter, qs, qe, "quarter", "${qs}..${qe}")
    verifySpan(DateSpan.thisYear,  Date(year, Month.jan, 1), Date(today.year, Month.dec, 31), "year", today.toLocale("YYYY"))

    // pastWeek, pastMonth, pastYear
    verifySpan(DateSpan.pastWeek,  today-7day,   today, "range", "${today-7day}..${today}")
    verifySpan(DateSpan.pastMonth, today-30day,  today, "range", "${today-30day}..${today}")
    verifySpan(DateSpan.pastYear,  pastYear,     today, "range", "${pastYear}..${today}")

    // lastWeek, lastMonth, lastYear
    verifySpan(DateSpan.lastWeek, sun-7day, sun-1day, "week", "${sun-7day}..${sun-1day}")
    verifySpan(DateSpan.lastMonth, lastMonEnd.firstOfMonth, lastMonEnd, "month", lastMonEnd.toLocale("YYYY-MM"))
    verifySpan(DateSpan.lastQuarter, lqs, lqe, "quarter", "${lqs}..${lqe}")
    verifySpan(DateSpan.lastYear, Date(year-1, Month.jan, 1), Date(today.year-1, Month.dec, 31), "year", (today.year-1).toStr)


    // weeks with mon start of week
    Locale("es").use
    {
      mon := sun+1day
      verifySpan(DateSpan.thisWeek,  mon, mon+6day, "week", "${mon}..${mon+6day}")
      verifySpan(DateSpan.lastWeek,  mon-7day, mon-1day, "week", "${mon-7day}..${mon-1day}")
    }
  }

//////////////////////////////////////////////////////////////////////////
// Iterators
//////////////////////////////////////////////////////////////////////////

  Void testEach()
  {
    list := Date[,]
    DateSpan.makeMonth(2010, Month.jan).eachDay |d| { list.add(d) }
    verifyEq(list.size, 31)
    verifyEq(list[0], Date(2010, Month.jan, 1))
    verifyEq(list[3], Date(2010, Month.jan, 4))
    verifyEq(list.last, Date(2010, Month.jan, 31))

    list.clear
    DateSpan(Date(2010, Month.mar, 4)).eachDay |d| { list.add(d) }
    verifyEq(list.size, 1)
    verifyEq(list.first, Date(2010, Month.mar, 4))
  }

//////////////////////////////////////////////////////////////////////////
// Prev/Nex
//////////////////////////////////////////////////////////////////////////

  Void testPrevNext()
  {
    s := DateSpan(Date(2010, Month.oct, 12))
    p := DateSpan(Date(2010, Month.oct, 11))
    verifyEq(s.prev, p)
    verifyEq(p.next, s)
    verifyEq(s.prev.toCode, "2010-10-11")
    verifyEq(p.next.toCode, "2010-10-12")

    s = DateSpan.makeWeek(Date(2010, Month.nov, 7))
    p = DateSpan.makeWeek(Date(2010, Month.nov, 1))
    verifyEq(s.prev, p)
    verifyEq(p.next, s)
    verifyEq(s.prev.toCode, "2010-10-31..2010-11-06")
    verifyEq(p.next.toCode, "2010-11-07..2010-11-13")

    s = DateSpan.makeMonth(2010, Month.nov)
    p = DateSpan.makeMonth(2010, Month.oct)
    verifyEq(s.prev, p)
    verifyEq(p.next, s)
    verifyEq(s.prev.toCode, "2010-10")
    verifyEq(p.next.toCode, "2010-11")

    s = DateSpan.makeMonth(2011, Month.jan)
    p = DateSpan.makeMonth(2010, Month.dec)
    verifyEq(s.prev, p)
    verifyEq(p.next, s)
    verifyEq(s.prev.toCode, "2010-12")
    verifyEq(p.next.toCode, "2011-01")

    s = DateSpan(Date(2010, Month.mar, 5), Date(2010, Month.apr, 7))
    p = DateSpan(Date(2010, Month.mar, 4), Date(2010, Month.apr, 6))
    verifyEq(s.prev, p)
    verifyEq(p.next, s)
    verifyEq(s.prev.toCode, "2010-03-04..2010-04-06")
    verifyEq(p.next.toCode, "2010-03-05..2010-04-07")
  }

//////////////////////////////////////////////////////////////////////////
// Dis
//////////////////////////////////////////////////////////////////////////

  Void testDis()
  {
    verifyEq(DateSpan().dis, "Today")
    verifyEq(DateSpan(Date.today-1day).dis, "$<haystack::yesterday>")
    d := Date(2010, Month.nov, 6)
    verifyEq(DateSpan(d).dis, "Sat 6-Nov-2010")
    verifyEq(DateSpan.makeWeek(d).dis, "Week of 31-Oct-2010")
    verifyEq(DateSpan.makeMonth(2010, Month.nov).dis, "Nov-2010")
    verifyEq(DateSpan.makeYear(2010).dis, "2010")
    s := DateSpan(Date(2010, Month.mar, 5), Date(2010, Month.apr, 7))
    verifyEq(s.dis, "5-Mar-10..7-Apr-10")

    verifyEq(DateSpan().dis(true), Date.today.toLocale("WWW D-MMM-YYYY"))
    verifyEq(DateSpan(d).dis(true), "Sat 6-Nov-2010")
  }

//////////////////////////////////////////////////////////////////////////
// Serialization
//////////////////////////////////////////////////////////////////////////

  Void testSerialization()
  {
    verifySer(DateSpan(), "$Date.today,day")
    verifySer(DateSpan(Date(2010, Month.nov, 6)), "2010-11-06,day")

    verifySer(DateSpan.makeWeek(Date(2010, Month.nov, 7)), "2010-11-07,week")

    verifySer(DateSpan.makeMonth(2010, Month.nov), "2010-11-01,month")

    verifySer(DateSpan.makeYear(2010), "2010-01-01,year")

    s := DateSpan(Date(2010, Month.mar, 5), Date(2010, Month.apr, 7))
    verifySer(s, "2010-03-05,2010-04-07")

    verifyEq(DateSpan.fromStr("today"), DateSpan.today)
    verifyEq(DateSpan.fromStr("yesterday"), DateSpan.yesterday)
    verifyEq(DateSpan.fromStr("thisWeek"), DateSpan.thisWeek)
    verifyEq(DateSpan.fromStr("thisMonth"), DateSpan.thisMonth)
    verifyEq(DateSpan.fromStr("pastWeek"), DateSpan.pastWeek)
    verifyEq(DateSpan.fromStr("pastMonth"), DateSpan.pastMonth)
    verifyEq(DateSpan.fromStr("lastWeek"), DateSpan.lastWeek)
    verifyEq(DateSpan.fromStr("lastMonth"), DateSpan.lastMonth)
  }

  private Void verifySer(DateSpan span, Str text)
  {
    verifyEq(span.toStr, text)
    verifyEq(DateSpan.fromStr(text), span)
  }

}