/*******************************************************************************
* Title: Identfy health outcomes
* Created by: Alex Hoagland
* Created on: 4/9/2021
* Last modified on: 6/7/2021
* Last modified by: Alex Hoagland

* Purpose: Identifies health outcomes for births/women in our sample.
		   
* Notes: 
		
* Key edits: 
   -  
*******************************************************************************/

***** 0. Directories & Packages 
global head "\\ad.bu.edu\bumcfiles\BUMC Projects\ColoradoAPCD"
global apcd "$head\raw\20.59_BU_Continuity_of_Medicaid\Medical_Claims_Header"
global apcdline "$head\raw\20.59_BU_Continuity_of_Medicaid\Medical_Claims_Line"
global sarah "$head\Sarah\Sarah Datasets"
global working "$head\Alex\Hoagland_WorkingData\Paper2"
global output "$head\Alex\Hoagland_Output\4.HealthOutcomesPaper"

// ssc install icd9, replace // icd-9 diagnoses
// ssc install icd9p, replace // icd-9 procedures
// ssc install icd10cm, replace // US icd-10-CM (not ICD-10-WHO) diagnoses
// ssc install icd10pcs, replace  // US icd-10 (not WHO) procedures
********************************************************************************

***** 2. Outcomes: Health costs
use "$working\HO_inprogress_20210622.dta", clear

// Identify prenatal care
gen prenatal = 0
replace prenatal = 1 if inlist(substr(principal_diagnosis_cd,1,3),"Z34", "Z36")
replace prenatal = 1 if inlist(substr(admit_diagnosis_cd,1,3),"Z34", "Z36")

// Check fraction of utilization that is pp care
gen oop = coinsurance + copay + deductible
replace oop = . if oop < 0
gen tc = oop + plan_paid 
replace tc = . if plan_paid < 0

* Correct to 2020 USD
cap gen service_year = year(new_svcstart)
foreach v of varlist oop tc { 
	replace `v' = `v' * 1.0903 if service_year == 2014
	replace `v' = `v' * 1.0890 if service_year == 2015
	replace `v' = `v' * 1.0754 if service_year == 2016
	replace `v' = `v' * 1.0530 if service_year == 2017
	replace `v' = `v' * 1.0261 if service_year == 2018
	replace `v' = `v' * 1.0123 if service_year == 2019
}
 
 // correct inflation
foreach v of varlist oop tc { 
	replace `v' = `v' / 1.0903 * (564.2/468.4) if service_year == 2014
	replace `v' = `v' / 1.0890 * (564.2/482) if service_year == 2015
	replace `v' = `v' / 1.0754 * (564.2/500.8) if service_year == 2016
	replace `v' = `v' / 1.0530 * (564.2/509) if service_year == 2017
	replace `v' = `v' / 1.0261 * (564.2/522.5) if service_year == 2018
	replace `v' = `v' / 1.0123 * (564.2/549.1) if service_year == 2019
}

// check proportion of visits that are prenatal vs all other care
// collapse to claim level 
collapse (max) prenatal (sum) tc oop, ///
	by(member_composite claim_id dob new_svcstart group) fast
	
// assume all claims of a given type on a given day are a single visit
collapse (max) prenatal (sum) tc oop , ///
	by(member_composite dob new_svcstart group) fast
	
// collapse to person level 
collapse (max) prenatal, by(member_composite dob group) fast

// merge in with data
merge 1:1 member_c dob using "$working\RestrictedSample_20210929.dta", keep(2 3) nogenerate
replace prenatal = 0 if missing(prenatal)
ttest prenatal, by(group) unequal
********************************************************************************