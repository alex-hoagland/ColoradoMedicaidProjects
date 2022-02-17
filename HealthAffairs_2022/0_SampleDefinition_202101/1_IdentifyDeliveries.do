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
global sarah "\\ad.bu.edu\bumcfiles\BUMC Projects\ColoradoAPCD\Sarah\Sarah Datasets"
global working "C:\Users\alcobe\Desktop\Hoagland_WorkingData"

// ssc install icd9, replace // icd-9 diagnoses
// ssc install icd9p, replace // icd-9 procedures
// ssc install icd10cm, replace // US icd-10-CM (not ICD-10-WHO) diagnoses
// ssc install icd10pcs, replace  // US icd-10 (not WHO) procedures
********************************************************************************


***** 1. Load medical claims data
use "$sarah\header_line_2014on_19up_medicaid.dta", clear

icd9 clean admit_diagnosis if icd_vers_flag == 0
icd9 clean principal_diagnosis if icd_vers_flag == 0
icd10cm clean admit_diagnosis if icd_vers_flag == 1
icd10cm clean principal_diagnosis if icd_vers_flag == 1
********************************************************************************


***** 2. Identify deliveries
gen byte tokeep = 0
// delivery codes
foreach v of var admit_diagnosis principal_diagnosis {
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

// procedure codes
replace tokeep = 1 if inlist(cpt4_cd, "1960","1961","59400","59409","59410","59412","59414","59510")
replace tokeep = 1 if inlist(cpt4_cd, "59514","59515","59610","59612","59614","59618","59620","59622")

* Check delivery codes not in tokeep? 
* icd9 gen test = principal_diagnosis, range(72* 73* 74* 650* 651* V27*) 
	// this isn't everything in ICD-9, just to give a sense
* fre principal_diagnosis if test == 1 & tokeep == 0

* Limit to delivery claims
keep if tokeep == 1
********************************************************************************


***** 3. Identify (i) member IDs, (ii) delivery date, and (iii) payer at time of delivery
*** Generate delivery date: account for multiple births 
gen svcdate = mdy(service_month, service_day, service_year)
* bysort member_composite_id member_id (svcdate): gen dayspassed = svcdate[_N]-svcdate[1]

gen service_halfyear = (service_month > 6) // group into 6-month windows
sort member_composite_id member_id service_year service_halfyear
egen birth_id = group(member_composite_id member_id service_year service_halfyear)

*** Collapse to one observation per birth
sort member_composite_id member_id birth_id svcdate // so that I pick up latest payer for each birth 
collapse (max) service_year service_month service_day (last) payer_cd insurance_*, ///
	by(member_composite_id member_id birth_id) fast 
	
*** Make sure I didn't split any births
gen svcdate = mdy(service_month, service_day, service_year)
format svcdate %td
bysort member_composite_id member_id (birth_id): gen dayspassed = svcdate-svcdate[_n-1]
replace dayspassed = . if dayspassed > 270 // only trying to flag potentially split births, so ignore birth_ids that are more than 9 months removed. 
	// 1,160 have births that potentially span birth_ids with weird births, collapse
bysort member_composite_id member_id (birth_id): drop if !missing(dayspassed[_n+1])

*** Organize file
keep member_* svcdate payer_cd insurance*
rename svcdate dob
duplicates drop
drop if missing(dob) // TODO: look at why these are missing?

* Reshape (some women have multiple payers for one birth)
bysort member_composite_id dob: gen j = _n
reshape wide member_id payer_cd insurance_product_type_cd insurance_product_type_desc, ///
	i(member_composite_id dob) j(j)

compress
save "$working\APCD_MedicaidDelivery_Sample", replace
********************************************************************************