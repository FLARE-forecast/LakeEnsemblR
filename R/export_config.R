#' Export model configuration setups
#'
#' Exports all settings from the master LakeEnsemblR config file
#'
#' @param config_file name of the master LakeEnsemblR config file
#' @param model vector; model to export configuration file for.
#'   Options include c("GOTM", "GLM", "Simstrat", "FLake", "MyLake")
#' @param dirs boolean; create directories for each model and if needed copies
#'  templates.
#'   Calls export_dirs. Defaults to TRUE
#' @param time boolean; exports time settings. Calls export_time. Defaults to TRUE.
#' @param location boolean; exports location and hypsograph settings.
#'   Calls export_location. Defaults to TRUE.
#' @param output_settings boolean; exports output settings.
#'   Calls export_output_settings. Defaults to TRUE.
#' @param meteo boolean; export meteorology data.
#'   Calls export_meteo. Defaults to TRUE.
#' @param init_cond boolean; export initial conditions.
#'   Calls export_init_cond. Defaults to TRUE.
#' @param extinction boolean; export light extinction data.
#'   Calls export_extinction. Defaults to TRUE.
#' @param inflow boolean; export inflow settings.
#'  Calls export_inflow. Defaults to TRUE.
#' @param model_parameters boolean; export model parameters specificed in the yaml
#'  configuration file. Calls export_model_parameters. Defaults to TRUE.
#' @param print Boolean; print initial conditions to console. Deafaults to TRUE
#' @param folder filepath; to folder which contains the model folders generated
#' by export_config()
#' @keywords methods
#' @author
#' Tadhg Moore, Jorrit Mesman, Johannes Feldbauer, Robert Ladwig
#' @examples
#'
#' @export

export_config <- function(config_file, model = c("GOTM", "GLM", "Simstrat", "FLake", "MyLake"),
                          dirs = TRUE, time = TRUE, location = TRUE,
                          output_settings = TRUE, meteo = TRUE, init_cond = TRUE,
                          extinction = TRUE, inflow = TRUE, model_parameters = TRUE,
                          print = TRUE, folder = "."){

  # Set working directory
  oldwd <- getwd()
  setwd(folder)

  # Fix time zone
  original_tz <- Sys.getenv("TZ")

  # this way if the function exits for any reason, success or failure, these are reset:
  on.exit({
    setwd(oldwd)
    Sys.setenv(TZ = original_tz)
  })

  Sys.setenv(TZ = "GMT")

  # Check if config file exists
  if(!file.exists(config_file)){
    stop(config_file, " does not exist.")
  }

  # check the master config file
  check_master_config(config_file, model = model, folder = folder, exp_cnf = TRUE)
  # check model input
  model <- check_models(model)

##--------------------- Export sub-functions ---------------
  # Export directories and copy template files
  if(dirs){
    export_dirs(config_file = config_file, model = model)
  }

  # Export time settings (start, stop, time step)
  if(time){
    export_time(config_file = config_file, model = model)
  }

  # Export hypsograph, lat/lon, ice
  if(location){
    export_location(config_file = config_file, model = model)
  }

  # Export output_settings (depth and time intervals)
  if(output_settings){
    export_output_settings(config_file = config_file, model = model)
  }

  # Export meteo
  if(meteo){
    export_meteo(config_file = config_file, model = model)
  }

  # Export initial conditions
  if(init_cond){
    export_init_cond(config_file = config_file, model = model, print = print)
  }

  # Export light extinction (Kw)
  if(extinction){
    export_extinction(config_file = config_file, model = model)
  }

  # Export user-defined inflow boundary condition
  if(inflow){
    export_inflow(config_file = config_file, model = model)
  }

  # Export user-defined model-specific parameters
  if(model_parameters){
    export_model_parameters(config_file = config_file, model = model)
  }
}
