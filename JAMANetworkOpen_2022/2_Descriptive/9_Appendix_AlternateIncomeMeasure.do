/*******************************************************************************
* Title: Check: how many in our sample do we lose if we look at income from one month before preg?
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
global apcd "$head\raw\20.59_BU_Continuity_of_Medicaid\Medical_Claims_Header"
global apcdline "$head\raw\20.59_BU_Continuity_of_Medicaid\Medical_Claims_Line"
global sarah "$head\Sarah\Sarah Datasets"
global working "$head\Alex\Hoagland_WorkingData\Paper2"
global output "$head\Alex\Hoagland_Output\4.HealthOutcomesPaper"
********************************************************************************


***** 1. Begin with the delivery data set, merge in income file
use "$working/RestrictedSample_20210929.dta", clear
keep member_composite_id dob 
duplicates drop
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


***** 3. Identify income from first month before pregnancy 
// look at full year prior to pregnancy if missing first month 

drop if elig_effect_strt >= dob-275 // Ignore incomes that start less than 9 months before delivery
drop if elig_end_dt <= dob - 275 - 365
	// Drop all eligibilities that end more than a year prior to pregnancy 
	
*** Flag all income measures where eligibility is measured in month prior to pregnancy 
gen firstmonth = (inrange(elig_effect_strt, dob-275-31, dob-275))
bysort member_c dob: egen hasinc = max(firstmonth) // flag for IDing income
gen hasinc_month = 1 if hasinc == 1 // flag # of months we needed to ID income
drop if hasinc == 1 & firstmonth == 0 // drop all unnecessary incomes for this group

*** If not, take latest income assessment for pregnancy 
bysort member_c dob (elig_effect_strt): keep if _n == _N
replace hasinc_month = round((dob-275-elig_effect_strt)/31) if hasinc_month != 1
drop if hasinc_month > 13
drop if (dob-275-elig_effect_strt) > 365

*** Collapse to counts 
collapse (max) hasinc (mean) hasinc_month, by(member_composite_id dob) fast
********************************************************************************


***** 4 Merge in to main data and assess 
merge 1:1 member_c dob using "$working/RestrictedSample_20210929.dta", keep(2 3) nogenerate
replace hasinc = 0 if missing(hasinc)
fre hasinc // 13.9% of women in our sample have income one month before pregnancy 
ttest hasinc, by(group) unequal // 14% of the Medicaid sample and 10% of the commercial sample 
gen broad = !missing(hasinc_month)
fre broad // 58.8% can be identified within a year of pregnancy starting
ttest broad, by(group) unequal // 59.3% of Medicaid sample and 41.1% of commercial sample 
********************************************************************************
