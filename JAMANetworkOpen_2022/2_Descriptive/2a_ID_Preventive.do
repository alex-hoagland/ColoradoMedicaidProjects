/*******************************************************************************
* Title: Identfy preventive visits with multiple diagnoses
* Created by: Alex Hoagland
* Created on: 4/9/2021
* Last modified on: 9/15/2021
* Last modified by: Alex Hoagland

* Purpose: Identifies health outcomes for births/women in our sample.
		   
* Notes: 
		
* Key edits: 
   -  
*******************************************************************************/

***** 0. Directories & Packages 
global head "\\ad.bu.edu\bumcfiles\BUMC Projects\ColoradoAPCD"
global apcd "$head\raw\20.59_BU_Continuity_of_Medicaid\Medical_Claims_Header"
global apcddx "$head\raw\20.59_BU_Continuity_of_Medicaid\Medical_Claims_Dx"
global sarah "$head\Sarah\Sarah Datasets"
global working "$head\Alex\Hoagland_WorkingData\Paper2"
global output "$head\Alex\Hoagland_Output\4.HealthOutcomesPaper"
********************************************************************************


***** 1. Load medical claims data for our sample
* First, transform sample into list of member_composite_id's and DOBs to keep
use "$working\HO_inprogress_20210622.dta", clear
keep claim_id
duplicates drop

* Merge in all diagnoses to filter
merge 1:m claim_id using ///
	"$apcddx\Medical_Claims_Dx.dta", ///	
	keep(3) nogenerate
********************************************************************************


***** 2. Flag all claims with the appropriate preventive diagnosis codes
gen anyprevdx = (inlist(dx_cd, "Z0000", "Z0001", "Z01411", "Z01419", "Z391", "Z392") | ///
				inlist(dx_cd,"V700", "V7231", "V241", "V242"))
collapse (max) anyprevdx, by(claim_id) fast

compress
save "$working\tomerge_allpreventivedx.dta", replace
********************************************************************************