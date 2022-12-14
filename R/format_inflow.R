#' Format inflow data for each model
#'@description
#' Format dataframe into shape for the specified model
#'
#' @name format_inflow
#' @param inflow dataframe; as read.csv() from standardised input.
#' @param model character; Model for which scaling parameters will be applied. Options include
#'    c('GOTM', 'GLM', 'Simstrat', 'FLake')
#' @param config_file filepath; To LER config yaml file. Only used if model = 'GOTM'
#' @importFrom gotmtools read_yaml set_yaml write_yaml get_yaml_value
#' @return dataframe of met data in the model format
#' @export
format_inflow <- function(inflow, model, config_file){

  if(!file.exists(file.path(config_file))) {
    stop(paste0(file.path(config_file), " does not exist. Make sure your file path is correct"))
  } else {
    yaml <- read_yaml(config_file)
  }

  # Load Rdata
  data("lake_var_dic", package = "LakeEnsemblR", envir = environment())

  lat <- get_yaml_value(yaml, label = "location", key = "latitude")
  lon <- get_yaml_value(yaml, label = "location", key = "longitude")
  elev <- get_yaml_value(yaml, label = "location", key = "elevation")

  ### Check what inflow data is available, as this determines what model forcing option to use
  chck_inflow <- sapply(lake_var_dic$standard_name, function(x) x %in% colnames(inflow))
  names(chck_inflow) <- lake_var_dic$short_name

  ## list with long standard names
  l_names <- as.list(lake_var_dic$standard_name)
  names(l_names) <- lake_var_dic$short_name

  hyp_file <- get_yaml_value(yaml, "location", "hypsograph")
  if(!file.exists(hyp_file)){
    stop(hyp_file, " does not exist. Check filepath in ", config_file)
  }
  suppressMessages({
    hyp <- read.csv(hyp_file)
  })

  if("FLake" %in% model){

    flake_inflow <- inflow

    flake_inflow <- flake_inflow[, c("Flow_metersCubedPerSecond",
                                 "Water_Temperature_celsius")]

    colnames(flake_inflow) <- c("FLOW", "TEMP")

    flake_inflow[, 1] <- (flake_inflow[, 1]) / max(hyp)

    #Reduce number of digits
    flake_inflow <- signif(flake_inflow, digits = 8)

    return(flake_inflow)

  }

  if("GLM" %in% model){

    glm_inflow <- inflow

    glm_inflow <- glm_inflow[, c("datetime", "Flow_metersCubedPerSecond",
                           "Water_Temperature_celsius",
                           "Salinity_practicalSalinityUnits")]

    colnames(glm_inflow) <- c("Time", "FLOW", "TEMP", "SALT")
    glm_inflow <- as.data.frame(glm_inflow)
    glm_inflow[, 1] <- format(glm_inflow[, 1], format = "%Y-%m-%d %H:%M:%S")

    #Reduce number of digits
    glm_inflow[, -1] <- signif(glm_inflow[, -1], digits = 8)

    return(glm_inflow)
  }

  if("GOTM" %in% model){

    gotm_inflow <- inflow

    gotm_inflow <- gotm_inflow[, c("datetime", "Flow_metersCubedPerSecond",
                                 "Water_Temperature_celsius",
                                 "Salinity_practicalSalinityUnits")]

    colnames(gotm_inflow)[1] <- paste0("!", colnames(gotm_inflow)[1])
    gotm_inflow <- as.data.frame(gotm_inflow)
    gotm_inflow[, 1] <- format(gotm_inflow[, 1], "%Y-%m-%d %H:%M:%S")

    #Reduce number of digits
    gotm_inflow[, -1] <- signif(gotm_inflow[, -1], digits = 8)

    return(gotm_inflow)
  }

  if("Simstrat" %in% model){

    simstrat_inflow <- inflow

    simstrat_inflow <- simstrat_inflow[, c("datetime", "Flow_metersCubedPerSecond",
                                   "Water_Temperature_celsius",
                                   "Salinity_practicalSalinityUnits")]
    simstrat_inflow <- as.data.frame(simstrat_inflow)

    simstrat_inflow[, 1] <- format(simstrat_inflow[, 1], "%Y-%m-%d %H:%M:%S")

    #Reduce number of digits
    simstrat_inflow[, -1] <- signif(simstrat_inflow[, -1], digits = 8)

    return(simstrat_inflow)
  }

  if("MyLake" %in% model) {

    mylake_inflow <- inflow

    mylake_inflow <- mylake_inflow[, c("datetime", "Flow_metersCubedPerSecond",
                                           "Water_Temperature_celsius",
                                           "Salinity_practicalSalinityUnits")]

    mylake_inflow$Flow_metersCubedPerDay <- mylake_inflow$Flow_metersCubedPerSecond * (86400.)
    mylake_inflow <- as.data.frame(mylake_inflow)

    mylake_inflow[, 1] <- format(mylake_inflow[, 1], "%Y-%m-%d %H:%M:%S")

    #Reduce number of digits
    mylake_inflow[, -1] <- signif(mylake_inflow[, -1], digits = 8)

    return(mylake_inflow)
  }
}
