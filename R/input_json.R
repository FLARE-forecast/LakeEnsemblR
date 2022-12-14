#' Input values into json file
#'
#'Inputs values into json file by locating the label and key within the json file.
#'  Preserves comments (!) if present.
#'  NOTE: this does not use a json parser so if there are json formatting errors
#'  this function will not pick them up.
#' @param file filepath; to json file which you wish to edit
#' @param label string; which corresponds to section where the key is located
#' @param key string; name of key in which to input the value
#' @param value string; to be input into the key/value pair.
#'   Note boolean values must be input as 'true'/'false' as per the json format
#' @param arg_list list; of parameter to be updated. List names need to be the same
#'  as the key (e.g. 'a_seiche'.
#' @param out_file filepath; to write the output json file (optional);
#'   defaults to overwriting file if not specified
#' @export
#' @author
#'Tadhg Moore, Jorrit Mesman
#' @examples
#'
#' \dontrun{
#' input_json(file = "samp.par", label = "ModelParameters", key = "f_wind",
#'  value = 1.2, out_file = NULL)
#' }
input_json <- function(file, label, key, value, arg_list = NULL, out_file = NULL){

  if(!file.exists(file)) {
    stop("File '", file, "' does not exist!")
  }
  par <- readLines(file)
  if (is.null(out_file)) {
    out_file <- file
  }

  if(!is.null(arg_list)) {

    for(p in seq_len(length(arg_list))) {

      key <- names(arg_list)[p]
      value <- arg_list[[p]]
      if(class(value) == "logical") {
        value <- tolower(value)
      } else if(class(value) == "character") {
        if(length(value) > 1) {
          value <- paste0("[\"", paste0(value, collapse = "\", \""), "\"]")
        } else {
          value <- paste0("\"", value, "\"")
        }
      }
      key_id <- paste0('"', key, '"')
      ind_key <- grep(key_id, par)
      if (length(ind_key) == 0) {
        stop(key, " not found in ",
             file)
      }
      # ind_key <- ind_key[ind_key > ind_label]
      ind_map <- ind_key #[which.min(ind_key - ind_label)]
      if (length(ind_map) == 0) {
        stop(key, " not found in in ",
             file)
      }
      spl1 <- strsplit(par[ind_map], c("!"))[[1]]
      if (length(spl1) == 2) {
        comment <- spl1[2]
      }
      spl2 <- strsplit(spl1[1], ": ")[[1]][2]
      if(gsub(" ", "", par[ind_map + 1]) == "},") {
        sub <- value
      } else {
        sub <- paste0(value, ",")
      }
      par[ind_map] <- gsub(pattern = paste0("\\Q", spl2, "\\E"),
                           replacement = sub,
                           x = par[ind_map])
    }
  } else {

    if(class(value) == "logical") {
      value <- tolower(value)
    } else if(class(value) == "character") {
      if(length(value) > 1) {
        value <- paste0("[\"", paste0(value, collapse = "\", \""), "\"]")
      } else {
        value <- paste0("\"", value, "\"")
      }
    }
    if(is.null(label)){
      ind_label <- 0
    }else{
      label_id <- paste0('"', label, '"')
      ind_label <- grep(label_id, par)

      if(length(ind_label) == 0){
        stop(label, " not found in ", file)
      }
    }
    key_id <- paste0('"', key, '"')
    ind_key <- grep(key_id, par)
    if (length(ind_key) == 0) {
      stop(key, " not found in ", label, " in ",
           file)
    }
    ind_key <- ind_key[ind_key > ind_label]
    ind_map <- ind_key[which.min(ind_key - ind_label)]
    if (length(ind_map) == 0) {
      stop(key, " not found in ", label, " in ",
           file)
    }
    spl1 <- strsplit(par[ind_map], c("!"))[[1]]
    if (length(spl1) == 2) {
      comment <- spl1[2]
    }
    spl2 <- strsplit(spl1[1], ": ")[[1]][2]
    if(gsub(" ", "", par[ind_map + 1]) == "},") {
      sub <- value
    } else {
      sub <- paste0(value, ",")
    }
    par[ind_map] <- gsub(pattern = paste0("\\Q", spl2, "\\E"),
                         replacement = sub,
                         x = par[ind_map])
    old_val <- gsub(" ", "", spl2, fixed = TRUE)
    message("Replaced ", label, " ", key, " ",
            old_val, " with ", value)
  }
  writeLines(par, out_file)
}
