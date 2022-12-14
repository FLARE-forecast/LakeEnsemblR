#' Export LakeEnsemblR standardised inflow files to model specific driver format
#'
#' Export inflow driver files for each model
#'
#' @inheritParams export_config
#'
#' @examples
#' \dontrun{
#' export_inflow(config_file, model = c("GOTM", "GLM", "Simstrat", "FLake", "MyLake"))
#' }
#' @importFrom gotmtools calc_cc read_yaml set_yaml write_yaml get_yaml_value
#' @importFrom glmtools read_nml set_nml write_nml
#'
#' @export
export_inflow <- function(config_file, model = c("GOTM", "GLM", "Simstrat", "FLake", "MyLake")){

  # Load Rdata
  data("met_var_dic", package = "LakeEnsemblR", envir = environment())
  data("lake_var_dic", package = "LakeEnsemblR", envir = environment())

  if(!file.exists(config_file)) {
    stop(config_file, " does not exist. Make sure your file path is correct")
  } else {
    yaml <- gotmtools::read_yaml(config_file)
  }

  Sys.setenv(TZ = "GMT")

  # check model input
  model <- check_models(model)

##-------------Read settings---------------
  # Use inflows
  use_inflows <- gotmtools::get_yaml_value(yaml, "inflows", "use")
  # Use counter outflows
  use_outflows <- gotmtools::get_yaml_value(yaml, "inflows", "mass-balance")

  # Get start & stop dates
  start_date <- gotmtools::get_yaml_value(yaml, "time", "start")
  stop_date <- gotmtools::get_yaml_value(yaml, "time", "stop")

  # Get scaling parameter
  scale_param <- gotmtools::get_yaml_value(yaml, "inflows", "scale_param")

##---------------FLake-------------

  if("FLake" %in% model){
    fla_fil <- file.path(gotmtools::get_yaml_value(yaml, "config_files", "FLake"))

    if(!use_inflows){
      input_nml(fla_fil, label = "inflow", key = "Qfromfile",  ".false.")
    }else{
      input_nml(fla_fil, label = "inflow", key = "Qfromfile",  ".true.")
    }
  }

##---------------GLM-------------

  if("GLM" %in% model){
    glm_nml <- file.path(gotmtools::get_yaml_value(yaml, "config_files", "GLM"))

    # Read in nml and input parameters
    nml <- glmtools::read_nml(glm_nml)

    if(!use_inflows){
      inp_list <- list("num_inflows" = 0,
                       "num_outlet" = 0)
    }else{
      inp_list <- list("num_inflows" = 1,
                       "num_outlet" = 0,
                       "inflow_fl" = "inflow_file.csv")
    }

    nml <- glmtools::set_nml(nml, arg_list = inp_list)
    glmtools::write_nml(nml, glm_nml)

    if(use_outflows){
      nml_list <- list("num_outlet" = 1, "outflow_fl" = "outflow.csv")
      nml <- glmtools::set_nml(nml, arg_list = nml_list)
      glmtools::write_nml(nml, glm_nml)

      max_elv <- glmtools::get_nml_value(nml, "H")
      nml <- glmtools::set_nml(nml, arg_list = list("outl_elvs" = max(max_elv)))
      glmtools::write_nml(nml, glm_nml)

    }
  }

##---------------GOTM-------------

  if("GOTM" %in% model){
    got_file <- file.path(get_yaml_value(yaml, "config_files", "GOTM"))
    got_yaml <- gotmtools::read_yaml(got_file)

    ## Switch off streams
    if(!use_inflows){
      # streams_switch(file = got_yaml, method = "off")
      got_yaml <- gotmtools::set_yaml(got_yaml, key1 = "streams", key2 = "inflow", key3 = "flow", key4 =
                            "method", value = 0L)
      got_yaml <- gotmtools::set_yaml(got_yaml, key1 = "streams", key2 = "inflow", key3 = "temp", key4 =
                            "method", value = 0L)
      got_yaml <- gotmtools::set_yaml(got_yaml, key1 = "streams", key2 = "inflow", key3 = "salt", key4 =
                            "method", value = 0L)
      got_yaml <- gotmtools::set_yaml(got_yaml, key1 = "streams", key2 = "outflow", key3 = "flow", key4 =
                            "method", value = 0L)
      got_yaml <- gotmtools::set_yaml(got_yaml, key1 = "streams", key2 = "outflow", key3 = "temp", key4 =
                            "method", value = 0L)
      got_yaml <- gotmtools::set_yaml(got_yaml, key1 = "streams", key2 = "outflow", key3 = "salt", key4 =
                            "method", value = 0L)
    } else {
      # streams_switch(file = got_yaml, method = "on")
      got_yaml <- gotmtools::set_yaml(got_yaml, key1 = "streams", key2 = "inflow", key3 = "flow", key4 =
                            "method", value = 2L)
      got_yaml <- gotmtools::set_yaml(got_yaml, key1 = "streams", key2 = "inflow", key3 = "temp", key4 =
                            "method", value = 2L)
      got_yaml <- gotmtools::set_yaml(got_yaml, key1 = "streams", key2 = "inflow", key3 = "salt", key4 =
                            "method", value = 2L)
      got_yaml <- gotmtools::set_yaml(got_yaml, key1 = "streams", key2 = "outflow", key3 = "flow", key4 =
                            "method", value = 0L)
      got_yaml <- gotmtools::set_yaml(got_yaml, key1 = "streams", key2 = "outflow", key3 = "temp", key4 =
                            "method", value = 0L)
      got_yaml <- gotmtools::set_yaml(got_yaml, key1 = "streams", key2 = "outflow", key3 = "salt", key4 =
                            "method", value = 0L)
    }

    gotmtools::write_yaml(got_yaml, got_file)

  }

##---------------Simstrat-------------

  if("Simstrat" %in% model){
    sim_par <- file.path(gotmtools::get_yaml_value(yaml, "config_files", "Simstrat"))

    input_json(file = sim_par, label = "Input", key = "Inflow", value = "Qin.dat")
    input_json(file = sim_par, label = "Input", key = "Outflow", "Qout.dat")
    input_json(file = sim_par, label = "Input", key = "Inflow temperature", "Tin.dat")
    input_json(file = sim_par, label = "Input", key = "Inflow salinity", "Sin.dat")


    # Turn off inflow
    if(!use_inflows){
      input_json(file = sim_par, label = "ModelConfig", key = "InflowMode", value = 0)
      ## Set Qin and Qout to 0 inflow
      inflow_line_1 <- "Time [d]\tQ_in [m3/s]"
      # In case Kw is a single value for the whole simulation:
      inflow_line_2 <- "1 0"
      inflow_line_3 <- "-1 0.00"
      start_sim <- get_json_value(sim_par, "Simulation", "Start d")
      end_sim <- get_json_value(sim_par, "Simulation", "End d")
      inflow_line_4 <- paste(start_sim, 0.000)
      inflow_line_5 <- paste(end_sim, 0.000)

      file_connection <- file("Simstrat/Qin.dat")
      writeLines(c(inflow_line_1, inflow_line_2, inflow_line_3, inflow_line_4, inflow_line_5),
                 file_connection)
      close(file_connection)
      file_connection <- file("Simstrat/Qout.dat")
      writeLines(c(inflow_line_1, inflow_line_2, inflow_line_3, inflow_line_4, inflow_line_5),
                 file_connection)
      close(file_connection)
    }else{
      input_json(file = sim_par, label = "ModelConfig", key = "InflowMode", value = 2)
      inflow_line_1 <- "Time [d]\tQ_in [m3/s]"
      # In case Kw is a single value for the whole simulation:
      inflow_line_2 <- "1 0"
      inflow_line_3 <- "-1 0.00"
      start_sim <- get_json_value(sim_par, "Simulation", "Start d")
      end_sim <- get_json_value(sim_par, "Simulation", "End d")
      inflow_line_4 <- paste(start_sim, 0.000)
      inflow_line_5 <- paste(end_sim, 0.000)

      file_connection <- file("Simstrat/Qout.dat")
      writeLines(c(inflow_line_1, inflow_line_2, inflow_line_3, inflow_line_4, inflow_line_5),
                 file_connection)
      close(file_connection)
    }

  }

##---------------MyLake-------------

  if("MyLake" %in% model){
    # Load config file MyLake
    load(gotmtools::get_yaml_value(yaml, "config_files", "MyLake"))

    if(!use_inflows){
      mylake_config[["Inflw"]] <- matrix(rep(0, 8 * length(seq.POSIXt(from = as.POSIXct(start_date),
                                                                    to = as.POSIXct(stop_date),
                                                                    by = "day"))),
                                         ncol = 8)

      # save lake-specific config file for MyLake
      temp_fil <- gsub(".*/", "", gotmtools::get_yaml_value(yaml, "config_files", "MyLake"))
      save(mylake_config, file = file.path("MyLake", temp_fil))
    }
  }

##-------------If inflow == TRUE---------------

  if(use_inflows == TRUE){

    inflow_file <- gotmtools::get_yaml_value(yaml, label = "inflows", key = "file")
    # Check if file exists
    if(!file.exists(inflow_file)){
      stop(inflow_file, " does not exist. Check filepath in ", yaml)
    }

    ### Import data
    message("Loading inflow data...")
    suppressMessages({
      inflow <- read.csv(file.path(inflow_file))
    })
    inflow[["datetime"]] <- as.POSIXct(inflow[["datetime"]])
    # Check time step
    tstep <- diff(as.numeric(inflow[["datetime"]]))

    start_date <- gotmtools::get_yaml_value(yaml, "time", "start")
    # Stop date
    stop_date <- gotmtools::get_yaml_value(yaml, "time", "stop")

    inflow_start <- which(inflow$datetime == as.POSIXct(start_date))
    inflow_stop <- which(inflow$datetime == as.POSIXct(stop_date)) + 1

    inflow <- inflow[inflow_start:inflow_stop, ]

    ### Naming conventions standard input
    # test if names are right
    chck_inflow <- sapply(list(colnames(inflow)), function(x) x %in% lake_var_dic$standard_name)
    if(any(!chck_inflow)){
      chck_inflow[which(chck_inflow == FALSE)] <- sapply(list(colnames(inflow[which(
        chck_inflow == FALSE)])), function(x) x %in% met_var_dic$standard_name)

      if(any(!chck_inflow)){
        stop("Colnames of inflow file are not in standard notation! ",
                    "They should be one of: \ndatetime\nFlow_metersCubedPerSecond\n",
                    "Water_Temperature_celsius\nSalinity_practicalSalinityUnits")
      }
    }

    ### Apply scaling
    inflow[["Flow_metersCubedPerSecond"]] <- inflow[["Flow_metersCubedPerSecond"]] * scale_param

    # FLake
    #####
    if("FLake" %in% model){

      flake_inflow <- format_inflow(inflow = inflow, model = "FLake", config_file = config_file)

      flake_outfile <- "Tinflow"

      flake_outfpath <- file.path("FLake", flake_outfile)

      # Write to file
      write.table(flake_inflow, flake_outfpath, quote = FALSE, row.names = FALSE, sep = "\t",
                  col.names = FALSE)
      temp_fil <- gotmtools::get_yaml_value(yaml, "config_files", "FLake")
      input_nml(temp_fil, label = "inflow", key = "time_step_number", nrow(flake_inflow))

      message("FLake: Created file ", file.path("FLake", flake_outfile))

      if(use_outflows){
        message("FLake does not need outflows, as mass fluxes are not considered.")
      }

    }

    # GLM
    #####
    if("GLM" %in% model){
      glm_inflow <- format_inflow(inflow = inflow, model = "GLM", config_file = config_file)

      inflow_outfile <- file.path("GLM", "inflow_file.csv")

      # Write to file
      write.csv(glm_inflow, inflow_outfile, row.names = FALSE, quote = FALSE)
      message("GLM: Created file ", file.path("GLM", "inflow_file.csv"))

      glm_outflow <- glm_inflow[, c("Time", "FLOW")]
      outflow_outfile <- file.path("GLM", "outflow.csv")
      write.csv(glm_outflow, outflow_outfile, row.names = FALSE, quote = FALSE)

      message("GLM: Created outflow file ", file.path("GLM", "outflow.csv"))
      }


    ## GOTM
    if("GOTM" %in% model){

      got_file <- file.path(gotmtools::get_yaml_value(yaml, "config_files", "GOTM"))
      got_yaml <- gotmtools::read_yaml(got_file)

      gotm_outfile <- "inflow_file.dat"

      gotm_outfpath <- file.path("GOTM", gotm_outfile)

      gotm_inflow <- format_inflow(inflow, model = "GOTM", config_file = config_file)

      # Write to file
      write.table(gotm_inflow, gotm_outfpath, quote = FALSE, row.names = FALSE, sep = "\t",
                  col.names = TRUE)

      message("GOTM: Created file ", file.path("GOTM", gotm_outfile))

      if(use_outflows){
        temp_fil <- gotmtools::get_yaml_value(yaml, "config_files", "GOTM")
        got_file <- file.path(temp_fil)
        got_yaml <- gotmtools::read_yaml(got_file)
        got_yaml <- gotmtools::set_yaml(got_yaml, key1 = "streams", key2 = "outflow", key3 = "flow",
                             key4 = "method", value = 2L)
        got_yaml <- gotmtools::set_yaml(got_yaml, key1 = "streams", key2 = "outflow", key3 = "temp",
                             key4 = "method", value = 0L)
        got_yaml <- gotmtools::set_yaml(got_yaml, key1 = "streams", key2 = "outflow", key3 = "salt",
                             key4 = "method", value = 0L)

        gotm_outflow <- gotm_inflow[, c(1:2)]
        gotm_outflow[,2] <- gotm_outflow[,2] * -1
        gotm_outflowfile <- "outflow_file.dat"
        gotm_outflowfpath <- file.path("GOTM", gotm_outflowfile)

        write.table(gotm_outflow, gotm_outflowfpath, quote = FALSE, row.names = FALSE, sep = "\t",
                    col.names = TRUE)

        gotmtools::write_yaml(got_yaml, got_file)

        message("GOTM: Created outflow file ", file.path("GOTM", gotm_outflowfile))
      }

    }

    ## Simstrat
    if("Simstrat" %in% model){

      inflow_outfile <- "Qin.dat"
      temp_outfile <- "Tin.dat"
      salt_outfile <- "Sin.dat"
      par_file <- file.path(gotmtools::get_yaml_value(yaml, "config_files", "Simstrat"))

      inflow_outfpath <- file.path("Simstrat", inflow_outfile)
      temp_outfpath <- file.path("Simstrat", temp_outfile)
      salt_outfpath <- file.path("Simstrat", salt_outfile)

      sim_inflow <- format_inflow(inflow = inflow, model = "Simstrat", config_file = config_file)

      ## Set Qin and Qout to 0 inflow
      inflow_line_1 <- "Time [d]\tQ_in [m3/s]"
      inflow_line_2 <- "1"
      inflow_line_3 <- "-1 0.00"
      inflow_line_4 <- paste(seq_len(length(sim_inflow$datetime)), sim_inflow$Flow_metersCubedPerSecond)
      file_connection <- file(inflow_outfpath)
      writeLines(c(inflow_line_1, inflow_line_2, inflow_line_3, inflow_line_4),
                 file_connection)
      close(file_connection)

      inflow_line_1 <- "Time [d]\tT_in [degC]"
      inflow_line_4 <- paste(seq_len(length(sim_inflow$datetime)), sim_inflow$Water_Temperature_celsius)
      file_connection <- file(temp_outfpath)
      writeLines(c(inflow_line_1, inflow_line_2, inflow_line_3, inflow_line_4),
                 file_connection)
      close(file_connection)

      inflow_line_1 <- "Time [d]\tS_in [perMille]"
      inflow_line_4 <- paste(seq_len(length(sim_inflow$datetime)), sim_inflow$Salinity_practicalSalinityUnits)
      file_connection <- file(salt_outfpath)
      writeLines(c(inflow_line_1, inflow_line_2, inflow_line_3, inflow_line_4),
                 file_connection)
      close(file_connection)

      message("Simstrat: Created file ", file.path("Simstrat", inflow_outfile))

      if(use_outflows){
        outflow_outfile <- "Qout.dat"
        par_file <- file.path(gotmtools::get_yaml_value(yaml, "config_files", "Simstrat"))

        outflow_outfpath <- file.path("Simstrat", outflow_outfile)

        sim_inflow$Flow_metersCubedPerSecond <- sim_inflow$Flow_metersCubedPerSecond * (- 1)

        inflow_line_1 <- "Time [d]\tQ_in [m3/s]"
        inflow_line_2 <- "1"
        inflow_line_3 <- "-1 0.00"
        inflow_line_4 <- paste(seq_len(length(sim_inflow$datetime)), sim_inflow$Flow_metersCubedPerSecond)
        file_connection <- file(outflow_outfpath)
        writeLines(c(inflow_line_1, inflow_line_2, inflow_line_3, inflow_line_4),
                   file_connection)
        close(file_connection)

        message("Simstrat: Created outflow file ", file.path("Simstrat", outflow_outfile))
      }
    }

    ## MyLake
    if("MyLake" %in% model){

      temp_fil <- gotmtools::get_yaml_value(yaml, "config_files", "MyLake")
      load(temp_fil)

      mylake_inflow <- format_inflow(inflow = inflow, model = "MyLake", config_file = config_file)

      # discharge [m3/d], temperature [deg C], conc of passive tracer [-], conc of passive
      # sediment tracer [-], TP [mg/m3], DOP [mg/m3], Chla [mg/m3], DOC [mg/m3]
      dummy_inflow <- matrix(rep(1e-10, 8 *
                                   length(seq.POSIXt(from = as.POSIXct(start_date),
                                                            to = (as.POSIXct(stop_date) + 1*24*60*60),
                                                            by = "day"))),
                             ncol = 8)
      dummy_inflow[, 1] <- mylake_inflow$Flow_metersCubedPerDay
      dummy_inflow[, 2] <- mylake_inflow$Water_Temperature_celsius
      dummy_inflow[, 5] <- dummy_inflow[, 5] * 1e7
      dummy_inflow[, 6] <- dummy_inflow[, 6] * 1e1


      mylake_config[["Inflw"]] <- dummy_inflow

      temp_fil <- gsub(".*/", "", temp_fil)
      # save lake-specific config file for MyLake
      save(mylake_config, file = file.path("MyLake", temp_fil))

      message("MyLake: Created file ", file.path("MyLake", temp_fil))

      if(use_outflows){
        message("MyLake does not need specific outflows, as it employs automatic overflow.")
      }
    }
  }

  message("export_inflow complete!")
}
