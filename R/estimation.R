#' The negative log likelihood for given parameters and data
#' 
#' \code{minimizeme} is mainly used by an optimizer (e.g. \code{optim}) 
#' to estimate parameters.
#' 
#' 
#' @param theta Numeric vector of *transformed* parameter values
#' @param data Numeric vector, or \code{data.frame} with columns named Weight and Freq. The observed values, fished individuals in grams
#' @param names String vector. Contains the names of the parameter vector theta.
#' @param fixed.names String vector. Names of constants.
#' @param fixed.vals Numeric vector. Transformed values of constants.
#' @param isSurvey Logical. If TRUE the observations are assumed to be from a survey.
#' @return Numeric scalar. The negative log likelihood for the given parameters and observations.
#' @author alko
#' @keywords optimize
#' @note If data is a list containing both sample and df, the \code{data.frame} df will be used.
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
minimizeme <- function(theta, data, names, fixed.names=c(), fixed.vals=c(), isSurvey=FALSE) {
    params <- parameters(c(names, fixed.names), c(theta, fixed.vals))  
    if(is(data, "data.frame")) {
        return(with(getParams(params,isSurvey),
                    sum( - data$Freq * log(pdfN.approx(data$Weight)) )))
    } else if(is(data, "numeric")) {
        return(with(getParams(params,isSurvey), sum(-log(pdfN.approx(data)))))
    } else {
        stop("data appears not to be numeric vector or data.frame")
    }
}



#' Estimates parameters using the given data and maybe some parameters
#' 
#' Parameter estimation minimizing the negative log likelihood, using the
#' nlminb function. \code{estimateParam} uses data from commercial catches or surveys.
#' \code{estimateMultidata} uses both sources
#' 
#' 
#' @param names String vector. The parameters to be estimated.
#' @param data Numeric vector, or \code{data.frame} with columns Weight and Freq, or \code{list} with a numeric vector named `sample` or a \code{data.frame} named `df`.
#' Weight of individual fish (vector) or frequencies per weight class \code{data.frame}.
#' @param start Numeric vector. Initial values of the parameters.
#' @param lower The lower bound for the parameter estimation.
#' @param upper The upper bound for the parameter estimation.
#' @param fixed.names String vector. Names of constants.
#' @param fixed.vals Numeric vector. Transformed values of constants.
#' @param fixed.transformed Logical. If FALSE the constants are not transformed.
#' @param plotFit Boolean. If TRUE a plot is produced with the fited pdf and the
#' kernel density estimate of the data.
#' @param isSurvey Boolean. If TRUE the data are assumed to be from a survey.
#' @param verbose Boolean. If TRUE the estimated confidence intervals are printed.
#' @param ... Additional named arguments passed to plotFit
#' @return A Parameters object, containing the estimated parameters.
#' @note If data is a list containing both sample and df, the \code{data.frame} df will be used.
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
           data=simulateData3(parameters(), samplesize=1000),
           start= rep(0.5, length(names)),
           lower=rep(-Inf, length(names)), upper=rep(Inf, length(names)),
           fixed.names=c(), fixed.vals=numeric(0), fixed.transformed = TRUE,
           plotFit=FALSE, isSurvey=FALSE, verbose=getOption("verbose"), useTMB = TRUE, ...) {
    p <- parameters()

    if(is(data, "list")) {
        if("df" %in% names(data)) {
            data <- data$df
        } else if ("sample" %in% names(data)) {
            data <- data$sample
        } else stop("`data` is a list not containing an element named sample or df.")
    }

    start[which(names == "Winf")] <- 
      ifelse(is(data, "data.frame"), (max(data$Weight) + 1) / p@scaleWinf, (max(data) + 1) / p@scaleWinf)
    
    scales <- sapply(names, function(n) get(paste0("getscale", n))(p))

    if( ! fixed.transformed) {
        fixed.scales <- sapply(fixed.names, function(n) get(paste0("getscale", n))(p))
        fixed.vals <- log(fixed.vals / fixed.scales)
    }
    
    useapply <- if(require(parallel)) mclapply else lapply
    
    sd <- mean <- rep(0, length(names))
    
    estim <- nlminb(log(start), minimizeme, data=data, names=names,
                    fixed.names=fixed.names, fixed.vals=fixed.vals,
                    lower=lower, upper=upper, isSurvey=isSurvey)
    if(estim$convergence != 0) warning(estim$message)
    
    res <- estim$par
    h <- hessian(minimizeme, estim$par, data=data,
                           names=names, fixed.names=fixed.names,
                           fixed.vals=fixed.vals,isSurvey=isSurvey)
    s <- jacobian(minimizeme, estim$par, data=data,
                            names=names, fixed.names=fixed.names,
                            fixed.vals=fixed.vals,isSurvey=isSurvey)
    vcm <- try(solve(h))
    
    ci <- matrix(rep(NA, length(names)*3),ncol=3, dimnames = list(names, c("Estimate","Lower", "Upper")))
    st.er <- NA
    if( ! is(vcm, "try-error")) {
      st.er <- sqrt(diag(vcm)) 
      ci <- cbind(exp(res)*scales, exp(outer(1.96 * st.er, c(-1,1), '*') + res) * scales)
    }
    
    p <- parameters(c(names, fixed.names), c(t(simplify2array(res)), fixed.vals))
    
    if(plotFit) plotFit(p, data, ...)
    if(verbose) print(ci)
    return(structure(p, par=res, hessian=h, jacobian=s, st.er=st.er, ci=ci, 
                     objective=estim$objective, convergence=estim$convergence, 
                     nlminbMessage=estim$message, call=match.call(), version=getVersion()))
}

