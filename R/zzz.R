#' @useDynLib s6model
#' @useDynLib calcFmsy
#' @useDynLib s6modeltest
.onAttach <- function(lib, pkg) {
   packageStartupMessage("Loading ", getVersion(),"\n")  
 }

.onUnload <- function (lib) {
  library.dynam.unload("s6model", lib)
  library.dynam.unload("calcFmsy", lib)
  library.dynam.unload("s6modeltest", lib)
}

