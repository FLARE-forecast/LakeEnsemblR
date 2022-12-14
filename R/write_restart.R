#' Write model restart variables
#'
#' Write model restart variables using the list from `read_restart()`
#'
#'@param folder folder
#'@param model string; denoting which model you are extracting from. Can be 'GLM', 'GOTM', 'Simstrat'
#'@examples
#'
#'
#'@importFrom ncdf4 nc_open ncvar_put
#'@importFrom glmtools read_nml set_nml write_nml
#'
#'@export

write_restart <- function(folder = ".", model, restart_list) {

  # GLM ----
  if(model == "GLM") {

    nml_file <- file.path(folder, model, "glm3.nml")
    if(!file.exists(nml_file)) {
      stop("No 'glm3.nml' file in ", folder)
    }
    nml <- glmtools::read_nml(nml_file)

    for(i in seq_len(length(restart_list))) {
      nml <- glmtools::set_nml(nml, names(restart_list)[i], restart_list[[i]])
    }

    lapply(seq_len(length(restart_list)), function(x) {
    })
    glmtools::write_nml(nml, nml_file)
  }

  # GOTM ----
  if(model == "GOTM") {

    z_var_names <- list("z", "temp", "salt", "u", "uo", "v", "vo", "xP", "h", "ho")
    zi_var_names <- list("tke", "zi", "tkeo", "eps", "num", "nuh", "nus")

    outfile <- file.path(folder, model, "restart.nc")
    if(!file.exists(outfile)) {
      stop(outfile, " does not exist!")
    }
    yaml_file <- file.path(folder, model, "gotm.yaml")
    yaml <- gotmtools::read_yaml(yaml_file)
    yaml$restart$load <- TRUE
    gotmtools::write_yaml(yaml, yaml_file)

    nc <- ncdf4::nc_open(outfile, write = TRUE)
    on.exit({
      ncdf4::nc_close(nc)
    })

    lapply(z_var_names, function(x) {
      nc <- ncdf4::ncvar_put(nc = nc, varid = x, vals = restart_list$z_vars[[x]])
    })
    lapply(zi_var_names, function(x) {
      nc <- ncdf4::ncvar_put(nc = nc, varid = x, vals = restart_list$zi_vars[[x]])
    })
  }

  # Simstrat ----
  if(model == "Simstrat") {

    par_file <- file.path(folder, model, "simstrat.par")
    if(!file.exists(par_file)) {
      stop("No 'simstrat.par' file in ", folder)
    }
    out_dir <- get_json_value(par_file, "Output", "Path")
    output_folder <- file.path(folder, model, out_dir)
    init_cond_file <- file.path(folder, model, "save_end_conditions.dat")
    init_cond <- do.call(cbind, restart_list[1:9])

    colnames(init_cond) <- c("depth (m) ", "u (m/s)   ", "v (m/s)   ", "T (????C)   ", "S (g/kg)  ", "k (J/kg)  ", "eps (W/kg)", "num (wwww)", "nuh (wwww)")

    write.csv(init_cond, init_cond_file, row.names = FALSE, quote = TRUE)

    init_cond_name <- "save_end_conditions.dat"

    arg_list <- list("Initial conditions" = init_cond_name,
                     "Use text restart" = TRUE,
                     "seiche_ini" = restart_list$seicheE,
                     "b_ice_ini" = restart_list$b_ice,
                     "w_ice_ini" = restart_list$w_ice,
                     "snow_ini" = restart_list$snow)
    input_json(file = par_file, arg_list = arg_list)
  }
}
