% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/get_yaml_multiple.R
\name{get_yaml_multiple}
\alias{get_yaml_multiple}
\title{Extract values from yaml file}
\usage{
get_yaml_multiple(file = "gotm.yaml", ...)
}
\arguments{
\item{file}{filepath; to yaml file which you wish to edit}

\item{...}{string key1, key2, etc.: multiple keys pointing toward the line
that you want to edit in the yaml file. Keys must be listed consecutively,
without skipping numbers.}
}
\description{
Extract values from yaml file, like gotmtools::get_yaml_value
 However, an unlimited amount of keys can be provided.
 NOTE: this does not use a yaml parser so if there are yaml formatting errors
 this function will not pick them up.
}
\examples{

\dontrun{
get_yaml_multiple(file = "example.yaml", key1 = "streams", key2 = "inflow", key3 = "file")
}
}
\author{
Jorrit Mesman
}
