/*******************************************************************************
* Title: Identfy deliveries
* Created by: Alex Hoagland
* Created on: 1/21/2021
* Last modified on: 
* Last modified by: Alex Hoagland

* Purpose: Identifies women in CO APCD who had deliveries paid for by Medicaid 
	during sample period. 
		   
* Notes: 
		
* Key edits: 
   -  
*******************************************************************************/

***** 0. Directories & Packages 
global raw "\\ad.bu.edu\bumcfiles\BUMC Projects\ColoradoAPCD\raw\20.59_BU_Continuity_of_Medicaid"
global working "\\ad.bu.edu\bumcfiles\BUMC Projects\ColoradoAPCD\Alex\Hoagland_WorkingData\CheckInfants"

// ssc install icd9, replace // icd-9 diagnoses
// ssc install icd9p, replace // icd-9 procedures
// ssc install icd10cm, replace // US icd-10-CM (not ICD-10-WHO) diagnoses
// ssc install icd10pcs, replace  // US icd-10 (not WHO) procedures
********************************************************************************


***** 1. Load medical claims data
use "$raw\Medical_Claims_Dx\Medical_Claims_Dx.dta", clear

//icd9 clean admit_diagnosis if icd_vers_flag == 0
//icd9 clean principal_diagnosis if icd_vers_flag == 0
//icd10cm clean admit_diagnosis if icd_vers_flag == 1
//icd10cm clean principal_diagnosis if icd_vers_flag == 1
********************************************************************************


***** 2. Identify deliveries
gen byte tokeep = 0
// delivery codes
foreach v of var dx_cd {
	replace tokeep = 1 if inlist(`v', "0073", "7301", "0074", "0741", "0742")
	replace tokeep = 1 if inlist(`v', "0744", "0749", "7499", "0650", "0651", "0651", "65101", "65103")
	replace tokeep = 1 if inlist(`v', "6511", "65111", "65113", "6512", "65121", "65123", "6513", "65131")
	replace tokeep = 1 if inlist(`v', "65133", "6514", "65141", "6515", "65151", "65153", "6516")
	replace tokeep = 1 if inlist(`v', "65161", "65163", "6517", "65171", "65173", "6518", "65181", "65183")
	replace tokeep = 1 if inlist(`v', "6519", "65191", "65193", "V270", "V271", "V272", "V273", "V274")
	replace tokeep = 1 if inlist(`v', "V275", "V276", "V277", "V279", "V3000", "V3001", "V311", "V312")
	replace tokeep = 1 if inlist(`v', "V321", "V322", "V331", "V332", "V341", "V342", "V351", "V352")
	replace tokeep = 1 if inlist(`v', "V361", "V362", "V371", "V372", "O80", "O800", "O801", "O808")
	replace tokeep = 1 if inlist(`v', "O809", "O82", "O820", "O821", "O822", "O828", "O829", "Z37")
	replace tokeep = 1 if inlist(`v', "Z37", "Z370", "Z371", "Z372", "Z373", "Z374", "Z375", "Z3750")
	replace tokeep = 1 if inlist(`v', "Z3751", "Z3752", "Z3753", "Z3754", "Z3759", "Z376", "Z3760", "Z3761")
	replace tokeep = 1 if inlist(`v', "Z3762", "Z3763", "Z3764", "Z3769", "Z377", "Z379", "Z38", "Z380")
	replace tokeep = 1 if inlist(`v', "Z3800", "Z381", "Z382", "Z383", "Z3830", "Z3831", "Z384", "Z385")
	replace tokeep = 1 if inlist(`v', "Z386", "Z3861", "Z3862", "Z3863", "Z3864", "Z3865", "Z3866", "Z3868")
	replace tokeep = 1 if inlist(`v', "Z3869", "Z387", "Z388")
}
* Limit to delivery claims
keep if tokeep == 1
keep claim_id
duplicates drop
save "$working\tomerge_claims.dta", replace

* Now merge with claims and keep infants
use "$working\tomerge_claims.dta", clear
merge 1:m claim_id using "$raw\Medical_Claims_Header\Medical_Claims_Header.dta", keep(3) nogenerate
gen year = substr(service_start_dt, 1, 4)
destring year, replace
// keep if member_age == 0
keep member*id year member_age service_start_dt // need to match this with vsid at some point
drop member_id
collapse (min) service_start_dt, by(member*id year member_age) 
duplicates drop // 191,295 IDs overall matched to 187,252 member_composite_ids
save "$working\allbabies_claims.dta", replace

* Now merge this with birth records -- use VSID to link moms and babies, look for only one 
use "\\ad.bu.edu\bumcfiles\BUMC Projects\ColoradoAPCD\Birth Records\raw\co_match_child_1219.dta", clear
rename yr year
merge m:1 member_composite_id year using "$working\allbabies_claims.dta" // pull in ages at time of service
save "$working\merged_birthcert_claims.dta", replace

* Keep only Medicaid-financed births
use "$working\merged_birthcert_claims.dta", clear
keep member_composite_id dob 
duplicates drop
bysort member_ (dob): gen i = _n
rename dob dob_
reshape wide dob, i(member_) j(i)
merge 1:m member_composite_id using "$raw/Member_to_Member_Composite_Crosswalk/Member_to_Member_Composite_Crosswalk.dta", keep(3) nogenerate // pulls all member_IDs



merge 1:m member_composite_id member_id "$raw/Member_Eligibility/Member_Eligibility.dta" // now use this file to summarize match quality
********************************************************************************
