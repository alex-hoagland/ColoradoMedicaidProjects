/*******************************************************************************
* Title: Pull APCD data (and organize)
* Created by: Alex Hoagland
* Created on: 1/12/2021
* Last modified on: 
* Last modified by: Alex Hoagland

* Purpose: Pulls and organizes APCD claim data for the sample of interest. 
		   
* Notes: 
		
* Key edits: 
   -  
*******************************************************************************/

***** 0. Directories 
global raw "\\ad.bu.edu\bumcfiles\BUMC Projects\ColoradoAPCD\raw\20.59_BU_Continuity_of_Medicaid\Medical_Claims_Header"
global working "C:\Users\alcobe\Desktop\Hoagland_WorkingData"
********************************************************************************


***** 1. Load medical header
use "$raw\Medical_Claims_Header.dta", clear // takes about 10-15 minutes on the supercomputer

* Keep only the women in our sample
merge m:1 member_id using "$working\SampleMemberIDs", ///
	keep(2 3) nogenerate // note: there are 119,376 member IDs w/o any claims?
	// TODO: check if this looks different if I only use member_id or member_composite_id?
drop if missing(claim_id)

* Keep only claims 1 year before/after the birth 
egen firstbirth = rowmin(dob*)
egen lastbirth = rowmax(dob*)

gen admdate = date(admit_dt, "YMD")
gen svcdate = date(service_start_dt, "YMD")
keep if inrange(admdate, firstbirth-365, lastbirth+365) | ///
		inrange(svcdate, firstbirth-365, lastbirth+365)

compress
save "$working\sample_ClaimsHeader.dta", replace
********************************************************************************


***** 2. Once ready, merge this with the line, DX, and procs files
keep member_id firstbirth lastbirth
duplicates drop
********************************************************************************


***** 3. Check the payer of each woman at the time of delivery, and for postpartum claims?
* Keep all claims that are +/-1 days around a woman's dob
keep if inlist(admdate, dob1, dob2, dob3, dob4, dob5, dob6) | ///
		inlist(admdate-1, dob1, dob2, dob3, dob4, dob5, dob6) | ///
		inlist(admdate+1, dob1, dob2, dob3, dob4, dob5, dob6) | ///
		inlist(svcdate, dob1, dob2, dob3, dob4, dob5, dob6) | ///
		inlist(svcdate-1, dob1, dob2, dob3, dob4, dob5, dob6) | ///
		inlist(svcdate+1, dob1, dob2, dob3, dob4, dob5, dob6)
		
fre insurance_product_type_cd payer_ // 99% of these claims are paid for by Medicaid

* Now check claims that are 60-90 days after birth
use "$working\sample_ClaimsHeader.dta", clear
forvalues i = 1/6 { 
	gen start`i' = dob`i' + 60
	gen end`i' = dob`i' + 90
}
keep if inrange(admdate, start1, end1) | ///
		(inrange(admdate, start2, end2) & !missing(start2)) | ///
		(inrange(admdate, start3, end3) & !missing(start3)) | ///
		(inrange(admdate, start4, end4) & !missing(start4)) | ///
		(inrange(admdate, start5, end5) & !missing(start5)) | ///
		(inrange(admdate, start6, end6) & !missing(start6)) | ///
		inrange(svcdate, start1, end1) | ///
		(inrange(svcdate, start2, end2) & !missing(start2)) | ///
		(inrange(svcdate, start3, end3) & !missing(start3)) | ///
		(inrange(svcdate, start4, end4) & !missing(start4)) | ///
		(inrange(svcdate, start5, end5) & !missing(start5)) | ///
		(inrange(svcdate, start6, end6) & !missing(start6)) 
fre insurance_product_type_cd payer_ // 98% of these claims are paid for by Medicaid

* Now check claims that are 240-365 days after birth
use "$working\sample_ClaimsHeader.dta", clear
forvalues i = 1/6 { 
	gen start`i' = dob`i' + 240
	gen end`i' = dob`i' + 365
}
keep if inrange(admdate, start1, end1) | ///
		(inrange(admdate, start2, end2) & !missing(start2)) | ///
		(inrange(admdate, start3, end3) & !missing(start3)) | ///
		(inrange(admdate, start4, end4) & !missing(start4)) | ///
		(inrange(admdate, start5, end5) & !missing(start5)) | ///
		(inrange(admdate, start6, end6) & !missing(start6)) | ///
		inrange(svcdate, start1, end1) | ///
		(inrange(svcdate, start2, end2) & !missing(start2)) | ///
		(inrange(svcdate, start3, end3) & !missing(start3)) | ///
		(inrange(svcdate, start4, end4) & !missing(start4)) | ///
		(inrange(svcdate, start5, end5) & !missing(start5)) | ///
		(inrange(svcdate, start6, end6) & !missing(start6)) 
fre insurance_product_type_cd payer_ // 97% of these claims are paid for by Medicaid
********************************************************************************