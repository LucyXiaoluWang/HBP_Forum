* creating the graphs for the paper


*------------------------------ creating the dataset for two of the graphs
/*
We need three distinct datasets for the graphs of the manuscript. Each graph-dataset 
will be created in the following lines.
*/
*-------------------------------------------------------------------------------
*Dataset No. 1 which will be used for parts of Fig2 and S1
use hbp_forum_data2agg, clear

sort msg_yqu id_user

*create categorical variable for the topic categories
gen cat_all = 0
replace cat_all = 1 if cat_g_neuromorphic == 1
replace cat_all = 2 if cat_g_brain_sim_model ==1 
replace cat_all = 3 if cat_g_neurorobotics==1
replace cat_all = 4 if cat_g_tech_support==1
replace cat_all = 5 if cat_g_organization==1
replace cat_all = 6 if cat_g_others==1
label define cat_alllab 1 "Neuromorphic" 2 "Brain Sim/Model" 3 "Neurorobotics" 4 "Tech Support" 5 "Organization" 6 "Others"

label values cat_all cat_alllab

gen byte tcat1  =1*(cat_all==1)
gen byte tcat2  =1*(cat_all==2)
gen byte tcat3  =1*(cat_all==3)
gen byte tcat4  =1*(cat_all==4)
gen byte tcat5  =1*(cat_all==5)
gen byte tcat6  =1*(cat_all==6)
gen byte check    =tcat6+tcat1+tcat2+ tcat3+tcat4+tcat5

assert check==1
drop check

* generate variables for the # of distinct users per post
* number of distinct users answering per quarter 
egen tag_u_msg = tag(msg_yqu id_user) if id_repl!=1
egen distinct_u_msg = total(tag_u_msg), by(msg_yqu)
label variable distinct_u_msg "# distinct users replying per quarter" 

* number of distinct users starting a topic per quarter 
egen tag_u_post = tag(msg_yqu id_user) if id_repl==1
egen distinct_u_post = total(tag_u_post), by(msg_yqu)
label variable distinct_u_post "# distinct users raising a topic per quarter" 


 *foratting the year-quarter variable 
gen quarter = string(msg_yqu, "%tqCCYY-q") 
labmask msg_yqu, values(quarter) 

save hbp_forum_graphData_1.dta, replace


*-------------------------------------------------------------------------------
* Dataset No.2
/* For two elements of Fig2, we need to use the forum data in wide format containing only the messages, user-ids, dates (including year-quarter and year of the first message) for each thread
We calculate the following variables per quarter:
	- # messages within 6 months per year-quarter
	- # messages within 3 months per year-quarter
	- # posts raised per year-quarter
	- # messages per year-quarter
	- average # messages within 6 months per post and year-quarter
	- average # messages within 3 months per post and year-quarter
*/
use hbp_forum_wide, clear


