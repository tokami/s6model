##' @title s6modelResults class
##' @exportClass s6modelResults
##'@name s6modelResults
#' @aliases s6modelResults-class
#' @rdname s6modelResults
#' @export
setClass("s6modelResults")

fitWL <- function(df, colnames = c("Weight", "Length")) {
  df <- setNames(df[colnames], c("Weight", "Length"))
  fit <- lm(log(Weight) ~ log(Length), data = df) 
  a <- exp(fit$coefficients[1])
  b <- fit$coefficients[2]
  list(a = a, b = b)
}

l2w <- function(l, a, b) {
  a * l ^ b
}

addWeight <- function(df, a, b, lengthcol = "Length") {
  if(is.null(df$Weight))
    df$Weight <- l2w(l = df[lengthcol], a = a, b = b)
  else
    warning("Column `Weight` exists, the original data frame `df` is returned")
  df
}

##' @export
makeAssessment <- function(inputData, a.mean = 0.35, a.sd = 0.175, nsample = 100, probs = seq(0, 1, 0.01), ...) {
  ests <- lapply(inputData, function(x) estimate_TMB(x, a=a.mean, ...))
  res <- lapply(ests, function(x) if(class(x)== "try-error") rep(NA, 4) else x[1:4] )
  res <- do.call(rbind.data.frame, res)
  row.names(res) <- names(inputData)
  if(a.sd > 0) {
    ci <- lapply(inputData, function(x) {
      reps <- lapply(seq(nsample), function(bogus) estimate_TMB(x, a = rparam(a.mean, a.sd), ...))
      reps <- lapply(reps, function(x) if(class(x)== "try-error") rep(NA, 4) else x[1:4] )
      reps <- do.call(rbind.data.frame, reps)
      as.data.frame(apply(reps, 2, quantile, probs = probs, na.rm = TRUE))
    })
    ci <- setNames(lapply(names(ci[[1]]), function(nm) lapply(ci, function(d) d[[nm]])),names(ci[[1]]))
    ci <- lapply(ci, function(yy) {
      for(w in which(sapply(yy, is.null))) {
        yy[[w]] <- rep(NA, length(probs))
      }
      do.call(cbind.data.frame, yy)
    })
    attr(res, "CI") <- ci
  } 
  class(res) <- c("s6modelResults", class(res))
  res <- structure(res, Results = ests, version = getVersion())
  res
}

##' @export
##' @rdname s6modelResults
print.s6modelResults <- function(x, ...) {
  n <- dim(x)
  if(dim(x)[1] == 0) {
    cat("Object with no results")
  } else {
    print.data.frame(x, ...)
  }
  cat("\nResults produced by:", formatVersion(attr(x, "version")), "\n")
  invisible(x)
}

makeShading <- function(x, ylow, yhigh, col = grey(0.8), ...) {
  xs <- c(x, rev(x))
  ys <- c(ylow, rev(yhigh))
  notna <- ! is.na(ys)
  polygon(xs[notna], ys[notna], col = col, border = NA)
}

addConfidenceShading <- function(x, y, ...) {
  d <- nrow(y) - 1
  for(i in seq(1, d / 2)) {
    s6model:::makeShading(x, y[i, ], y[d - i, ],
                col=grey(1 - i / (d / 2 )))
  }
}

##' @export
##' @rdname s6modelResults
plot.s6modelResults <- function(x, ..., what = "FFmsy", use.rownames = FALSE, 
                                years = NULL, xlab = NULL, ylab = NULL, 
                                ylim = NULL, addDefault = FALSE, col.def = "white",
                                addhline = 1, col.hline = 1, lty.hline = 2,
                                cex.ver = 0.7, version = TRUE, xaxs = "i", yaxs = "i") {
  yl <- switch(what, FFmsy = expression(F/F[msy]), Fm = "F", Winf = expression(W[infinity]), Wfs = "50% retainment size", stop("Unidentified `what` argument. Please select one of FFmsy, Fm, Winf, or Wfs"))
  ylab <- if(is.null(ylab)) yl else ylab
  xlab <- if(is.null(xlab)) "Year" else xlab
  
  xs <- seq(dim(x)[1])
  if(use.rownames) {
    xs <- as.numeric(regmatches(row.names(x), regexpr("[0-9]+", row.names(x), perl = TRUE)))
  }
  if(! is.null(years) & ! use.rownames) {
    xs <- years
  }
  ys <- x[[what]]
  ylim <- range(ys, attr(x, "CI")[[what]], na.rm = TRUE)
  
  plot(xs, ys, type="n", ylim=ylim, xlab = "", ylab = "", xaxs = xaxs, yaxs = yaxs, ...)
  title(xlab = xlab, ylab=ylab, line=2)
  if( ! is.null(attr(x, "CI"))) {
    addConfidenceShading(xs, attr(x, "CI")[[what]])
  }
  if(addDefault){
    lines(xs, ys, lty=2, lwd=3, col= col.def)
  }
  if(!is.null(addhline)) {
    abline(h=addhline, lwd=2, col=col.hline, lty=lty.hline)
  }
  if(version) {
    addVersion(attr(x, "version"), cex = cex.ver)
  }
  box()
}