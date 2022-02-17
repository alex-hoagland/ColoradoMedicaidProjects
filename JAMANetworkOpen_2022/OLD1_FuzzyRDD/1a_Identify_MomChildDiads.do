/*******************************************************************************
* Title: ID'ing double-use IDs
* Created by: Alex Hoagland
* Created on: 5/20/2021
* Last modified on: 
* Last modified by: Alex Hoagland

* Purpose: 
		   
* Notes: 
		
* Key edits: 
   -  
*******************************************************************************/

***** 0. Directories & Packages 
global sarah "\\ad.bu.edu\bumcfiles\BUMC Projects\ColoradoAPCD\Sarah\Sarah Datasets"
global working "\\ad.bu.edu\bumcfiles\BUMC Projects\ColoradoAPCD\Alex\Hoagland_WorkingData\Paper2"
global output "\\ad.bu.edu\bumcfiles\BUMC Projects\ColoradoAPCD\Alex\Hoagland_Output\4.HealthOutcomesPaper"
global birthrecords "\\ad.bu.edu\bumcfiles\BUMC Projects\ColoradoAPCD\Birth Records\raw"
********************************************************************************


***** 1. Merge in mom's VSID
import delimited "$birthrecords\co_match_child_1219.csv", clear
compress
save "$birthrecords\co_match_child_1219.dta", replace

import delimited "$birthrecords\co_match_mom_1219.csv", clear
keep member_composite_id dob vsid duplicateflag
bysort member_composite_id dob (vsid): gen j = _n
reshape wide vsid duplicate, i(member_ dob) j(j)
gen dob_record = daily(dob, "MDY")
drop dob
rename dob dob 

merge 1:m member_composite_id dob using "$working\FuzzyRDD.dta", keep(2 3) nogenerate
save "$working\FuzzyRDD.dta", replace
********************************************************************************


***** 2. Link moms with baby IDs 
keep member_composite dob vsid* duplicateflag*
reshape long vsid duplicateflag, i(member_composite dob) j(num_id)
drop if missing(vsid)

preserve
use "$birthrecords\co_match_child_1219.dta", clear
keep member_composite_id vsid dob duplicateflag
bysort vsid dob: gen j = _n
rename member_ babyid
reshape wide babyid duplicateflag, i(vsid dob) j(j)
gen babydup = duplicateflag1 
drop duplicateflag*
compress
save "$working\tomerge.dta", replace
restore

rename dob dob_sample
rename member_ momid
rename duplicateflag momdup
merge m:1 vsid using "$working\tomerge.dta", keep(1 3) nogenerate
rename dob dob_babyrecord
order vsid dob* momid babyid*

rm "$working\tomerge.dta"
********************************************************************************


***** 3. Organize crosswalk from mother to infant IDs
gen dob_babyrecord2 = daily(dob_babyrecord, "MDY")
drop dob_babyrecord
rename dob_babyrecord2 dob_babyrecord
format dob* %td
order vsid dob*
drop if dob_sample != dob_babyrecord 
drop dob_babyrecord
rename dob dob

gen todrop = (momid == babyid1) 
forvalues i = 1/8 { 
	replace todrop = 1 if momid == babyid`i'
}
drop if todrop == 1
drop todrop

compress
save "$working\Mother_Infant_Diads.dta", replace
********************************************************************************


***** 4. Trim sample to include only those with different baby IDs
keep momid dob
duplicates drop
 
rename momid member_composite_id
gen separateids = 1

merge 1:1 member_composite_id dob using "$working\FuzzyRDD.dta", keep(3) nogenerate
save "$working\FuzzyRDD_Limited.dta", replace
********************************************************************************


***** 5. Looking to see when baby IDs are first used in claims
use "$working\Mother_Infant_Diads.dta", clear
keep momid vsid babyid* dob 
reshape long babyid, i(momid vsid dob) j(birthid)
drop if missing(babyid)
keep babyid dob 
duplicates drop

rename babyid member_composite_id
rename dob listed_dob
********************************************************************************