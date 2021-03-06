#' Obtain NCDC station data
#' @description Obtain NCDC station data for all stations residing in the CALMET domain during a specied time period.
#' @param data_filename a string representing the exact filename for the archive to be retrieved.
#' @param local_archive_dir a local path containing an archive of gzipped NCDC station data files.
#' @param year the year of the data archive.
#' @param bbox_lat_lon a spatial bounding box in projected in lat/lon coordinates.
#' @export calmet_get_ncdc_station_data
#' @examples
#' \dontrun{
#' # Get 2010 station data for a previously defined domain
#' calmet_get_ncdc_station_data(year = 2010,
#'                              bbox_lat_lon = bbox)
#'}

calmet_get_ncdc_station_data <- function(data_filename = NULL,
                                         local_archive_dir = NULL,
                                         year = NULL,
                                         bbox_lat_lon = NULL){
  
  # Add require statements
  require(mi)
  require(lubridate)
  require(plyr)
  require(stringr)
  require(RCurl)
  
  # When downloading a single file
  if (!is.null(data_filename)){
    
    year <- gsub("[0-9]*-[0-9]*-([0-9]*).gz", "\\1", data_filename)
    
    if (!is.null(local_archive_dir)){
      
      local_file_exists <- file.exists(paste(local_archive_dir, "/", data_filename, sep = ""))
      
      if (local_file_exists == TRUE){
        
        file_copied <- file.copy(paste(local_archive_dir, "/", data_filename, sep = ""),
                                 paste(getwd(), "/", data_filename, sep = ""), overwrite = TRUE)
        
        # Extract the downloaded data file
        system(paste("gunzip ", data_filename, sep = ""),
               intern = FALSE, ignore.stderr = TRUE)
        
        # Remove the .gz file from the working folder if it exists
        if (file.exists(data_filename)) file.remove(data_filename)
        
      }
      
      if (local_file_exists == FALSE){       
        file_copied <- FALSE            
      }
      
    }
    
    if (is.null(local_archive_dir)){
      
      remote_file_exists <- url.exists(paste("ftp://ftp.ncdc.noaa.gov/pub/data/noaa/", year,
                                             "/", data_filename, sep = ""))
      
      if (remote_file_exists == TRUE){
        system(paste("curl -O ftp://ftp.ncdc.noaa.gov/pub/data/noaa/", year,
                     "/", data_filename, sep = ""))
        
        # Extract the downloaded data file
        system("gunzip *.gz", intern = FALSE, ignore.stderr = TRUE)
        
        # Remove the .gz file from the working folder if it exists
        if (file.exists(data_filename)) file.remove(data_filename)
      }
      
      if (remote_file_exists == FALSE){
        NULL
      }
      
    }
    
    if (file.exists(gsub(".gz", "", data_filename))){
      files <- list.files(pattern = paste(gsub(".gz", "", data_filename), "$", sep = ''))
    }
    
    if (!file.exists(gsub(".gz", "", data_filename))){
      return(NULL)
    }
    
  }
  
  if (is.null(data_filename) & !is.null(year) & !is.null(bbox_lat_lon)){
    
    # Check whether 'year' are within set bounds (1950 to current year)
    if (year < 1892 | year > year(Sys.Date())) {
      stop("Year is not volid.")
    } else { }
    
    # Get hourly surface data history CSV from NOAA/NCDC FTP
    calmet_get_ncdc_history()
    
    # Read in the 'ish-history.csv' file
    st <- read.csv("ish-history.csv")
    
    # Get formatted list of station names and elevations
    names(st)[c(3, 9)] <- c("NAME", "ELEV")
    st <- st[, -5]
        
    # Recompose the years from the data file
    st$BEGIN <- as.numeric(substr(st$BEGIN, 1, 4))
    st$END <- as.numeric(substr(st$END, 1, 4))
    
    # Generate a list based on the domain location, also ignoring stations
    # without beginning years reported
    domain_list <- subset(st, st$LON >= bbox_lat_lon@xmin & 
                            st$LON <= bbox_lat_lon@xmax &
                            st$LAT >= bbox_lat_lon@ymin &
                            st$LAT <= bbox_lat_lon@ymax &
                            BEGIN <= year - 1 &
                            END >= year + 1)
    
    if (nrow(domain_list) == 0){  
      stop("There are no stations.")
    }
    
    # Initialize data frame for file status reporting
    outputs <- as.data.frame(matrix(NA, dim(domain_list)[1], 2))
    names(outputs) <- c("FILE", "STATUS")
    
    # Download the gzip-compressed data files for the years specified
    # Provide information on the number of records in data file retrieved       
    for (i in 1:nrow(domain_list)){
      
      outputs[i, 1] <- paste(sprintf("%06d", domain_list[i,1]),
                             "-", sprintf("%05d", domain_list[i,2]),
                             "-", year, ".gz", sep = "")
      
      if (!is.null(local_archive_dir)){
        
        local_file_exists <- file.exists(paste(local_archive_dir, "/", outputs[i, 1], sep = ""))
        
        if (local_file_exists == TRUE){
          
          file_copied <- file.copy(paste(local_archive_dir, "/", outputs[i, 1] , sep = ""),
                                   paste(getwd(), "/", outputs[i, 1] , sep = ""), overwrite = TRUE)
          
          # Determine if file is available locally
          outputs[i, 2] <- ifelse(file_copied == "TRUE", 'available', 'missing')
          
          # Extract the downloaded data file
          system(paste("gunzip ", outputs[i, 1], sep = ""),
                 intern = FALSE, ignore.stderr = TRUE)
          
          # Remove the .gz file from the working folder if it exists
          if (file.exists(outputs[i, 1])) file.remove(outputs[i, 1])
          
        }
        
        if (local_file_exists == FALSE){       
          file_copied <- FALSE            
        }
        
      }
      
      if (is.null(local_archive_dir) | file_copied == FALSE){
        
        remote_file_exists <- url.exists(paste("ftp://ftp.ncdc.noaa.gov/pub/data/noaa/", year,
                                               "/", outputs[i, 1], sep = ""))
        
        if (remote_file_exists == TRUE){
          system(paste("curl -O ftp://ftp.ncdc.noaa.gov/pub/data/noaa/", year,
                       "/", outputs[i, 1], sep = ""))
          
          # Determine if file is available locally
          outputs[i, 2] <- ifelse(file.exists(outputs[i, 1]) == "TRUE", 'available', 'missing')
          
          # Extract the downloaded data file
          system("gunzip *.gz", intern = FALSE, ignore.stderr = TRUE)
          
          # Remove the .gz file from the working folder if it exists
          if (file.exists(outputs[i, 1])) file.remove(outputs[i, 1])    
          
        }
        
      }
      
    }
    
    # Generate report of stations and file transfers
    file_report <- cbind(domain_list, outputs)
    row.names(file_report) <- 1:nrow(file_report)
    
    # Get list of data files
    files <- gsub(".gz", "", subset(file_report, STATUS == "available")[,12])
    
    # Filter file list to only use those files that were requested
    files <- files[which(outputs[, 1] %in% paste(files, ".gz", sep = ""))]
    
    # Remove any NA values from vector
    files <- files[!is.na(files)]
    
  }
  
  # Define column widths from met data file
  column_widths <- c(4, 6, 5, 4, 2, 2, 2, 2, 1, 6,
                     7, 5, 5, 5, 4, 3, 1, 1, 4, 1,
                     5, 1, 1, 1, 6, 1, 1, 1, 5, 1,
                     5, 1, 5, 1)
  
  for (i in 1:length(files)){
    
    # Read data from mandatory data section of each file, which is a fixed-width string
    data <- read.fwf(files[i], column_widths)
    data <- data[, c(2:8, 10:11, 13, 16, 19, 21, 29, 31, 33)]
    names(data) <- c("USAFID", "WBAN", "YR", "M", "D", "HR", "MIN", "LAT", "LONG",
                     "ELEV", "WIND.DIR", "WIND.SPD", "CEIL.HGT", "TEMP", "DEW.POINT",
                     "ATM.PRES")
    
    # Recompose data and use consistent missing indicators of 9999 for missing data
    data$LAT <- data$LAT/1000
    data$LONG <- data$LONG/1000
    data$WIND.DIR <- ifelse(data$WIND.DIR > 400, 999, data$WIND.DIR)
    data$WIND.SPD <- ifelse(data$WIND.SPD > 100, 999.9, data$WIND.SPD/10)
    data$TEMP <-  ifelse(data$TEMP > 900, 999.9, round((data$TEMP/10) + 273.2, 1))
    data$DEW.POINT <- ifelse(data$DEW.POINT > 100, 999.9, data$DEW.POINT/10)
    data$ATM.PRES <- ifelse(data$ATM.PRES > 2000, 999.9, data$ATM.PRES/10)
    data$CEIL.HGT <- ifelse(data$CEIL.HGT == 99999, 999.9, round(data$CEIL.HGT*3.28084/100, 0))
    
    # Read data from additional data section of each file
    # Additional data is of variable length
    additional.data <- as.data.frame(scan(files[i], what = 'character', sep = "\n", quiet = TRUE))
    colnames(additional.data) <- c("string")
    
    #
    # opaque sky cover: GF1
    #
    
    # Get number of entries in the dataset that contain sky cover codes
    number_of_sky_cover_lines <- sum(str_detect(additional.data$string, "GF1"), na.rm = TRUE)
    
    if (number_of_sky_cover_lines > 1000){
      
      # Get the sky coverage code values from the dataset
      GF1_sky_cover_coverage_code <- as.character(str_extract_all(additional.data$string, "GF1[0-9][0-9]"))
      GF1_sky_cover_coverage_code <- str_replace_all(GF1_sky_cover_coverage_code,
                                                     "GF1([0-9][0-9])", "\\1")
      GF1_sky_cover_coverage_code <- as.numeric(GF1_sky_cover_coverage_code)
      
      # Replace any '99' values with NA values
      GF1_sky_cover_coverage_code[(GF1_sky_cover_coverage_code) == 99] <- NA
      
      # Generate a vector of indices where the sky coverage code is missing
      missing_sky_cover_indices <- which(is.na(GF1_sky_cover_coverage_code))
      
      # Create a vector of timestamps using the 'ISOdatetime' function
      timestamps <- ISOdatetime(data$YR, data$M, data$D, data$HR, data$MIN, sec = 0, tz = "GMT")
      
      # Create a data frame with a timestamp column and a sky cover code column
      GF1_sky_cover_coverage_code_df <- data.frame(timestamps, GF1_sky_cover_coverage_code)
      
      # Generate a vector of imputations for each missing value using the 'mi' package
      imputed_values <- round(unname(mi.count(GF1_sky_cover_coverage_code~timestamps,
                                              data = GF1_sky_cover_coverage_code_df)@random), 0)
      
      # Imputed values less than 0 or greater than 9 are bounding by 0 and 9 values 
      imputed_values[imputed_values > 9] <- 9
      imputed_values[imputed_values < 0] <- 0
      
      # Replace NA values with predicted values from imputation
      for (j in 1:length(missing_sky_cover_indices)){
        GF1_sky_cover_coverage_code[missing_sky_cover_indices[j]] <- imputed_values[j]
      }
      
      # Place the sky coverage vector into the 'additional.data' data frame
      additional.data$SKY.COVER <- GF1_sky_cover_coverage_code
      
    }
    
    if (number_of_sky_cover_lines < 1000){
      
      # Create vector of missing values with length equal to number of rows
      # of 'additional.data'
      missing_sky_cover <- rep(999, nrow(additional.data))
      
      # Place the sky coverage vector into the 'additional.data' data frame
      additional.data$SKY.COVER <- missing_sky_cover
      
    }
    
    #
    # precipitation: AA[1-2]
    #
    
    # Get number of entries that contain precipitation
    number_of_precip_lines <- sum(str_detect(additional.data$string, "AA1"), na.rm = TRUE)
    
    AA1_precip_period_in_hours <- as.character(str_extract_all(additional.data$string, "AA1[0-9][0-9]"))
    AA1_precip_period_in_hours <- str_replace_all(AA1_precip_period_in_hours,
                                                  "AA1([0-9][0-9])", "\\1")
    AA1_precip_period_in_hours <- as.numeric(AA1_precip_period_in_hours)     
    AA1_precip_depth_in_mm <- as.character(str_extract_all(additional.data$string,
                                                           "AA1[0-9][0-9][0-9][0-9][0-9][0-9]"))
    AA1_precip_depth_in_mm <- str_replace_all(AA1_precip_depth_in_mm,
                                              "AA1[0-9][0-9]([0-9][0-9][0-9][0-9])", "\\1")
    AA1_precip_depth_in_mm <- as.numeric(AA1_precip_depth_in_mm)/10
    AA1_precip_rate_in_mm_per_hour <- AA1_precip_depth_in_mm / AA1_precip_period_in_hours
    
    # Replace any NA values with the '999' missing indicator
    AA1_precip_rate_in_mm_per_hour[is.na(AA1_precip_rate_in_mm_per_hour)] <- 999
    
    # Place the precipitation rate vector into the 'additional.data' data frame
    additional.data$PRECIP.RATE <- round_any(AA1_precip_rate_in_mm_per_hour, 0.1, f = round)      
    
    # Remove the string portion of the 'additional data' data frame
    additional.data$string <- NULL
    
    # Column bind the 'data' and 'additional data' data frame
    data <- cbind(data, additional.data)
    
    # Calculate the RH using the August-Roche-Magnus approximation
    RH <- ifelse(data$TEMP == 999.9 | data$DEW.POINT == 999.9, NA, 
                 100 * (exp((17.625 * data$DEW.POINT) / (243.04 + data$DEW.POINT))/
                          exp((17.625 * (data$TEMP - 273.2)) / (243.04 + (data$TEMP - 273.2)))))
    
    data$RH <- round_any(as.numeric(RH), 0.1, f = round)
    
    data$RH[is.na(data$RH)] <- 999
    
    # Calculate the precipitation code
    # 
    # Category        Temperature   Rate (mm/hr)    Code
    # -------------   -----------   -------------   ----
    # Light Rain      >0 deg C      R < 2.5         1
    # Moderate Rain   >0 deg C      2.5 ≤ R < 7.6   2
    # Heavy Rain      >0 deg C      R ≤ 7.6         3
    # Light Snow      <=0 deg C     R < 2.5         19
    # Moderate Snow   <=0 deg C     2.5 ≤ R < 7.6   20
    # Heavy Snow      <=0 deg C     R ≤ 7.6         21
    
    PRECIP.CODE <- ifelse(data$PRECIP.RATE > 0 & data$PRECIP.RATE < 2.5, 1,
                          ifelse(data$PRECIP.RATE >= 2.5 & data$PRECIP.RATE < 7.6, 2,
                                 ifelse(data$PRECIP.RATE >= 7.6 & data$PRECIP.RATE < 900,
                                        3, 999)))
    
    PRECIP.CODE <- ifelse(PRECIP.CODE < 25 & data$TEMP < 273.2, PRECIP.CODE + 18, PRECIP.CODE)
    
    # Add precipitation code to the data frame
    data$PRECIP.CODE <- PRECIP.CODE
    
    # Write CSV file for each station, combining data elements from the mandatory data
    # section and the additional data section
    write.csv(data, file = paste(gsub(".*/(.*)", "\\1", gsub(".gz$", "", files[i])), ".csv", sep = ""),
              row.names = FALSE)
    
    # Remove the data file from the working directory
    file.remove(files[i])
    
  }
  
  # Get list of CSV files that were created
  CSV_files_created <- gsub("$", ".csv", files)
  
  # Return the list of created CSV files
  return(CSV_files_created)
  
}