##' @param surdata Same as data. Survey data.
##' @param comdata Same as data. Commercial data.
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

##' @export
estimate_TMB <- function(df, n=0.75, epsilon_a=0.8, epsilon_r=0.1, A=4.47, 
                         eta_m=0.25, a=0.27, Winf = NULL, sigma=NULL,
                         sdloga = 0.89, winf.ubound = 2, DLL="s6model", 
                         verbose=FALSE, map=list(loga=factor(NA), x=factor(NA)), 
                         random=c(), isSurvey = FALSE, eta_S = 0.01, usePois = TRUE,
                         totalYield = 0.000001, ...) {
  if(! require(TMB)) stop("TMB is not installed! Please install and try again.")
  tryer <- try({
    binsize <- attr(df,"binsize")
    if(is.null(Winf))  {
      Winf <- max(df$Weight) + 2 * binsize
    } else {
      map$logWinf  <- factor(NA)
    }
    if(is.null(sigma) || is.na(sigma))  {
      sigma <- if(usePois) sum(df$Freq) else 0.0001
    } else {
      map$logSigma  <- factor(NA)
    }
    if(! isSurvey) {
      map$logeta_S <- factor(NA)
    }
    data <- list(binsize=binsize, nwc=dim(df)[1], freq=df$Freq, n=n, epsilon_a=epsilon_a,
                 epsilon_r=epsilon_r, A=A, eta_m=eta_m, meanloga = log(a), 
                 sdloga = sdloga, isSurvey = as.integer(isSurvey), usePois = as.integer(usePois),
                 totalYield = totalYield)
    pars <- list(loga=log(a), x=0, logFm = log(0.5), logWinf = log(Winf),
                 logWfs = log(min(df$Weight[df$Freq > 0])), logSigma=log(sigma), logeta_S = log(eta_S))
    estnames <- names(pars[! names(pars) %in% c(names(map), random)])
    upper <- rep(Inf, length(estnames))
    upper[which(estnames == "logWinf")] <- log(Winf * winf.ubound)
    obj <- MakeADFun(data = data, parameters = pars, DLL = DLL, map=map, random=random, ...)
    obj$env$tracemgc <- verbose
    obj$env$inner.control$trace <- verbose
    obj$env$silent <- ! verbose
    if(! verbose) {
      newtonOption(trace=0)
      config(trace.optimize = 0, DLL=DLL)
    }
    opt <- nlminb(obj$par, obj$fn, obj$gr, upper = upper)
    sdr <- sdreport(obj)
    nms <- c("Fm","Winf","Wfs", "a", "eta_S")
    vals <- sdr$value
    sds <- setNames(sdr$sd, names(vals))
    estpars <- parameters(c(nms, "n", "epsilon_a", "epsilon_r", "A", "eta_m"),
                          as.numeric(c(vals[nms], n, epsilon_a, epsilon_r, A, eta_m)),
                          transformed=FALSE)
    Fmsy <- calcFmsy(estpars)
    opt$convergence
  }, silent = !verbose)
  if(class(tryer) == "try-error") {
    return(tryer)
  }
  structure(data.frame(Fm=vals["Fm"], Fm_sd = sds["Fm"], Winf=vals["Winf"], Winf_sd=sds["Winf"],
                       Fmsy = Fmsy, Wfs = vals["Wfs"], Wfs_sd = sds["Wfs"], FFmsy = vals["Fm"]/Fmsy, 
                       a = vals["a"], eta_S = vals["eta_S"], sigma = vals["sigma"], R = vals["R"], 
                       Y = vals["Y"], ssb = vals["ssb"], ssb_sd = sds["ssb"], row.names=NULL),
            obj=obj, opt=opt, sdr = sdr, estpars=estpars)
}
