@REM ***************************************************
@REM clean.bat
@REM Purpose: Remove temporary and output files
@REM Author: Erik Buunk
@REM First version: 0.1 - 2021-09-13
@REM Current version: 0.1 - 2021-09-13
@REM **********************\

@REM Intermediate data files
del /q 01_data\02_external\*
del /q 01_data\03_intermediate\*
del /q 01_data\04_final\*

@REM output files
del /q 03_results\01_log\*
del /q 03_results\02_tables\*
del /q 03_results\03_figures\*