#' The negative log likelihood for given parameters and data
#' 
#' \code{minimizeme} is supposed to be used by an optimizer (e.g. \code{optim}) 
#' to estimate parameters.
#' 
#' 
#' @param theta Numeric vector of *transformed* parameter values
#' @param data Numeric vector or data.frame with columns named Weight and Freq.
#'   The observed values, fished individuals in grams
#' @param names String vector. Contains the names of the parameter vector theta.
#' @param fixed.names String vector. Names of constants.
#' @param fixed.vals Numeric vector. Transformed values of constants.
#' @param isSurvey Logical. If TRUE the observations are assumed to be from a survey.
#' @return Numeric scalar. The negative log likelihood for the given parameters and observations.
#' @author alko
#' @keywords optimize
#' @examples 
#'  
#' \dontrun{
#' ## Simulate some data with default parameter values and fishing mortality Fm = 0.3
#' sim <- simulateData3(params = parameters("Fm", 0.3, transformed=FALSE))
#'
#' ## Plotting the negative log likelihood for different values of Fm
#' Fm <- seq(0.1, 1, 0.05) 
#' Fm.transformed <- log(Fm / 0.25)
#' nll <- sapply(Fm.transformed, function(x) minimizeme(theta = x, data = sim$sample, names = "Fm"))
#' plot(Fm, nll, type="l") 
#'
#' ## Using optimise to estimate one parameter
#' est <- optimise(f = minimizeme, interval=c(0.01, 1), data=sim$sample, names="Fm")
#' est.Fm <- exp(est$minimum) * 0.25
#' abline(v=est.Fm)
#' mtext(paste("Estimated Fm = ", round(est.Fm, 2)), at=est.Fm)
#' }
#' 
#' @export minimizeme
#' @rdname minimizeme
minimizeme <- function(theta, data, names, fixed.names=c(), fixed.vals=c(), isSurvey=FALSE)
{
  params <- parameters(c(names, fixed.names), c(theta, fixed.vals))  
  if(class(data) == "data.frame") {
    return(with(getParams(params,isSurvey),
                sum( - data$Freq * log(pdfN.approx(data$Weight)) )))
  }
  return(with(getParams(params,isSurvey), sum(-log(pdfN.approx(data)))))
}



