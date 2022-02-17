/*******************************************************************************
* Title: Identifying baby procedures on mother's ID
* Created by: Alex Hoagland
* Created on: 5/24/2021
* Last modified on: 
* Last modified by: Alex Hoagland

* Purpose: Identifies claims that should be attributed to an infant but are associated
	with a mother's ID. Helps to identify those to drop from main sample. 
		   
* Notes: Included claims are: 
	1. Delivery codes for infants, not mothers
	2. Well-child visits
	3. Other inpatient procedures for infants (hearing tests, circumcision, etc.)
		
* Key edits: 
   -  
*******************************************************************************/

***** 0. Directories & Packages 
global sarah "\\ad.bu.edu\bumcfiles\BUMC Projects\ColoradoAPCD\Sarah\Sarah Datasets"
global working "\\ad.bu.edu\bumcfiles\BUMC Projects\ColoradoAPCD\Alex\Hoagland_WorkingData\Paper2"
global output "\\ad.bu.edu\bumcfiles\BUMC Projects\ColoradoAPCD\Alex\Hoagland_Output\4.HealthOutcomesPaper"
********************************************************************************


***** 1. Keep associated claims
use "$working\momids_1yearclaims.dta", clear
gen tokeep = 0 

*** 1. Delivery codes
replace tokeep = 1 if substr(admit_diagnosis_cd,1,3) == "Z38" | ///
	substr(principal_diagnosis_cd,1,3) == "Z38"
	
	// to do: add procedures to all

*** 2. Well-child visits
replace tokeep = 1 if inlist(admit_diagnosis_cd,"V2031","V2032","V202","V700","Z0000","Z0001","Z00110","Z00111","Z00129") 
replace tokeep = 1 if inlist(principal_diagnosis_cd,"V2031","V2032","V202","V700","Z0000","Z0001","Z00110","Z00111","Z00129") 

*** 3. Inpatient procedures for infants
replace tokeep = 1 if inlist(admit_diagnosis_cd, "V773", "Z13228","V200","V201","V202","V700","V7232","V7231", "V72311") | inlist(admit_diagnosis_cd, "V7262","V7651","Z761","Z762","Z00129","Z0000","Z0001","Z01411","Z0142") | inlist(admit_diagnosis_cd,"Z01419","Z1211")
replace tokeep = 1 if inlist(principal_diagnosis_cd, "V773", "Z13228","V200","V201","V202","V700","V7232","V7231", "V72311") | inlist(principal_diagnosis_cd, "V7262","V7651","Z761","Z762","Z00129","Z0000","Z0001","Z01411","Z0142") | inlist(principal_diagnosis_cd,"Z01419","Z1211")

keep if tokeep == 1
********************************************************************************


***** 2. Keep associated mom IDs (to drop)
keep member_c dob 
duplicates drop

merge 1:1 member_composite_id dob using "$working\FuzzyRDD_Limited_2", keep(2) nogenerate
compress
save "$working\FuzzyRDD_Limited_3", replace
********************************************************************************