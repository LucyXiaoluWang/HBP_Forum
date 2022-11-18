/*Code for the regression results in Chapter XX Table 2 


used dataset: HBP_forum_postquarter_long
obtained in 04_dataset_construction_step2
regressing the # replies to a post per quarter on the following variables (post-quarter-level):
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


use HBP_forum_postquarter_long, clear
xtset id_post msg_yqu

* Column 1
regress nyqu_replies i.i_hbpplatform pyq_code pyq_female pyq_hbp pyq_senior  pyq_admin nyqu_ctry i.y, vce(robust)
outreg2 using "$RESULTS\Regression_postlevel.doc", replace  /// 
	keep(i.i_hbpplatform pyq_code pyq_female pyq_hbp pyq_senior  pyq_admin nyqu_ctry)  label  /// 
	addtext(Year FE , YES)	
	
	
* Column 2	
regress nyqu_replies i.i_hbpplatform i.poster_code i.poster_female i.poster_hbp i.poster_senior   i.y, vce(robust)
outreg2 using "$RESULTS\Regression_postlevel.doc", append  /// 
	keep(i.i_hbpplatform i.poster_code i.poster_female i.poster_hbp i.poster_senior)  ///
	label addtext(Year FE , YES)	
	
	
* Column 3
regress nyqu_replies i.i_hbpplatform pyq_code pyq_female pyq_hbp pyq_senior  pyq_admin nyqu_ctry  i.poster_code i.poster_female i.poster_hbp i.poster_senior i.y, vce(robust)
outreg2 using "$RESULTS\Regression_postlevel.doc", append  /// 
	keep(i.i_hbpplatform pyq_code pyq_female pyq_hbp pyq_senior  pyq_admin nyqu_ctry  i.poster_code i.poster_female i.poster_hbp i.poster_senior ) /// 
	label addtext(Year FE & Robust Standard Errors, YES)	
	
	
* Column 4
regress nyqu_replies pyq_code pyq_female pyq_hbp pyq_senior  pyq_admin nyqu_ctry  i.poster_code i.poster_female i.poster_hbp i.poster_senior i.cat_all i.y, vce(robust)
outreg2 using "$RESULTS\Regression_postlevel.doc", append  /// 
	keep( pyq_code pyq_female pyq_hbp pyq_senior  pyq_admin nyqu_ctry  i.poster_code i.poster_female i.poster_hbp i.poster_senior i.cat_all) label /// 	
	addtext(Year FE & Robust Standard Errors, YES)	
