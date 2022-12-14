#' Export initial conditions into each model setup from the LakeEnsemblR standardized input for observed temperature profile
#'
#' Export initial condition files and input into model configuration files.
#'
#' @name export_init_cond
#' @inheritParams export_config
#' @param date character; Date in "YYYY-mm-dd HH:MM:SS" format to extract the initial profile.
#' If NULL, the observations file specified in config_file is used to extract
#' the date.
#' @param print logical; Prints the temperature profile to the console
#'
#' @importFrom glmtools read_nml set_nml write_nml get_nml_value
#' @importFrom gotmtools read_yaml set_yaml write_yaml get_yaml_value
#'
#' @export

export_init_cond <- function(config_file,
                             model = c("GOTM", "GLM", "Simstrat", "FLake", "MyLake"),
                             date = NULL, print = TRUE){

  if(!file.exists(config_file)) {
    stop(config_file, " does not exist. Make sure your file path is correct")
  } else {
    yaml <- gotmtools::read_yaml(config_file)
  }

  Sys.setenv(TZ = "GMT")

  # check model input
  model <- check_models(model)

  if(is.null(date)) {
    date <- get_yaml_value(yaml, "time", "start")
  }

  # Here check if config_file, "initial_profile:" is empty or not
  init_temp_file <- get_yaml_value(yaml, "input", "init_temp_profile", "file")
  if(is.null(init_temp_file)){
    # If no initial temperature profile is given, read in the observations and
    # extract initial profile from there

    wtemp_file <- get_yaml_value(yaml, "observations", "temperature", "file")

    if(is.null(wtemp_file)){
      stop("Neither an initial temperature profile, nor an observations file is provided!")
    }

    message(paste0("Loading wtemp_file... [", Sys.time(), "]"))
    suppressMessages({
      obs <- read.csv(wtemp_file)
    })
    message(paste0("Finished loading wtemp_file! [", Sys.time(), "]"))


    # Check if date is in observations
    if(!date %in% obs[["datetime"]]){
      stop(paste(date, "is not found in observations file. Cannot initialise water temperature!"))
    }

    dat <- which(obs[, 1] == date)
    ndeps <- length(dat)
    deps <- unlist(as.vector(obs[dat, 2]))
    tmp <- unlist(as.vector(obs[dat, 3]))
  } else {
    # Read in the provided initial temperature profile
    suppressMessages({
      init_prof <- read.csv(get_yaml_value(yaml, "input", "init_temp_profile", "file"))
    })
    init_prof <- as.data.frame(init_prof)
    ndeps <- nrow(init_prof)
    deps <- init_prof[, 1]
    tmp <- init_prof[, 2]
  }

  deps <- signif(deps, 4)
  tmp <- signif(tmp, 4)
  df_print <- data.frame(depths = deps, wtemp = tmp, row.names = NULL)

  # Do a test to see if the maximum depth in the initial profile
  # exceeds the maximum depth of the lake. If so, throw an error
  if(max(deps) > get_yaml_value(yaml, "location", "depth")){
    stop("Maximum depth in initial profile exceeds lake depth: ",
         get_yaml_value(yaml, "location", "depth"), " m")
  }

  # FLake
  #####
  if("FLake" %in% model){
    # Input values to nml
    nml_file <- get_yaml_value(yaml, "config_files", "FLake")

    nml <- glmtools::read_nml(nml_file)

    nml <- glmtools::set_nml(nml, "T_wML_in", tmp[which.min(deps)])
    nml <- glmtools::set_nml(nml, "T_bot_in", tmp[which.min(deps)])

    depth <- glmtools::get_nml_value(nml_file = nml_file, arg_name = "depth_w_lk")
    hmix <- calc_hmix(tmp, deps)
    if(!is.na(hmix) & hmix < depth) {
      nml <- glmtools::set_nml(nml, "SIMULATION_PARAMS::h_ML_in", round(hmix, 2))
    } else {
      nml <- glmtools::set_nml(nml, "SIMULATION_PARAMS::h_ML_in", depth)
    }

    message("FLake: Input initial conditions into ",
            file.path(get_yaml_value(yaml, "config_files", "FLake")),
            " [", Sys.time(), "]")

  }

  # GLM
  #####
  if("GLM" %in% model){

    # Input to nml file
    nml <- read_nml(get_yaml_value(yaml, "config_files", "GLM"))

    nml_list <- list("num_depths" = ndeps, "the_depths" = deps,
                     "the_temps" = tmp, "the_sals" = rep(0, length(tmp)))
    nml <- set_nml(nml, arg_list = nml_list)
    # check for max(the_depths) > lake_depth ??
    write_nml(nml, get_yaml_value(yaml, "config_files", "GLM"))
    message("GLM: Input initial conditions into ",
            file.path(get_yaml_value(yaml, "config_files", "GLM")),
            " [", Sys.time(), "]")

  }

  ## GOTM
  if("GOTM" %in% model){
    got_file <- get_yaml_value(yaml, "config_files", "GOTM")
    got_yaml <- read_yaml(got_file)

    df <- matrix(NA, nrow = 1 + ndeps, ncol = 2)
    df[1, 1] <- date
    df[1, 2] <- paste(ndeps, " ", 2)
    df[(2):(1 + ndeps), 1] <- as.numeric(-deps)
    df[(2):(1 + ndeps), 2] <- as.numeric(tmp)
    df <- as.data.frame(df)
    write.table(df, file.path("GOTM", "init_cond.dat"),
                quote = FALSE, row.names = FALSE, col.names = FALSE, sep = "\t")

    got_yaml <- set_yaml(got_yaml, label = "temperature", key = "file", value = "init_cond.dat")
    got_yaml <- set_yaml(got_yaml, label = "temperature", key = "method", value = 2L)
    got_yaml <- set_yaml(got_yaml, label = "temperature", key = "column", value = 1L)

    message("GOTM: Created initial conditions file ", file.path("GOTM", "init_cond.dat"),
            " [", Sys.time(), "]")

  }

  ## Simstrat
  if("Simstrat" %in% model){
    df2 <- data.frame("Depth [m]" = -deps, "U [m/s]" = 0, 	"V [m/s]" = 0,
                      "T [deg C]" = tmp,	"k [J/kg]" = 3e-6,	"eps [W/kg]" = 5e-10)
    colnames(df2) <- c("Depth [m]",	"U [m/s]",	"V [m/s]",	"T [deg C]",	"k [J/kg]",	"eps [W/kg]")

    write.csv(df2, file.path("Simstrat", "init_cond.dat"), row.names = FALSE)

    par_file <- get_yaml_value(yaml, "config_files", "Simstrat")

    input_json(par_file, "Input", "Initial conditions", "init_cond.dat")

    message("Simstrat: Created initial conditions file ",
            file.path("Simstrat", "init_cond.dat"),
            " [", Sys.time(), "]")

  }

  ## MyLake
  if("MyLake" %in% model){

    load(get_yaml_value(yaml, "config_files", "MyLake"))

    mylake_init <- list()

    # configure initial depth profile
    deps_Az <- data.frame("Depth_meter" = mylake_config[["In.Z"]],
                          "Az" = mylake_config[["In.Az"]])

    # configure initial temperature profile
    # depth MUST match those from hyposgraph -- interpolate here as needed
    temp_interp1 <- dplyr::full_join(deps_Az,
                                     data.frame("Depth_meter" = deps,
                                                "Water_Temperature_celsius" = tmp),
                                     by = c("Depth_meter"))

    temp_interp2 <- dplyr::arrange(temp_interp1, Depth_meter)

    temp_interp3 <- dplyr::mutate(temp_interp2,
                                  TempInterp = approx(x = Depth_meter,
                                                    y = Water_Temperature_celsius,
                                                    xout = Depth_meter,
                                                    yleft = dplyr::first(na.omit(Water_Temperature_celsius)),
                                                    yright = dplyr::last(na.omit(Water_Temperature_celsius)))$y)

    temp_interp <- dplyr::filter(temp_interp3, !is.na(Az))

    # fill in depths and temperature in iniital profile RData file
    mylake_init[["In.Tz"]] <- as.matrix(temp_interp$TempInterp)

    mylake_init[["In.Z"]] <- as.matrix(temp_interp$Depth_meter)

    # save initial profile data
    save(mylake_init, file = file.path("MyLake", "mylake_init.Rdata"))

    # update config parameter with initial depth differences
    # mylake_config[["Phys.par"]][1]=median(diff(mylake_init$In.Z))

    # save revised config file
    cnf_name <- gsub(".*/", "", get_yaml_value(yaml, "config_files", "MyLake"))
    save(mylake_config, file = file.path("MyLake", cnf_name))

    message("MyLake: Created initial conditions file ",
            file.path("MyLake", cnf_name),
            " [", Sys.time(), "]")

  }

  if(print == TRUE){
    print(df_print)
  }

  message("export_init_cond complete!")
}