#' Estimates parameters using the given data and maybe some parameters
#' 
#' Parameter estimation minimizing the negative log likelihood, using the
#' nlminb function. \code{estimateParam} uses data from commercial catches or surveys.
#' \code{estimateMultidata} uses both sources
#' 
#' 
#' @param names String vector. The parameters to be estimated.
#' @param data Numeric vector or data.frame with columns Weight and Freq.
#' Weight of individual fish (vector) or frequencies per weight class (data.frame).
#' @param start Numeric vector. Initial values of the parameters.
#' @param lower The lower bound for the parameter estimation.
#' @param upper The upper bound for the parameter estimation.
#' @param fixed.names String vector. Names of constants.
#' @param fixed.vals Numeric vector. Transformed values of constants.
#' @param plotFit Boolean. If TRUE a plot is produced with the fited pdf and the
#' kernel density estimate of the data.
#' @param isSurvey Boolean. If TRUE the data are assumed to be from a survey.
#' @param verbose Boolean. If TRUE the estimated confidence intervals are printed.
#' @param ... Additional named arguments passed to plotFit
#' @return A Parameters object, containing the estimated parameters.
#' @author alko
#' @keywords optimize
#' @examples
#' 
#' ## Simulate some data
#' sam <- simulateData3(params=parameters("a", 0.5, transformed=FALSE))
#' 
#' ## Estimate the a parameter and see the fitted plot
#' estimateParam(names="a", data=sam$sample, plotFit=TRUE)
#' @rdname estimateParam
#' @export estimateParam
estimateParam <-
  function(names = c("Fm", "Winf", "Wfs"),
           data=simulateData3(parameters(), samplesize=1000)$sample,
           start= rep(0.5, length(names)),
           lower=rep(-Inf, length(names)), upper=rep(Inf, length(names)),
           fixed.names=c(), fixed.vals=numeric(0),
           plotFit=FALSE, isSurvey=FALSE, verbose=getOption("verbose"), ...) {
    p <- parameters()
    
    start[which(names == "Winf")] <- 
      ifelse(class(data)=="data.frame", (max(data$Weight) + 1) / p@scaleWinf, (max(data) + 1) / p@scaleWinf)
    
    scales <- sapply(names, function(n) get(paste0("getscale", n))(p))
    
    useapply <- ifelse(require(parallel), mclapply, lapply)
    
    sd <- mean <- rep(0, length(names))
    
    estim <- nlminb(log(start), minimizeme, data=data, names=names,
                    fixed.names=fixed.names, fixed.vals=fixed.vals,
                    lower=lower, upper=upper, isSurvey=isSurvey)
    if(estim$convergence != 0) warning(estim$message)
    
    res <- estim$par
    h <- numDeriv::hessian(minimizeme, estim$par, data=data,
                           names=names, fixed.names=fixed.names,
                           fixed.vals=fixed.vals,isSurvey=isSurvey)
    s <- numDeriv::jacobian(minimizeme, estim$par, data=data,
                            names=names, fixed.names=fixed.names,
                            fixed.vals=fixed.vals,isSurvey=isSurvey)
    vcm <- try(solve(h))
    
    ci <- matrix(rep(NA, length(names)*3),ncol=3, dimnames = list(names, c("Estimate","Lower", "Upper")))
    st.er <- NA
    if(class(vcm) != "try-error") {
      st.er <- sqrt(diag(vcm)) 
      ci <- cbind(exp(res)*scales, exp(outer(1.96 * st.er, c(-1,1), '*') + res) * scales)
    }
    
    p <- parameters(c(names, fixed.names), c(t(simplify2array(res)), fixed.vals))
    
    if(plotFit) plotFit(p, data, ...)
    if(verbose) print(ci)
    return(structure(p, par=res, hessian=h, jacobian=s, st.er=st.er, ci=ci, 
                     objective=estim$objective, convergence=estim$convergence, 
                     nlminbMessage=estim$message, call=match.call()))
}

##' @param surdata Same as data. Survey data.
##' @param comdata Same as data. Commercial data.
##' @author alko
##' @rdname minimizeme
minimizemeMultidata <- function(theta, surdata, comdata, names, fixed.names=c(), fixed.vals=c())
  {
    params <- parameters(c(names, fixed.names), c(theta, fixed.vals))
    return(with(getParams(params,isSurvey=TRUE), sum(-log(pdfN.approx(surdata)))) +
           with(getParams(params,isSurvey=FALSE), sum(-log(pdfN.approx(comdata)))))
  }
##' @param surdata Same as data. Survey data.
##' @param comdata Same as data. Commercial data.
##' @rdname estimateParam
estimateMultidata <-
  function(names = c("Fm", "Winf", "Wfs"),
           surdata=simulateData3(parameters(), samplesize=1000, isSurvey=TRUE)$sample,
           comdata=simulateData3(parameters(), samplesize=1000)$sample,
           start= rep(0.5, length(names)), lower = rep(0.1, length(names)),
           fixed.names=c(), fixed.vals=numeric(0),
           plotFit=FALSE, ...) {
    start[which(names == "Winf")] <- (max(surdata, comdata) + 1) / parameters()@scaleWinf
    lower[which(names == "eta_F")] <- 0.0001
    
    useapply <- ifelse(require(parallel), mclapply, lapply)
    sd <- mean <- rep(0, length(names))
    
    
    estim <- nlminb(log(start), minimizemeMultidata, surdata=surdata, comdata=comdata,
                    names=names, fixed.names=fixed.names, fixed.vals=fixed.vals,
                    lower=log(lower))
    if(estim$convergence != 0)
      warning(estim$message)
    res <- c(estim$par) ##, estim$convergence)
    
    p <- parameters(c(names, fixed.names), c(t(simplify2array(res)), fixed.vals))
    if(plotFit) plotFit(p, data, ...)
    return(p)
  }