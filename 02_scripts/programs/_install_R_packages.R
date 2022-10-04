print("Installing packages")

list.of.required.packages <- c("ggplot2") # "RStata", "plyr", "stringr", "stargazer", "estimatr"
new.packages <- list.of.required.packages[!(list.of.required.packages %in% installed.packages()[, "Package"])]

# install the new packages
if(length(new.packages)) install.packages(new.packages)

