local lb = `1'
local enrol = `2'

* Identify start/end dates of enrollment "spells", potentially lasting longer than one record
bysort member_ dob vsid (num_elig_record): gen switch = (insurance_type != insurance_type[_n-1])
bysort member_ dob vsid (num_elig_record): replace switch = 1 if (start_dt - end_dt[_n-1] > 3) // if there is a gap in coverage, count that as a spell too
bysort member_ dob vsid (num_elig_record): replace switch = . if _n == 1
bysort member_ dob vsid: gen spell = sum(switch)
bysort member_ dob vsid spell: egen spell_st = min(start_dt)
bysort member_ dob vsid spell: egen spell_end = max(end_dt)
format spell_* %td
bysort member_ dob vsid spell: keep if _n == 1 // keep just one observation per spell

* Identify postpartum start and end dates
gen month = month(dob)+`lb'
gen year = year(dob)
replace year = year+1 if month > 12
replace month = month - 12 if month > 12
gen day = day(dob)
gen pp_s = mdy(month,day,year)
gen pp_e = dob + 365
format pp_s %td
format pp_e %td
drop year month day
drop if spell_st > pp_e | spell_end < pp_s

* Identify all enrollment covering at least a certain number of days between pp_s and pp_e
gen overlap = min(spell_end, pp_e)-max(spell_st,pp_s)+1
drop if overlap < `enrol'
replace insurance_type = "Commercial" if insurance_type == "Other"
	// not many of these
	
* If needed, drop the year 2014
if ("`3'" == "_Missing2014") {
	drop if year(pp_s) == 2014 | year(pp_e) == 2014
	drop if year(spell_st) == 2014 | year(spell_end) == 2014
	drop if year(spell_st) < 2014 & year(spell_end) > 2014
	}

* Identify coverage at individual level, plus months of enrollment
gen on_me = (insurance_type == "Medicaid")
gen on_co = (insurance_type == "Commercial")
gen on_mu = (insurance_type == "Multiple")
gen de_me = overlap if on_me == 1
gen de_co = overlap if on_co == 1
gen de_mu = overlap if on_mu == 1
	
collapse (max) on_* (sum) de_* (first) pct_fpl_month2, by(member_composite_id dob vsid) fast // each enrollee counts once
replace on_mu = 1 if on_co == 1 & on_me == 1
replace on_co = 0 if on_mu == 1
replace on_me = 0 if on_mu == 1
ereplace de_mu = rowtotal(de_me de_co) if de_me > 0 & de_co > 0
replace de_co = 0 if on_mu == 1
replace de_me = 0 if on_mu == 1

* Create graph of enrollment frequency
replace pct_fpl = round(pct_fpl)
collapse (sum) on_*, by(pct_fpl) fast
keep if pct_fpl > 0 & pct_fpl < 300

gen com = on_me + on_c
gen mul = on_me + on_c + on_mu

twoway (bar on_me pct_fpl) (rbar on_me com pct_fpl) (rbar com mul pct_fpl), /// 
		graphregion(color(white)) subtitle("Total Enrolled Lives by FPL: Enrollment Spanning `lb'-12 Months Postpartum") ///
		legend(on) legend(order(1 "Medicaid" 2 "Commercial" 3 "Multiple")) ///
		ylab(, angle(horizontal)) xtitle("Income (as % FPL)") xline(138, lpattern(dash) lcolor(red)) ///
		note("Note: Counts enrollment in any program for at least `enrol' days between `lb' and 12 months postpartum (inclusive)." ///
			"Measures income at 60 days postpartum." ///
			"Only shows enrollment for women with income in (0, 300)% FPL.")
graph export "$temp\Output\EnrollmentDistributions\EnrollmentStratified_byFPL_`lb'-12MonthsPP_`enrol'Days`3'.png", as(png) replace
