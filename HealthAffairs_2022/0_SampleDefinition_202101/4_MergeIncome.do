/*******************************************************************************
* Title: Merge delivery information and income file
* Created by: Alex Hoagland
* Created on: 1/26/2021
* Last modified on: 
* Last modified by: Alex Hoagland

* Purpose: Identifies merge quality of delivery information and income data

* Notes: 
		
* Key edits: 
   - 2.5.2021: assigning incomes going backwards, keep track of when income is assigned
*******************************************************************************/


***** 0. Directories & Packages 
global head "\\ad.bu.edu\bumcfiles\BUMC Projects\ColoradoAPCD"
global sarah "$head\Sarah\Sarah Datasets"
global working "$head\Alex\Hoagland_WorkingData"
global output "$head\Alex\Hoagland_Output\0.SampleDefinition"
********************************************************************************


***** 1. Begin with the delivery data set, merge in income file
use "$working\APCD_MedicaidDelivery_Sample.dta", clear
keep member_composite_id dob 
bysort member_composite_id (dob): gen j = _n
reshape wide dob, i(member_composite_id) j(j) // want one observation per member

merge 1:m member_composite_id using "$head\Planned Enrollment\prelim income data cleaning 9_10_20.dta", keep(3) nogenerate 

duplicates drop // there are duplicates in the income file
reshape long dob, i(member_composite_id age* fed* aid* elig*) j(birth_no) 
	// reshape back to one observation per birth
drop if missing(dob)

order member_ dob birth_no
sort member_ dob birth_no
********************************************************************************


***** 2. First, assessing how many births we lose because they are outside of 
*****		a Medicaid eligibility window
preserve
keep if inrange(dob,elig_effect_strt,elig_end_dt)
keep member_c dob
duplicates drop
merge 1:1 member_c dob using "$working\APCD_MedicaidDelivery_Sample.dta", ///
	keep(2) nogenerate keepusing(member_c dob)
gen todrop = 1
save "$working\tomerge.dta", replace
	// we lost 1,434 of 159,390 births (.9%). Drop these
restore

*** Dropping these .9% 
merge m:1 member_c dob using "$working\tomerge.dta", keep(1) nogenerate
drop todrop
rm "$working\tomerge.dta"
********************************************************************************


***** 3. DEPRECATED Identifying income (first pregnancy-qualifying income)
// drop if elig_end_dt < dob-275 // Ignore incomes that end more than 9 months before delivery
// drop if elig_effect_strt >= dob // Don't look at eligibilities after birth either
//
// gen inpreg = elig_effect_strt if (strpos(aid_desc, "Pregnant") | ///
// 					strpos(aid_desc, "Prenatal"))
// bysort member_ dob: ereplace inpreg = min(inpreg) 
// 	//earliest eligibility start date with pregnancy info
// gen income_pregqual = fed_pov_lvl_pc*100 if elig_effect_strt == inpreg & ///
// 	(strpos(aid_desc, "Pregnant") | strpos(aid_desc, "Prenatal"))
//
// preserve // About 88% of women in the sample have this income measure assigned.
// drop if missing(income_pregqual) 
// bysort member_composite_id dob (income_pregqual): gen test = (income_pregqual[1] != income_pregqual[_N])
// sort test member_ dob 
// 	// ~20 women have multiple preg-qualifying income measures on same day 
// restore
//
// collapse (max) income_pregqual, by(member_composite_id dob) fast 
// drop if missing(income_pregqual)
********************************************************************************


***** 3a. New income identification ("generous eligibility redetermination" method)
*** Look at income assignment as the income given at the first of the month 
*** FOLLOWING 60 days after the delivery date
*** When that is not identified, go backwards. Keep track of how far back you have to go. 
* drop if elig_end_dt < dob // clean up data

gen newdate = dob + 60
gen newmonth = month(newdate)+1
replace newdate = mdy(newmonth,1,year(newdate)) if newmonth <= 12
replace newdate = mdy(1,1,year(newdate)+1) if newmonth == 13
drop newmonth
format newdate %td
assert day(newdate) == 1 // looking at first of month only

drop if elig_effect_strt > newdate // no need to look forward right now

gen income_re = fed_pov_lvl_pc*100 if elig_effect_strt == newdate
bysort member_c dob: egen fill_no = count(income_re)
gen fill_date = 0 if fill_no > 0 & !missing(fill_no)

*** For women missing this measure, assign most recent income 
gen elapse = newdate-elig_effect_strt
bysort member_c dob: egen most_recent = min(elapse) // Closest to newdate
replace income_re = fed_pov_lvl_pc*100 if missing(income_re) & fill_no == 0 & ///
	elapse == most_recent // assigning income
replace fill_date = elapse if missing(fill_date) & !missing(income_re)

*** Fix those that have multiple incomes assigned --> check with Sarah about this
// for now, taking mean of two observations. 
drop fill_no
bysort member_c dob: egen fill_no = count(income_re)

*** Collapse and analyze
collapse (mean) income_re (max) fill_date fill_no, by(member_c dob) fast

* Income distribution
hist inc if inrange(inc,0.1,300), percent fcolor(ebblue%20) lcolor(ebblue) ///
	graphregion(color(white)) xline(138,lcolor(red)lpattern(dash)) ///
	xtitle("Assigned Income (% of FPL)") ytitle("Percent") ///
	subtitle("Distribution of Assigned Incomes")
graph export "$output\IncomeDistribution.png", as(png) replace

* Figure for how far back we have to go to fill income information
gen months = ceil(-1*fill_date/30)
gen days = -1*fill_date
hist months if months >= -12, discrete percent ///
	fcolor(ebblue%20) lcolor(ebblue) ///
	graphregion(color(white)) ///
	subtitle("Income Assignment Relative to First Month Following (DOB+60 days)") ///
	xtitle("Months Prior to the First Month Following (DOB+60 days)") ///
	xsc(r(-12(1)0)) xlab(-12(1)0) ///
	note("Note: Does not show 1.96% of records with incomes requiring more than a year lag in income data.")
graph export "$output\IncomeDistribution_AssignmentDates.png", as(png) replace

keep member_composite_id dob income_re fill_*
rename fill_no income_count
rename fill_date income_assign_date
merge 1:1 member_composite_id dob using "$working\APCD_MedicaidDelivery_Sample.dta", ///
	keep(2 3) nogenerate 
order income_*, last
	
compress
save "$working\APCD_MedicaidDelivery_Sample_WithIncome_20210205.dta", replace	
********************************************************************************
