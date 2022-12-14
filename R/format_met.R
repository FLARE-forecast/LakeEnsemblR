#' Format meteorological data for each model
#'@description
#' Format dataframe into shape for the specified model
#'
#' @name scale_met
#' @param met dataframe; as read.csv() from standardised input.
#' @param model character; Model for which scaling parameters will be applied. Options include
#'    c("GOTM", "GLM", "Simstrat", "FLake")
#' @param config_file filepath; To LER config yaml file. Only used if model = "GOTM"
#' @return dataframe of met data in the model format
#' @importFrom gotmtools read_yaml set_yaml write_yaml get_yaml_value
#' @export
format_met <- function(met, model, config_file){

  # Load Rdata
  data("met_var_dic", package = "LakeEnsemblR", envir = environment())

  yaml <- read_yaml(config_file)

  lat <- get_yaml_value(yaml, label = "location", key = "latitude")
  lon <- get_yaml_value(yaml, label = "location", key = "longitude")
  elev <- get_yaml_value(yaml, label = "location", key = "elevation")

  ### Check what met data is available, as this determines what model forcing option to use
  # (in the simstrat config file)
  chck_met <- lapply(met_var_dic$standard_name, function(x)x %in% colnames(met))
  names(chck_met) <- met_var_dic$short_name
  ## list with long standard names
  l_names <- as.list(met_var_dic$standard_name)
  names(l_names) <- met_var_dic$short_name
  # heat flux
  heat_flux <- FALSE

  # Calculate other required variables
  # Relative humidity
  if(!chck_met$relh & chck_met$airt & chck_met$dewt){
    # The function is in helpers.R the formula is from the weathermetrics package
    met[[l_names$relh]] <- dewt2relh(met[[l_names$dewt]], met[[l_names$airt]])

    if(any(is.na(met[[l_names$relh]]))){
      met[[l_names$relh]] <- na.approx(met[[l_names$relh]])
      message("Interpolated NAs")
    }
    chck_met$relh <- TRUE
  }

  # Vapour pressure
  if(!chck_met$vap_p & chck_met$relh){
    # Calculate vapour pressure as: relhum * saturated vapour pressure
    # Used formula for saturated vapour pressure from:
    # Woolway, R. I., Jones, I. D., Hamilton, D. P., Maberly, S. C., Muraoka, K., Read,
    # J. S., . . . Winslow, L. A. (2015).
    # Automated calculation of surface energy fluxes with high-frequency lake buoy data.
    # Environmental Modelling & Software, 70, 191-198.

    met[[l_names$vap_p]] <- met[[l_names$relh]] / 100 * 6.11 *
      exp(17.27 * met[[l_names$airt]] / (237.3 + met[[l_names$airt]]))
    chck_met$vap_p <- TRUE

  }

  # Pressure
  if(!chck_met$p_surf & chck_met$p_sea){
    # If only sea-level pressure is available, convert to lake surface
    # level pressure using elevation
    # We use the barometric formula. In reality, other factors such as temperature
    # play a role too.
    # https://www.math24.net/barometric-formula/#:~:text=P(h)%3DP0,exp(%E2%88%920.00012H).
    # https://en.wikipedia.org/wiki/Barometric_formula

    met[[l_names$p_surf]] <- met[[l_names$p_sea]] * exp(-0.00012 * elev)

    chck_met$p_surf <- TRUE
  }

  # No Pressure available
  if(!chck_met$p_surf){
    # No pressure known - use crude calculation using air temperature and assuming sea level pressures is 101325 Pa
    # https://www.mide.com/air-pressure-at-altitude-calculator
    # https://en.wikipedia.org/wiki/Barometric_formula
    g <- 9.80665 # Gravity
    Pb <- 101325 # Pressure at sea level
    Lb <- -0.0065 # Standard temperature lapse rate
    R <- 8.31432 # Universal gas constant
    M <- 0.0289644 # Molar mass of Earth's air

    at_samp <- met[[l_names$airt]]
    at_samp[at_samp < 4] <- 4 # Any air temperature below 3.3 degC results in NaN

    met[[l_names$p_surf]] <- Pb * (1 + (Lb / at_samp) * (elev))^((-g * M) / R *Lb)

    chck_met$p_surf <- TRUE
  }

  # Cloud cover
  if(!chck_met$cc){

    met[[l_names$cc]] <- gotmtools::calc_cc(date = met[[l_names$time]],
                                          airt = met[[l_names$airt]],
                                          relh = met[[l_names$relh]],
                                          swr = met[[l_names$swr]],
                                          lat = lat, lon = lon,
                                          elev = elev)
    chck_met$cc <- TRUE

  }

  # Precipitation
  # Users can be provide rainfall, precipitation, and/or snowfall in mm/d or mm/h

  # Convert everything from mm/h to mm/d if needed
  if(!chck_met$precip & chck_met$precip_h){
    # Convert
    met[[l_names$precip]] <- met[[l_names$precip_h]] * 24

    chck_met$precip <- TRUE
  }
  if(!chck_met$rain & chck_met$rain_h){
    # Convert
    met[[l_names$rain]] <- met[[l_names$rain_h]] * 24

    chck_met$rain <- TRUE
  }
  if(!chck_met$snow & chck_met$snow_h){
    # Convert
    met[[l_names$snow]] <- met[[l_names$snow_h]] * 24

    chck_met$snow <- TRUE
  }


  # If precipitation is not provided, but rainfall is, compute precipitation
  if(!chck_met$precip & chck_met$rain){
    # Set precipitation to rain
    met[[l_names$precip]] <- met[[l_names$rain]]

    # In case snowfall is also provided, add snowfall to precipitation
    if(chck_met$snow){
      met[[l_names$precip]] <- met[[l_names$precip]] + met[[l_names$snow]]
    }
    chck_met$precip <- TRUE
  }

  # If precipitation is provided, but rainfall is not, compute rainfall
  if(chck_met$precip & !chck_met$rain){
    # If snowfall is provided, subtract snow from precipitation to get rainfall.
    if(chck_met$snow){
      met[[l_names$rain]] <- met[[l_names$precip]] -
        met[[l_names$snow]]
      met[[l_names$rain]][met[[l_names$rain]] < 0] <- 0
    }else{
      met[[l_names$rain]] <- met[[l_names$precip]]
    }
  }

  # Precipitation needs to be in m h-1 for Simstrat
  # If no precipitation is provided, precipitation is assumed to be 0
  if(chck_met$precip){
    met$`Precipitation_meterPerHour` <- met[[l_names$precip]] / 24 / 1000
  }else{
    met[[l_names$precip]] <- 0
    met[[l_names$rain]] <- 0
    chck_met$precip <- TRUE
    # Precipitation_metPerHour does not have to be recalculated, as Simstrat
    # can be run without precipitation column.
  }

  #Snowfall
  if(!chck_met$snow & chck_met$precip){
    freez_ind <- which(met[[l_names$airt]] < 0)
    met[[l_names$snow]] <- 0
    met[[l_names$snow]][freez_ind] <- met[[l_names$precip]][freez_ind]
    chck_met$snow <- TRUE
  }

  # Long-wave radiation
  if(!chck_met$lwr & chck_met$dewt){
    met[[l_names$lwr]] <- gotmtools::calc_in_lwr(cc = met[[l_names$cc]],
                                      airt = met[[l_names$airt]],
                                      dewt = met[[l_names$dewt]])
    chck_met$lwr <- TRUE
  } else if(!chck_met$lwr & !chck_met$dewt & chck_met$relh){
    met[[l_names$lwr]] <- gotmtools::calc_in_lwr(cc = met[[l_names$cc]],
                                      airt = met[[l_names$airt]],
                                      relh = met[[l_names$relh]])
    chck_met$lwr <- TRUE
  }

  # wind speed
  if(!chck_met$wind_speed & chck_met$u10 & chck_met$v10){
    met[[l_names$wind_speed]] <- sqrt(met[[l_names$u10]]^2 + met[[l_names$v10]]^2)
  }

  # wind direction
  if(!chck_met$wind_dir & chck_met$u10 & chck_met$v10){
    met[[l_names$wind_dir]] <- calc_wind_dir(met[[l_names$u10]], met[[l_names$v10]])
    chck_met$wind_dir <- TRUE
  }

  # u and v wind vectors
  if(!chck_met$u10 & !chck_met$v10 & chck_met$wind_speed & chck_met$wind_dir){
    rads <- met[[l_names$wind_dir]] / 180 * pi
    met[[l_names$u10]] <- met[[l_names$wind_speed]] * cos(rads)
    met[[l_names$v10]] <- met[[l_names$wind_speed]] * sin(rads)
    chck_met$u10 <- TRUE
    chck_met$v10 <- TRUE
  }

  if(!chck_met$u10 & !chck_met$v10 & chck_met$wind_speed & !chck_met$wind_dir){
    met[[l_names$u10]] <- met[[l_names$wind_speed]]
    met[[l_names$v10]] <- 0
    chck_met$u10 <- TRUE
    chck_met$v10 <- TRUE
  }

##---------------------------------- FLake ---------------------------------------------------------

  if("FLake" %in% model){

    ## Extract start, stop, lat & lon for netCDF file from config file
    start <- get_yaml_value(yaml, "time", "start")
    stop <- get_yaml_value(yaml, "time", "stop")
    met_timestep <- get_meteo_time_step(file.path(get_yaml_value(yaml, "input", "meteo", "file")))

    fla_fil <- file.path(get_yaml_value(yaml, "config_files", "FLake"))

    # Subset temporally
    if(!is.null(start) & !is.null(stop)){
      fla_met <- met[(met[["datetime"]] >= start & met[["datetime"]] < stop), ]
    }else{
      fla_met <- met
    }

    input_nml(fla_fil, label = "SIMULATION_PARAMS", key = "del_time_lk", met_timestep)


    fla_met$index <- seq_len(nrow(fla_met))

    # Re-organise
    fla_met <- fla_met[, c(l_names$swr, l_names$airt, l_names$vap_p,
                           l_names$wind_speed, l_names$cc, l_names$time)]
    fla_met$datetime <- format(fla_met$datetime, format = "%Y-%m-%d %H:%M:%S")
    colnames(fla_met)[1] <- paste0("!", colnames(fla_met)[1])

    #Reduce number of digits
    fla_met[, -c(1, ncol(fla_met))] <- signif(fla_met[, -c(1, ncol(fla_met))], digits = 8)

    return(fla_met)
  }

##--------------------------------- GLM ------------------------------------------------------------

  if("GLM" %in% model){

    glm_met <- met

    # Convert units
    glm_met$Precipitation_meterPerDay <- glm_met[[l_names$precip]] / 1000
    glm_met$Snowfall_meterPerDay <- glm_met[[l_names$snow]] / 1000

    glm_met <- glm_met[, c(l_names$time, l_names$swr, l_names$lwr,
                           l_names$airt, l_names$relh, l_names$wind_speed,
                           "Precipitation_meterPerDay", "Snowfall_meterPerDay")]

    colnames(glm_met) <- c("Date", "ShortWave", "LongWave", "AirTemp", "RelHum", "WindSpeed",
                           "Rain", "Snow")
    glm_met <- as.data.frame(glm_met)
    glm_met[["Date"]] <- format(glm_met[["Date"]], format = "%Y-%m-%d %H:%M:%S")

    #Reduce number of digits
    glm_met[, -1] <- signif(glm_met[, -1], digits = 8)

    return(glm_met)
  }

##--------------------------- GTOM -----------------------------------------------------------------

  if("GOTM" %in% model){

    got_met <- met

    # Convert units
    got_met$Precipitation_meterPerSecond <- got_met[[l_names$precip]] / 1000 / 86400

    got_met <- got_met[, c(l_names$time, l_names$u10, l_names$v10,
                           l_names$p_surf, l_names$airt, l_names$relh,
                           l_names$cc, l_names$swr, "Precipitation_meterPerSecond")]

    colnames(got_met)[1] <- paste0("!", colnames(got_met)[1])
    got_met <- as.data.frame(got_met)
    got_met[, 1] <- format(got_met[, 1], "%Y-%m-%d %H:%M:%S")

    #Reduce number of digits
    got_met[, -1] <- signif(got_met[, -1], digits = 8)

    return(got_met)
  }

##----------------------------- Simstrat -----------------------------------------------------------

  if("Simstrat" %in% model){

    sim_met <- met

    par_file <- file.path(get_yaml_value(yaml, "config_files", "Simstrat"))

    # If snow_module is true, there needs to be a precipitation (or snowfall) columnn.
    if("Precipitation_meterPerHour" %in% colnames(sim_met)){
      snow_module <- TRUE
      input_json(par_file, "ModelConfig", "SnowModel", 1)
    } else {
      snow_module <- FALSE
      input_json(par_file, "ModelConfig", "SnowModel", 0)
    }

    # If pressure is given, set p_air to the average air pressure. Otherwise set it to 1 atm
    if(chck_met$p_surf){
      input_json(par_file, "ModelParameters", "p_air", round(mean(met[[l_names$p_surf]]) / 100))
    }else{
      input_json(par_file, "ModelParameters", "p_air", 1013)
    }

    ### Pre-processing
    # Time
    if("datetime" %in% colnames(sim_met)){
      # Time in simstrat is in decimal days since a defined start year
      start_year <- get_json_value(par_file, "Simulation", "Reference year")

      sim_met$datetime <- as.numeric(difftime(sim_met$datetime,
                                              as.POSIXct(paste0(start_year, "-01-01")),
                                              units = "days"))
    }else{
      stop(paste0("Cannot find \"datetime\" column in the input file. Without this column, ",
                  "the model cannot run"))
    }

    # Determine forcing mode based on available met data
    if(chck_met$time & chck_met$u10 & chck_met$v10 & chck_met$airt & chck_met$swr &
       chck_met$vap_p & chck_met$lwr){
      forcing_mode <- 5
      sim_met <- sim_met[, c(l_names$time, l_names$u10, l_names$v10, l_names$airt, l_names$swr,
                             l_names$vap_p, l_names$lwr)]
      if(snow_module){
        sim_met[["Precipitation_meterPerHour"]] <- met[["Precipitation_meterPerHour"]]
      }

    }else if(chck_met$time & chck_met$u10 & chck_met$v10 & heat_flux & chck_met$swr){
      forcing_mode <- 4
      stop("Simstrat: Forcing mode 4 currently not supported.")
    }else if(chck_met$time & chck_met$u10 & chck_met$v10 & chck_met$airt & chck_met$swr &
              chck_met$vap_p & chck_met$cc){

      forcing_mode <- 3
      sim_met <- sim_met[, c(l_names$time, l_names$u10, l_names$v10, l_names$airt, l_names$swr,
                             l_names$vap_p, l_names$cc)]
      if(snow_module){
        sim_met[["Precipitation_meterPerHour"]] <- met[["Precipitation_meterPerHour"]]
      }

    }else if(chck_met$time & chck_met$u10 & chck_met$v10 & chck_met$airt & chck_met$swr &
              chck_met$vap_p){
      forcing_mode <- 2

      sim_met <- sim_met[, c(l_names$time, l_names$u10, l_names$v10, l_names$airt, l_names$swr,
                             l_names$vap_p)]
      if(snow_module){
        sim_met[["Precipitation_meterPerHour"]] <- met[["Precipitation_meterPerHour"]]
      }

    }else if(chck_met$time & chck_met$u10 & chck_met$v10 & chck_met$airt & chck_met$swr){
      forcing_mode <- 1
      sim_met <- sim_met[, c(l_names$time, l_names$u10, l_names$v10, l_names$airt, l_names$swr)]
      if(snow_module){
        sim_met[["Precipitation_meterPerHour"]] <- met[["Precipitation_meterPerHour"]]
      }
    }else{
      stop(paste("Simstrat: There is not enough data to run the model in any forcing mode"))
    }

    # Set the forcing mode
    input_json(par_file, "ModelConfig", "Forcing", forcing_mode)

    #Reduce number of digits
    sim_met <- as.data.frame(sim_met)
    sim_met[, -1] <- signif(sim_met[, -1], 8)

    return(sim_met)
  }

##------------------------------- MyLake -----------------------------------------------------------

  if("MyLake" %in% model) {

    mylake_met <- met

    if(!chck_met$swr) {
      mylake_met[[l_names$swr]] <- 0
    }

    mylake_met <- mylake_met[, c(l_names$time,
                                 l_names$swr,
                                 l_names$cc,
                                 l_names$airt,
                                 l_names$relh,
                                 l_names$p_surf,
                                 l_names$wind_speed,
                                 l_names$precip)]


    # scale for units accepted in MyLake
    mylake_met[[l_names$swr]] <- mylake_met[[l_names$swr]] * 0.0864
    mylake_met[[l_names$p_surf]] <- mylake_met[[l_names$p_surf]] * 0.01
    mylake_met[[l_names$time]] <-
      as.matrix(floor((as.numeric(as.POSIXct(mylake_met[[l_names$time]])) / 86400) + 719529))

    return(mylake_met)
  }
}