*---------------------------------------------------------------------
* generate the # of replies per thread
gen n_msg = 0
forvalues i = 2/40 {
    replace n_msg = n_msg + !missing(msg_`i'_txt)
}
label variable n_replies "# messages received per post "


* generate the date 6 months after the initial post was posted
gen date1_6mon=d_1+183
format %td date1_6mon
* originally d_1_sixmon
label variable date1_6mon "Date 6 months after initial post"
*calculate the number of messages received per thread within the first 6 months after the initial post
* for this we loop through the messages ranging from 2-40, as 1 is the initial post
gen n_msg_6mon = 0
forvalues i = 2/40 {
     replace n_msg_6mon = n_msg_6mon + !missing(msg_`i'_txt) if  d_`i' <= date1_6mon
} 
label variable n_msg_6mon "# messages per post within 6 months after the initial post"

*the same for three months
gen date1_3mon=d_1+91
format %td date1_3mon
label variable date1_3mon "Date 3 months after initial post"

gen n_msg_3mon = 0
* originally n_repl_threemon
forvalues i = 2/40 {
     replace n_msg_3mon = n_msg_3mon + !missing(msg_`i'_txt) if  d_`i' <= date1_3mon
} 
label variable n_msg_3mon "# messages per post within 3 months after the initial post"


*------- gen the variables on quarter-level

gen x=1
bys yqu: egen nyqu_post = total(x) 
bys yqu: egen nyqu_msg_6mon = total(n_msg_6mon)
* originally
bys yqu: egen nyqu_msg_3mon = total(n_msg_3mon) 
* originally nyqu_repl_threemon
bys yqu: egen nyqu_msg = total(n_msg)
*originally nyqu_repl 
gen nyqu_msg_6ppost = nyqu_msg_6mon/nyqu_post
*oriignally nyqu_rep_six_ppost
gen nyqu_msg_6ppost = nyqu_msg_3mon/nyqu_post
*originally nyqu_rep_three_ppost
label variable nyqu_post "# posts raised per year-quarter" 
label variable nyqu_msg "# messages per year-quarter"
label variable nyqu_msg_6mon "# messages within 6 months per year-quarter"
label variable nyqu_msg_3mon "# messages within 3 months per year-quarter"
label variable nyqu_msg_6ppost "average # messages within 6 months per post and year-quarter"
label variable nyqu_msg_3ppost "average # messages within 3 months per post and year-quarter"

save hbp_forum_graphData_2, replace
*-------------------------------------------------------------------------------
* Dataset No.3
/* for one element of Fig2 we need the following variables from the dataset aggregated to the user-quarter-level:
	- mean of the # total posts per user per quarter
	- mean of the # topics started per user per quarter
	- mean of the # replies per user per quarter

*/
use hbp_forum_data2agg, clear
sort msg_yqu id_user
forvalues i=1/282 {
	bys msg_yqu: egen nyqu_n_`i' = count(id_user) if id_user==`i' 
	bys msg_yqu: egen nyqu_start_`i' = count(id_user) if id_user==`i' & id_msg==1
	bys msg_yqu: egen nyqu_repl_`i' = count(id_user) if id_user==`i' & id_msg!=1

}
sort id_user
keep id_user msg_yqu nyqu_n_* nyqu_start* nyqu_repl* 

save data_uyqu_2reshape_step1, replace
use data_uyqu_2reshape_step1, clear

collapse nyqu_n_* nyqu_start_* nyqu_repl_* , by(msg_yqu id_user)
collapse nyqu_n_* nyqu_start* nyqu_repl* , by(msg_yqu)
reshape long nyqu_n_ nyqu_start_ nyqu_repl_ , i(msg_yqu) j(userid)
		
rename *_ *
rename userid id_user


bys msg_yqu: egen mean_n = mean(nyqu_n)
bys msg_yqu: egen mean_st = mean(nyqu_start)
bys msg_yqu: egen mean_rep = mean(nyqu_repl)
label variable mean_n "mean # posts per user per quarter"
label variable mean_st "mean # topics started per user per quarter"
label variable mean_rep "mean # replies per user per quarter"

gen yqu = qofd(msg_yqu)
format yqu %tq

xtset id_user yqu

save hbp_forum_graphData_3, replace 

*------------------------------------------------------------------------------
*------------------------------------------------------------------------------
**# Figure 2

use hbp_forum_graphData_2, clear 

* creating the figures  Fig2 a) Total replies & # replies per post 
tw line nyqu_msg_6mon nyqu_msg_3mon nyqu_msg yqu if yqu<=244 , lp(shortdash dash solid ) ///
	xtitle("") ytitle("") xlabel(220 "2015" 224 "2016" 228 "2017" 232 "2018" 236 "2019" 240 "2020" 244 "2021" , labsize(small)) ylabel(,angle(0) labsize(small)) ///
   legend(cols(1) ring(0) pos(11) lwidth(0) size(small) symxsize(*0.6) lab(1 "within 6 months") lab(2 "within 3 months") lab(3 "total topics & replies") nobox ///
   region(lstyle(none))) ylabel(,angle(0) labsize(small)) ///
	title("# total replies {sub: (time unit: year-quarter)}", size(medium)) graphregion(color(white)) saving(nc_repl_six_three_n, replace)

tw line nyqu_msg_6ppost nyqu_msg_3ppost yqu if yqu<=244 , lp(shortdash solid) xtitle("") ytitle("") ///
	xlabel(220 "2015" 224 "2016" 228 "2017" 232 "2018" 236 "2019" 240 "2020" 244 "2021" , labsize(small)) ylabel(,angle(0) labsize(small)) ///
   legend(cols(1) ring(0) pos(11) lwidth(0) size(small) symxsize(*0.425) lab(1 "within 6 months") lab(2 "within 3 months") nobox ///
   region(lstyle(none))) ylabel(,angle(0) labsize(small)) ylabel(0(1)5) ///
	title("# replies per post {sub: (time unit: year-quarter)} ", size(medium)) graphregion(color(white)) saving(nc_replppost_six_three_n, replace)


graph combine nc_repl_six_three_n.gph nc_replppost_six_three_n.gph, graphregion(fcolor(white)) cols(2) ///
	ysize(3) xsize(6) iscale(1) 
graph export FigChosen_repl_tt_ppost_1x2.png, replace 


*** ------ Fig2 b): 1) # distinct users; 2) # posts & replies per user
use hbp_forum_graphData_1.dta, clear

di yq(2020,1) // 240
di yq(2020,4) // 243
di yq(2015,1) // 220
di yq(2021,1) // 244


tw line distinct_u_post distinct_u_msg msg_yqu if msg_yqu<=244, lp(dash solid) ///
   xtitle("") ytitle("") xlabel(220 "2015" 224 "2016" 228 "2017" 232 "2018" 236 "2019" 240 "2020" 244 "2021" , labsize(small)) ylabel(,angle(0) labsize(small)) ///
   legend(cols(1) ring(0) pos(11) lwidth(0) size(small) symxsize(*0.6) lab(1 "# users raising a topic") lab(2 "# users replying") nobox ///
   region(lstyle(none))) ylabel(,angle(0) labsize(small)) ///
	title("# users {sub: (time unit: year-quarter)}", size(medium)) graphregion(color(white)) saving(distinct_users, replace)


