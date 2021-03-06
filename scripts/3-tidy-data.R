# Manually fix data for specific data sets --------------------------------

# sc_07a ---------------------------------------------------------------- #

# Convert date column that contains strings (because it is describing an interval) to a true date column
# Use the end-of-week date as the reporting date
data_sets$sc_07a$data$new <- data_sets$sc_07a$data$new %>% 
  mutate(
    Date = Date %>% 
      str_sub(start = -8L) %>% 
      as.Date("%d/%m/%y")
  )

# Tidy data ---------------------------------------------------------------
# Convert data frames into a tidy (long) data format
# For use on https://statistics.gov.scot/

ratio_dictionary_regex <- "( per )|(percent)|(rate)|(ratio)"

for(x in names(data_sets)){
  
  if(data_sets[[x]]$flags$import){
    
    # Fix common errors with data entry and formatting ------------------ #
    
    data_sets[[x]]$data$new <- data_sets[[x]]$data$new %>% 
      # Drop rows where the date is NA
      # NA values in other columns are treated as valid data
      filter(!is.na(Date)) %>% 
      # Remove timezone information from date variable
      mutate(
        Date = ymd(Date)
      ) %>% 
      # Where the variable name contains a word that indicates that it is a
      # ratio, multiply the value by 100
      mutate(
        across(
          matches(ratio_dictionary_regex, ignore.case = TRUE),
          ~ . * 100
        )
      )
    
    # Pivot data into tidy (long) format -------------------------------- #
    
    # Health board data needs special rules, because the column names
    # indicate the health board rather than the variable being measured;
    # instead, read the variable name from the metadata CSV file
    
    if(data_sets[[x]]$import_rules$source == "hb"){
      
      # Health board data
      data_sets[[x]]$data$tidy_long <- data_sets[[x]]$data$new %>% 
        pivot_longer(
          cols = -Date,
          names_to = "HBname",
          values_to = "Value"
        ) %>% 
        left_join(
          HB_codes,
          by = c(HBname = "HB2014Name")
        ) %>% 
        mutate(
          Variable = data_sets[[x]]$export_rules$variable_name
        )%>% 
        group_by(HBname) %>% 
        arrange(Date, .by_group = TRUE) %>% 
        ungroup()
      
    } else {
      
      # Whole-of-Scotland data
      data_sets[[x]]$data$tidy_long <- data_sets[[x]]$data$new %>% 
        pivot_longer(
          cols = -Date,
          names_to = "Variable",
          values_to = "Value"
        ) %>% 
        mutate(
          HBname = NA,
          HB2014Code = "S92000003"
        )
      
    }
    
    data_sets[[x]]$data$tidy_long <- data_sets[[x]]$data$tidy_long %>% 
      mutate(
        # Measurement type is "Count", unless the variable name contains a
        # word that indicates that it is a ratio
        Measurement = if_else(
          condition = str_detect(str_to_lower(Variable), ratio_dictionary_regex),
          true = "Ratio",
          false = "Count"
        ),
        "Units" = Variable,
        # Coerce Value to string, to support health board data's use of *
        Value = as.character(Value)
      ) %>% 
      # Order variables appropriately, drop health board names, and name
      # variables according to https://statistics.gov.scot/ standards
      select(
        GeographyCode = HB2014Code,
        DateCode = Date,
        Measurement, 
        Units,
        Value,
        Variable
      )
    
  }
  
}
