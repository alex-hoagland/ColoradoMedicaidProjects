/*******************************************************************************
* Title: 2d: Identfy health outcomes (FRAGMENT: used to call from other files)
* Created by: Alex Hoagland
* Created on: 1/13/2022
* Last modified on: 
* Last modified by: Alex Hoagland

* Purpose: Identifies health outcomes for births/women in our sample.
		   
* Notes: 
		
* Key edits: 
   -  
*******************************************************************************/


merge m:1 claim_id using "$working\tomerge_allpreventivedx.dta", nogenerate
	// merge in preventive dx's using 2a_ID_Preventive.do
replace any = 0 if missing(any)

merge m:1 claim_id using "$working\tomerge_allpcpdx.dta", nogenerate
replace anypcp = 0 if missing(anypcp)

replace place_of_service_cd = "" if strpos(place_of_service_cd , "U")
destring place_of_service_cd, gen(pos)

cap drop ho* 

* Identifying IP hospitalizations (progressively imposing restrictions)
// gen crit1 = (claim_type_cd == 3) // Inpatient claim type
// bysort member_id member_composite_id claim_id: ereplace crit1 = max(crit1)
gen crit2 = (!missing(new_discharge) & !missing(new_admit) & new_discharge > new_admit) // need to be kept >= 24 hours
bysort member_id member_composite_id claim_id: ereplace crit2 = max(crit2)
gen crit3 = (inlist(pos,21,51,56,61) | ///
		substr(revenue_cd, 1, 2) == "01" | inlist(substr(revenue_cd,1,3),"020","021")) // appropriate POS or revenue codes
bysort member_id dob member_composite_id claim_id new_admit: ereplace crit3 = max(crit3)
gen ho_ip = (crit2 == 1 & crit3 == 1)
label var ho_ip "Health outcome: Any inpatient stay"

* Any ED use 
gen ho_ed = (er_flag == "Y" | place_of_s == "23")
replace ho_ed = 0 if revenue_cd != "0981" & substr(revenue_cd,1,3) != "045"
bysort member_composite_id dob member_id claim_id new_admit: ereplace ho_ed = max(ho_ed) 
label var ho_ed "Health outcome: Any ED Use"

* Identify all outpatient visits
// all non-IP and non-ED visits
gen ho_op = (ho_ed == 0 & ho_ip == 0)
destring place_of_service_cd, replace
replace ho_op = 0 if place_of_s > 73 & !missing(place_of_s) // Exclude labs and other POS's, keep unassigned
bysort member_composite_id dob member_id claim_id new_svcstart: ereplace ho_op = max(ho_op) 
label var ho_op "Health outcome: Any outpatient visit"

* Identify all preventive visits based on dx/cpt codes
gen ho_prev = 0 
destring cpt4_cd , gen(test) force
replace ho_prev = 1 if inrange(test, 99381, 99397) & !missing(test)
replace ho_prev = 1 if anyprev == 1| /// 
	inlist(principal, "Z0000", "Z0001", "Z01411", "Z01419", "Z391", "Z392") | ///
	inlist(principal,"V700", "V7231", "V241", "V242") | ///
	inlist(admit_diag, "Z0000", "Z0001", "Z01411", "Z01419", "Z391", "Z392") | ///
	inlist(admit_diag,"V700", "V7231", "V241", "V242")
drop test

replace ho_prev = 0 if ho_op != 1
bysort member_composite_id dob member_id claim_id new_svcstart: ereplace ho_prev = max(ho_prev)

* Identify general primary care visits
gen ho_pcp = anypcp 
replace ho_pcp = 1 if inlist(substr(principal_diagnosis, 1, 3), "Z00", "Z01", "Z39", "V70", "V72", "V24")
replace ho_pcp = 1 if ho_prev == 1
replace ho_pcp = 0 if ho_op != 1
bysort member_composite_id dob member_id claim_id new_svcstart: ereplace ho_pcp = max(ho_pcp) 
label var ho_pcp "Health outcome: General Primary Care Visit"
********************************************************************************