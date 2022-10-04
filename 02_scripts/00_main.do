/***************************************************
Do-File: 00_main.do
Purpose: Main file to define general settings and
         to run do-files
Author:
First version:
Current version:

OVERVIEW
  This script generates tables and figures for the paper:
      <PROJECT> <AUTHOR>
  All raw data are stored in /01_data
  All tables are outputted to /04_results/tables
  All figures are outputted to /04_results/figures

SOFTWARE REQUIREMENTS
  Analyses run on ... using Stata version ... and ....

TO PERFORM A CLEAN RUN, DELETE THE FOLLOWING TWO FOLDERS:
  /03_results
  /04_publication
  ...

The source of this script is based on the Data Room Scripts combined with
the project https://github.com/reifjulian/my-project
**********************/

* User must set the global macro MyProject to the path of the folder that includes run.do
* global MyProject "C:/Users/jdoe/MyProject"
global MyProject "/dataroom"

global data_dir "01_data"
global scripts_dir "02_scripts"
global results_dir "03_results"
global publ_dir "04_publication"

global log_dir "$MyProject/$results_dir/01_log"
global tables_dir "$MyProject/$results_dir/02_tables"
global figures_dir "$MyProject/$results_dir/03_figures"

global Rscripts_dir "$MyProject/$scripts_dir/programs"

cap mkdir "$MyProject/$results_dir"
cap mkdir "$log_dir"
cap mkdir "$tables_dir"
cap mkdir "$figures_dir"

cap mkdir "$MyProject/$publ_dir"

* To disable the R portion of the analysis, set the following flag to 0
* To enable set to 1
global enable_R = 1

* flag to install Stata or R libraries
global install_libraries = 1

* Confirm that the global for the project root directory has been defined
assert !missing("$MyProject")

* Initialize log and record system parameters
clear
set more off
cap log close
local datetime : di %tcCCYY.NN.DD!-HH.MM.SS `=clock("$S_DATE $S_TIME", "DMYhms")'
local logfile "$log_dir/`datetime'.log.txt"
log using "`logfile'", text

di "Begin date and time: $S_DATE $S_TIME"
di "Stata version: `c(stata_version)'"
di "Updated as of: `c(born_date)'"
di "Variant:       `=cond( c(MP),"MP",cond(c(SE),"SE",c(flavor)) )'"
di "Processors:    `c(processors)'"
di "OS:            `c(os)' `c(osdtl)'"
di "Machine type:  `c(machine_type)'"

* All required Stata packages are available in the /libraries/stata folder
tokenize `"$S_ADO"', parse(";")
while `"`1'"' != "" {
  if `"`1'"'!="BASE" cap adopath - `"`1'"'
  macro shift
}
adopath ++ "$MyProject/$scripts_dir/libraries/stata"
mata: mata mlib index

* Stata programs and R scripts are stored in /programs
adopath ++ $"Rscripts_dir"




* Install Stata libraries
* Include rscript if you want to use R
* Set the directories to local location
cap mkdir "$MyProject/$scripts_dir/libraries/stata"
sysdir set PLUS "$MyProject/$scripts_dir/libraries/stata"
sysdir set PERSONAL "$MyProject/$scripts_dir/libraries/stata"

* install the Stata libraries
if "$install_libraries"!="0" do "$MyProject/$scripts_dir/01_install_libraries.do"

* Setup R
* R packages can be installed manually (see README) or installed automatically by uncommenting the following line
if "$enable_R"=="1" rscript using "$Rscripts_dir/_install_R_packages.R"

* Stata and R version control
version 15
if "$enable_R" == "1" rscript, rversion(3.6) require(ggplot2)
if "$enable_R" == "1" rscript using "$Rscripts_dir/_rversion.R"

* -------------------------
* Run project analysis
* -------------------------
do "$MyProject/$scripts_dir/02_process_raw_data.do"
do "$MyProject/$scripts_dir/03_clean_data.do"
do "$MyProject/$scripts_dir/04_regressions.do"
do "$MyProject/$scripts_dir/05_make_tables_figures.do"

* End log
di "End date and time: $S_DATE $S_TIME"
log close

** EOF
