#'Creates directories for each model
#'
#'Creates directories with file setups for each model, based on the master LakeEnsemblR config file
#'
#' @inheritParams export_config
#'@keywords methods
#' @importFrom gotmtools read_yaml
#'@examples
#'
#'
#'@export

export_dirs <- function(config_file, model = c("GOTM", "GLM", "Simstrat", "FLake", "MyLake")){

  if(!file.exists(config_file)) {
    stop(config_file, " does not exist. Make sure your file path is correct")
  } else {
    yaml <- gotmtools::read_yaml(config_file)
  }

  # check model input
  model <- check_models(model)

##---------------FLake-------------
  if("FLake" %in% model){
    # Create directory and output directory, if they do not yet exist
    if(!dir.exists("FLake")){
      dir.create("FLake")
    }
    if(!dir.exists("FLake/output")){
      dir.create("FLake/output")
    }

    # Read the FLake config file from config_file, and write it to the FLake directory
    temp_fil <- get_yaml_value(yaml, "config_files", "FLake")
    if(!file.exists(temp_fil)){
      template_file <- system.file("extdata/flake_template.nml", package = packageName())
      file.copy(from = template_file,
                to = file.path(temp_fil))
    }
  }

##---------------GLM-------------
  if("GLM" %in% model){
    # Create directory and output directory, if they do not yet exist
    if(!dir.exists("GLM/output")){
      dir.create("GLM/output", recursive = TRUE)
    }

    # Read the GLM config file from yaml, and write it to the GLM directory
    temp_fil <- get_yaml_value(yaml, "config_files", "GLM")

    if(!file.exists(temp_fil)){
      template_file <- system.file("extdata/glm3_template.nml", package = "LakeEnsemblR")
      file.copy(from = template_file,
                to = file.path(temp_fil))
    }
  }

##---------------GOTM-------------
  if("GOTM" %in% model){
    # Create directory and output directory, if they do not yet exist
    if(!dir.exists("GOTM/output")){
      dir.create("GOTM/output", recursive = TRUE)
    }

    # Read the GOTM config file from yaml, and write it to the GOTM directory
    temp_fil <- gotmtools::get_yaml_value(yaml, "config_files", "GOTM")
    if(!file.exists(temp_fil)){
      template_file <- system.file("extdata/gotm_template.yaml", package = packageName())
      file.copy(from = template_file,
                to = file.path(temp_fil))

      template_file <- system.file("extdata/restart.nc", package = packageName())
      file.copy(from = template_file,
                to = file.path("GOTM/restart.nc"))
    }
  }

##---------------Simstrat-------------
  if("Simstrat" %in% model){
    # Create directory and output directory, if they do not yet exist
    if(!dir.exists("Simstrat/output")){
      dir.create("Simstrat/output", recursive = TRUE)
    }

    # Read the Simstrat config file from yaml, and write it to the Simstrat directory
    temp_fil <- get_yaml_value(yaml, "config_files", "Simstrat")
    if(!file.exists(temp_fil)){
      template_file <- system.file("extdata/simstrat_template.par", package = packageName())
      file.copy(from = template_file,
                to = file.path(temp_fil))
    }

    # Copy in template files from examples folder in the package
    qin_fil <- system.file("extdata/simstrat_files/Qin.dat", package = packageName())
    qout_fil <- system.file("extdata/simstrat_files/Qout.dat", package = packageName())
    tin_fil <- system.file("extdata/simstrat_files/Tin.dat", package = packageName())
    sin_fil <- system.file("extdata/simstrat_files/Sin.dat", package = packageName())
    file.copy(from = qin_fil, to = file.path("Simstrat", "Qin.dat"))
    file.copy(from = qout_fil, to = file.path("Simstrat", "Qout.dat"))
    file.copy(from = tin_fil, to = file.path("Simstrat", "Tin.dat"))
    file.copy(from = sin_fil, to = file.path("Simstrat", "Sin.dat"))
  }

##---------------MyLake-------------
  if("MyLake" %in% model){
    # Create directory and output directory, if they do not yet exist
    if(!dir.exists("MyLake")){
      dir.create("MyLake")
    }

    # Load config file MyLake
    temp_fil <- get_yaml_value(yaml, "config_files", "MyLake")
    if(!file.exists(temp_fil)){
      # Load template config file from extdata
      mylake_path <- system.file(package = "LakeEnsemblR")
      load(file.path(mylake_path, "extdata", "mylake_config_template.Rdata"))

      temp_fil <- gsub(".*/", "", temp_fil)
      # save lake-specific config file for MyLake
      save(mylake_config, file = file.path("MyLake", temp_fil))
    }
  }

  message("export_dirs complete!")
}
