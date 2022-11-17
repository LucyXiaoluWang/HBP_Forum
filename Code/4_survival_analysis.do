/*Code for the regression results in Chapter XX Table 3 


used dataset: hbp_forum_wide_survival_oneQ
obtained in 05_dataset_construction_survival
regressing the solution time on the following variables using Cox-Proportional Hazard model
and Time-to-Event analysis:
	- indicator HBP-platform relevant
	- % replies containing code
	- % replies by females
	- % replies by HBP-affiliated users
	- % replies by senior users
	- % replies by admin
	- # countries
	- indicator variables on characteristics of the initial post
	- categorical variable on the topic category	
	including year fixed effects and robust standard errors

The results are directly exported to a word document.
*/

use hbp_forum_wide_survival_oneQ, clear

* generate the time difference in days between the date of the initial question and the 
* first solution
gen time_diff=day_sol_1-date_earl_cor
* to avoid solving time of 0 if the solution was given on the same day, we add 1 day to each time-difference
* if the initial post received an answer at all (status==1)
li time_diff status day_sol_1 date_earl if day_sol_1==date_earl_cor
replace time_diff=1+time_diff if status==1

* setting the parameters for the survival analysis
stset time_diff status


*---- Regressions 

* Column 1
stcox i.i_hbpplatform ib2.status_cum p_code p_female  p_userhbp  p_senior n_ctry i.y, vce(robust)
 outreg2 using "$RESULTS\Regression_survival.doc", replace eform  /// 
	keep(i.i_hbpplatform ib2.status_cum p_code p_female  p_userhbp  p_senior n_ctry ) /// 
	label  /// 
	nocons addtext(Year FE, YES)

* Column 2
stcox i.i_hbpplatform ib2.status_cum  i.poster_code i.poster_hbp i.poster_female i.poster_senior i.y, vce(robust)
 outreg2 using "$RESULTS\Regression_survival.doc", append eform  /// 
	keep(i.i_hbpplatform ib2.status_cum  i.poster_code i.poster_hbp i.poster_female i.poster_senior) /// 
	label nocons addtext(Year FE, YES)

* Column 3	
stcox i.i_hbpplatform p_code p_female  p_userhbp  p_senior ib2.status_cum  n_ctry i.poster_code i.poster_hbp i.poster_female i.poster_senior i.y, vce(robust)
outreg2 using "$RESULTS\Regression_survival.doc", append eform  /// 
	keep(i.i_hbpplatform ib2.status_cum p_code p_female  p_userhbp  p_senior n_ctry i.poster_code i.poster_hbp i.poster_female i.poster_senior ) /// 
	label nocons addtext(Year FE, YES)

* column 4	
stcox ib2.status_cum p_code p_female  p_userhbp  p_senior n_ctry i.poster_code i.poster_hbp i.poster_female i.poster_senior  i.cat_all i.y, vce(robust)
 outreg2 using "$RESULTS\Regression_survival.doc", append eform  /// 
	keep(ib2.status_cum p_code p_female  p_userhbp  p_senior n_ctry i.poster_code i.poster_hbp i.poster_female i.poster_senior i.cat_all) /// 
	label 	nocons addtext(Year FE, YES)
	
* Column 5 Time-to-event

stpm2 i.i_hbpplatform ib2.status_cum p_code p_female  p_userhbp  p_senior n_ctry i.poster_code i.poster_hbp i.poster_female i.poster_senior i.y, scale(hazard)	df(2) eform 
outreg2 using "$RESULTS\Regression_survival.doc", append eform  /// 
	keep(i.i_hbpplatform ib2.status_cum p_code p_female  p_userhbp  p_senior n_ctry i.poster_code i.poster_hbp i.poster_female i.poster_senior ) /// 
	label nocons addtext(Year FE, YES)  
	