use hbp_forum_graphData_3, clear 

tw tsline mean_n mean_st mean_rep, lp(solid dash shortdash) /// 
  tlabel(2015q1 "2015" 2016q1 "2016" 2017q1 "2017" 2018q1 "2018" 2019q1 "2019" 2020q1 "2020" 2021q1 "2021") /// 
  xtitle("") ytitle("")  xlabel(, labsize(small)) ylabel(,angle(0) labsize(small)) ///
  title("# posts and replies per user {sub:(time unit: year-quarter)}", size(medium)) graphregion(color(white)) /// 
  legend(cols(1) ring(0) pos(2) lwidth(0) size(small) symxsize(*0.6) lab(1 "# total") lab(2 "# topics") lab(3 "# replies") nobox region(lstyle(none))) /// 
  saving(tsn_mean_posts_repl_yqu, replace)

 
* combine the figures distinct_users.gph and tsn_mean_posts_repl_yqu.gph
graph combine distinct_users.gph tsn_mean_posts_repl_yqu.gph, graphregion(fcolor(white)) cols(2) ///
	ysize(3) xsize(6) iscale(1) 
graph export FigChosen_Nusers_postrepl_puser_1x2.png, replace 



*------------------------------------------------------------------------------
*-----------------------------------------------------------------------------
**# Figure 3

use  hbp_forum_wide_survival_oneQ, clear

gen time_diff=day_sol_1-date_earl_cor
li time_diff status day_sol_1 date_earl if day_sol_1==date_earl_cor
replace time_diff=1+time_diff if status==1
stset time_diff status
stdescribe 

* Fig3 a) Survival estimates for posts w/ and w/o code
sts graph if i_code==1, by(status_cum) /// 
	ylabel(,angle(0) labsize(small)) xtitle("days") /// 
	title("Survival estimates for posts w/ code", size(medium)) graphregion(color(white)) /// 
	legend(cols(1) ring(0) pos(2) lwidth(0) size(small) symxsize(*0.6) lab(1 "admin solved") lab(2 "user solved")nobox region(lstyle(none))) /// 
	  saving(KM_oneQ_solvedbyCUM_code1, replace)
	  graph export Fig_KaplanMeier_oneQ_solvedbyCUM_code1.png, replace 
sts graph if i_code==0, by(status_cum) /// 
	ylabel(,angle(0) labsize(small)) xtitle("days") /// 
	title("Survival estimates for posts w/o code", size(medium)) graphregion(color(white)) /// 
	legend(cols(1) ring(0) pos(2) lwidth(0) size(small) symxsize(*0.6) lab(1 "admin solved") lab(2 "user solved")nobox region(lstyle(none))) /// 
	  saving(KM_oneQ_solvedbyCUM_code0, replace)
	  graph export Fig_KaplanMeier_oneQ_solvedbyCUM_code0.png, replace 
graph combine KM_oneQ_solvedbyCUM_code1.gph KM_oneQ_solvedbyCUM_code0.gph, col(2) graphregion(color(white)) ///
	ysize(2.75) xsize(7) iscale(1) 
graph export Fig_KaplanMeier_oneQ_solvedbyCUM_code.png, replace

*Fig3 b) Survival estimates for initial post characteristics
sts  graph,  by(poster_hbp) ylabel(,angle(0) labsize(small)) xtitle("days") /// 
	title("Survival estimates for initial post characteristics ", size(medium)) graphregion(color(white)) /// 
	legend(cols(1) ring(0) pos(2) lwidth(0) size(small) symxsize(*0.6) lab(1 "Initial post by user w/o HBP affiliation") lab(2 "Initial post by user w/ HBP affiliation") nobox region(lstyle(none))) /// 
	  saving(KM_oneQ_HBPPoster, replace)
graph export Fig_KaplanMeier_oneQ_HBPPoster.png, replace 






*------------------------------------------------------------------------------
**# Supplementary Figure S1 

use hbp_forum_graphData_1.dta, clear
di yq(2015,1) // 220

graph bar (mean) tcat1 tcat2 tcat3 tcat4 tcat5 tcat6 if msg_yqu>220,  /// 
       over(msg_yqu,label(labsize(*0.5) alternate)) name(G2, replace) percentage stack  ///
	   bar(1, bcolor(orange*0.5)) bar(2, bcolor(midblue*1)) bar(3, bcolor(blue*1.75)) ///
       bar(4, bcolor(orange*1)) bar(5, bcolor(midblue*0.45)) bar(6, bcolor(orange*0.25)) ///
       legend(cols(3) size(vsmall) lab(1 "Neuromorphic") lab(2 "Brain Sim/Model") lab(3 "Neurorobotics") lab(4 "Tech Support") lab(5 "Organization") lab(6 "Others")  nobox ///
	   region(lstyle(none))) ylabel(,angle(0) labsize(vsmall)) ytitle(, size(small))  ///
       graphregion(color(white)) title("Topics by category", size(medium)) saving(Bar_topic_cat_yqu, replace)
graph export FigChosen_cat_nyqu.png, replace
