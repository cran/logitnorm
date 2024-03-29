# random, percentile, density and quantile function of the logit-normal
# distribution and estimation of parameters from percentiles by Sum of Squares
# Newton optimization
# 

logit <- function(
  ### Transforming (0,1) to normal scale (-Inf Inf)
  p      ##<< percentile
  ,...   ##<< further arguments to qlogis
){ 
  ##details<<
  ## function \eqn{logit(p) = log \left( \frac{p}{1-p} \right) = log(p) - log(1-p)}
  ##seealso<< \code{\link{invlogit}}
  ##seealso<< \code{\link{logitnorm}}
  qlogis(p,...) 
}

invlogit <- function(
  ### Transforming (-Inf,Inf) to original scale (0,1)
  q,   ##<< quantile
  ...  ##<< further arguments to plogis
){
  ##details<<
  ## function \eqn{f(z) = \frac{e^{z}}{e^{z} + 1} \! = \frac{1}{1 + e^{-z}} \!}
  ##seealso<< \code{\link{logit}}
  ##seealso<< \code{\link{logitnorm}}
  plogis(q,...) 
} 

# for normal-logit transformation do not use scale and location, better use it
# in generating rnorm etc

rlogitnorm <- function(
  ### Random number generation for logitnormal distribution
  n,          ##<< number of observations
  mu = 0,     ##<< distribution parameter
  sigma = 1,	##<< distribution parameter
  ...	##<< arguments to \code{\link{rnorm}}
){	
  ##seealso<< \code{\link{logitnorm}}
  plogis( rnorm(n = n, mean = mu, sd = sigma, ...) ) 
}

plogitnorm <- function(
  ### Distribution function for logitnormal distribution	
  q  ##<< vector of quantiles
  , mu = 0    ##<< location distribution parameter
  , sigma = 1	##<< scale distribution parameter
  , ...       ##<< further arguments to pnorm
){
  ##seealso<< \code{\link{logitnorm}}
  ql <- qlogis(q)
  pnorm(ql,mean = mu,sd = sigma,...)
}


dlogitnorm <- function(
  ### Density function of logitnormal distribution	
  x		##<< vector of quantiles
  , mu = 0         ##<< scale distribution parameter
  , sigma = 1	     ##<< location distribution parameter
  , log = FALSE    ##<< if TRUE, the log-density is returned
  , ...	##<< further arguments passed to \code{\link{dnorm}}: \code{mean}, 
  ## and \code{sd} for mu and sigma respectively.  
){
  ##details<< \describe{\item{Logitnorm distribution}{ 
  ## \itemize{
  ## \item{density function: dlogitnorm }
  ## \item{distribution function: \code{\link{plogitnorm}} }
  ## \item{quantile function: \code{\link{qlogitnorm}} }
  ## \item{random generation function: \code{\link{rlogitnorm}} }
  ## }
  ## }}
  ##seealso<< \code{\link{logitnorm}}
  ##details<< The function is only defined in interval (0,1), but the density 
  ## returns 0 outside the support region.
  ql <- qlogis(x)
  # multiply (or add in the log domain) by the Jacobian (derivative) of the
  # back-Transformation (logit)
  if (log) {
    ifelse(
      x <= 0 | x >= 1, 0, 
      dnorm(ql, mean = mu, sd = sigma, log = TRUE, ...) - log(x) - log1p(-x)
    )
  } else {
    ifelse(
      x <= 0 | x >= 1, 0, 
      dnorm(ql,mean = mu,sd = sigma,...)/x/(1 - x)
    )
  }
}

qlogitnorm <- function(
  ### Quantiles of logitnormal distribution.	
  p ##<< vector of probabilities
  , mu = 0    ##<< location distribution parameter
  , sigma = 1	##<< scale distribution parameter
  , ...       ##<< further arguments to plogis
){
  ##seealso<< \code{\link{logitnorm}}
  qn <- qnorm(p,mean = mu,sd = sigma,...)
  plogis(qn)
}

# derivative of logit(x)
.dlogit <- function(x) 1/x + 1/(1-x)

#------------------ estimating parameters from fitting to distribution 
.ofLogitnorm <- function(
  ### Objective function used by \code{\link{coefLogitnorm}}. 
  theta				##<< theta[1] is mu, theta[2] is the sigma
  ,quant				##<< q are the quantiles for perc
  ,perc = c(0.5,0.975) 
){
  # there is an analytical expression for the gradient, but here just use
  # numerical gradient
  #
  # calculating perc should be faster than calculating quantiles of the normal
  # distr.
  if (theta[2] <= 0) return( Inf )
  tmp.predp = plogitnorm(quant, mu = theta[1], sigma = theta[2] )
  tmp.diff = tmp.predp - perc
  
  #however, q not so long valley and less calls to objective function
  #but q has problems with high sigma
  #tmp.predq = qlogitnorm(perc, mean = theta[1], sigma = theta[2] )
  #tmp.diff =  tmp.predq - quant
  sum(tmp.diff^2)
}

twCoefLogitnormN <- function(
  ### Estimating coefficients from a vector of quantiles and percentiles (non-vectorized).	
  quant					##<< the quantile values
  ,perc = c(0.5,0.975)		##<< the probabilities for which the quantiles were specified
  , method = "BFGS"			##<< method of optimization (see \code{\link{optim}})
  , theta0 = c(mu = 0,sigma = 1)	##<< starting parameters
  , returnDetails = FALSE	##<< if TRUE, the full output of optim is returned instead of only entry par
  , ... 					##<< further parameters passed to optim, e.g. \code{control = list(maxit = 1000)}
){
  ##seealso<< \code{\link{logitnorm}}
  names(theta0) <- c("mu","sigma")
  tmp <- optim( theta0, .ofLogitnorm, quant = quant,perc = perc, method = method, ...)
  if (tmp$convergence != 0)
    warning(paste("coefLogitnorm: optim did not converge. theta0 = ",paste(theta0,collapse = ",")))
  if (returnDetails )
    tmp
  else
    tmp$par
  ### named numeric vector with estimated parameters of the logitnormal distribution.
  ### names: \code{c("mu","sigma")}
}
#mtrace(coefLogitnorm)
attr(twCoefLogitnormN,"ex") <- function(){
  # experiment of re-estimation the parameters from generated observations
  thetaTrue <- c(mu = 0.8, sigma = 0.7)
  obsTrue <- rlogitnorm(thetaTrue["mu"],thetaTrue["sigma"], n = 500)
  obs <- obsTrue + rnorm(100, sd = 0.05)        # some observation uncertainty
  plot(density(obsTrue),col = "blue"); lines(density(obs))
  
  # re-estimate parameters based on the quantiles of the observations
  (theta <- twCoefLogitnorm( median(obs), quantile(obs,probs = 0.9), perc = 0.9))
  
  # add line of estimated distribution
  x <- seq(0,1,length.out = 41)[-c(1,41)]	# plotting grid
  dx <- dlogitnorm(x,mu = theta[1],sigma = theta[2])
  lines( dx ~ x, col = "orange")
}

twCoefLogitnorm <- function(
  ### Estimating coefficients of logitnormal distribution from median and upper quantile	
  median					##<< numeric vector: the median of the density function
  , quant					##<< numeric vector: the upper quantile value
  , perc = 0.975				##<< numeric vector: the probability for which the quantile was specified
){
  ##seealso<< \code{\link{logitnorm}}
  # twCoefLogitnorm
  mu = logit(median)
  upperLogit = logit(quant)
  sigmaFac = qnorm(perc)
  sigma = 1/sigmaFac*(upperLogit - mu)
  c(mu = mu, sigma = sigma)
  ### numeric matrix with columns \code{c("mu","sigma")}
  ### rows correspond to rows in median, quant, and perc
}
#mtrace(twCoefLogitnorm)
attr(twCoefLogitnorm,"ex") <- function(){
  # estimate the parameters, with median at 0.7 and upper quantile at 0.9
  med = 0.7; upper = 0.9 
  med = 0.2; upper = 0.4 
  (theta <- twCoefLogitnorm(med,upper))
  
  x <- seq(0,1,length.out = 41)[-c(1,41)]	# plotting grid
  px <- plogitnorm(x,mu = theta[1],sigma = theta[2])	#percentiles function
  plot(px~x); abline(v = c(med,upper),col = "gray"); abline(h = c(0.5,0.975),col = "gray")
  
  dx <- dlogitnorm(x,mu = theta[1],sigma = theta[2])	#density function
  plot(dx~x); abline(v = c(med,upper),col = "gray")
  
  # vectorized
  (theta <- twCoefLogitnorm(seq(0.4,0.8,by = 0.1),0.9))
  
  .tmp.f <- function(){
    # xr = rlogitnorm(1e5, mu = theta["mu"], sigma = theta["sigma"])
    # median(xr)
    invlogit(theta["mu"])
    qlogitnorm(0.975, mu = theta["mu"], sigma = theta["sigma"])
  }
}

twCoefLogitnormCi <- function( 
  ### Calculates mu and sigma of the logitnormal distribution from lower and upper quantile, i.e. confidence interval.
  lower	##<< value at the lower quantile, i.e. practical minimum
  ,upper	##<< value at the upper quantile, i.e. practical maximum
  ,perc = 0.975	##<< numeric vector: the probability for which the quantile was specified
  , sigmaFac = qnorm(perc) 	##<< sigmaFac = 2 is 95% sigmaFac = 2.6 is 99% interval
  , isTransScale = FALSE ##<< if true lower and upper are already on logit scale
){	
  ##seealso<< \code{\link{logitnorm}}
  if (!isTRUE(isTransScale) ) {
    lower <- logit(lower)
    upper <- logit(upper)
  }
  halfWidth <- (upper - lower)/2
  sigma <- halfWidth/sigmaFac
  cbind( mu = upper - halfWidth, sigma = sigma )
  ### named numeric vector: mu and sigma parameter of the logitnormal distribution.
}
attr(twCoefLogitnormCi,"ex") <- function(){
  mu = 2
  sd = c(1,0.8)
  p = 0.99
  lower <- l <- qlogitnorm(1 - p, mu, sd )		# p-confidence interval
  upper <- u <- qlogitnorm(p, mu, sd )		# p-confidence interval
  cf <- twCoefLogitnormCi(lower,upper, perc = p)	
  all.equal( cf[,"mu"] , c(mu,mu) )
  all.equal( cf[,"sigma"] , sd )
}

.ofLogitnormMLE <- function(
  ### Objective function used by \code{\link{coefLogitnormMLE}}. 
  mu	##<< numeric vector of proposed parameter				
  ## make sure that logit(mu)<mle for mle>0.5 and logit(mu)>mle for mle<0.5
  , mle				##<< the mode of the density distribution
  , logitMle = logit(mle)##<< may provide for performance reasons
  , quant				##<< q are the quantiles for perc
  , perc = c(0.975) 
){
  # given mu and mle, we can calculate sigma
  sigma2 = (logitMle - mu)/(2*mle - 1)
  ifelse( sigma2 <= 0, Inf, {
    tmp.predp = plogitnorm(quant, mu = mu, sigma = sqrt(sigma2) )
    tmp.diff = tmp.predp - perc
    tmp.diff^2
  })
}

twCoefLogitnormMLE <- function(
  ### Estimating coefficients of logitnormal distribution from mode and upper quantile	
  mle						  ##<< numeric vector: the mode of the density function
  ,quant					##<< numeric vector: the upper quantile value
  ,perc = 0.999		##<< numeric vector: the probability for which the quantile 
  ## was specified
  #, ... 					##<< Further parameters to \code{\link{optimize}}
){
  ##seealso<< \code{\link{logitnorm}}
  # twCoefLogitnormMLE
  nc <- c(length(mle),length(quant),length(perc)) 
  n <- max(nc)
  res <- matrix( as.numeric(NA), n,2, dimnames = list(NULL,c("mu","sigma")))
  for (i in 1:n ) {
    i0 <- i - 1
    mleI <- mle[1 + i0 %% nc[1]]
    quantI <- quant[1 + i0 %% nc[2]]
    percI <- perc[1 + i0 %% nc[3]]
    if (mleI == 0.5) {
      # if mode is at 0.5 its symmetrical and corresponds to median
      mu = 0
      res[i,] = twCoefLogitnorm(0.5, quantI, percI)
      break()
    }
    # in order to estimate sigma
    # we now that mu is in (\code{logit(mle)},0) for \code{mle < 0.5} and in 
    # \code{(0,logit(mle))} for \code{mle > 0.5} for unimodal distribution
    # there might be a maximum in the middle and optimized misses the low part
    # hence, first get near the global minimum by a evaluating the cost at a 
    # grid that is spaced narrower at the edge
    # 
    #intv <- if (logitMle < 0) c(logitMle+.Machine$double.eps,0) else c(0,logitMle-.Machine$double.eps)
    logitMle <- logit(mleI)
    upper <- abs(logitMle) - .Machine$double.eps
    muTry <- sign(logitMle)*log(seq(1,exp(upper),length.out = 40))
    ofMuTry <- .ofLogitnormMLE(
      muTry, mle = (mleI), logitMle = logitMle
      , quant = (quantI <- quant[1 + i0 %% nc[2]])
      , perc = (percI <- perc[1 + i0 %% nc[3]]))
    #plot(muTry,ofMuTry)
    # now optimize starting from the near minimum
    imin <- which.min(ofMuTry)
    intv <- muTry[ c(max(1,imin - 1), min(length(muTry),imin + 1)) ]
    if (diff(intv) == 0 ) mu <- intv[1] else
      mu <- optimize( 
        .ofLogitnormMLE, interval = intv, mle = (mleI), logitMle = logitMle
        , quant = quantI
        , perc = percI)$minimum
      sigma <- sqrt((logitMle - mu)/(2*mleI - 1))
    res[i,] <- c(mu,sigma)
  }
  res
  ### numeric matrix with columns \code{c("mu","sigma")}
  ### rows correspond to rows in \code{mle}, \code{quant}, and \code{perc}
}
#mtrace(coefLogitnorm)
attr(twCoefLogitnormMLE,"ex") <- function(){
  # estimate the parameters, with mode 0.7 and upper quantile 0.9
  mode = 0.7; upper = 0.9
  (theta <- twCoefLogitnormMLE(mode,upper))
  x <- seq(0,1,length.out = 41)[-c(1,41)]	# plotting grid
  px <- plogitnorm(x,mu = theta[1],sigma = theta[2])	#percentiles function
  plot(px~x); abline(v = c(mode,upper),col = "gray"); abline(h = c(0.999),col = "gray")
  dx <- dlogitnorm(x,mu = theta[1],sigma = theta[2])	#density function
  plot(dx~x); abline(v = c(mode,upper),col = "gray")
  # vectorized
  (theta <- twCoefLogitnormMLE(mle = seq(0.4,0.8,by = 0.1),quant = upper))
  # flat
  (theta <- twCoefLogitnormMLEFlat(mode))
}

.tmp.f <- function(){
  (theta = twCoefLogitnormMLEFlat(0.9))
  (theta = twCoefLogitnormMLEFlat(0.1))
  (theta = twCoefLogitnormMLEFlat(0.5))
  mle = c(0.7,0.2)
  mle = seq(0.55,0.95,by=0.05)
  mle = seq(0.95,0.99,by=0.01)
  theta = twCoefLogitnormMLEFlat(mle)
  sigma = theta[,2]
  plot(sigma ~ mle)
  (sigmac = 1/(2*mle*(1-mle)))
  sigmac/sigma
  plot(sigmac ~ mle)
}

twCoefLogitnormMLEFlat <- function(
  ### Estimating coefficients of a maximally flat unimodal logitnormal distribution given the mode 	
  mle		##<< numeric vector: the mode of the density function
){
  vectorList <- lapply(mle, .twCoefLogitnormMLEFlat_scalar)
  do.call(rbind, vectorList)
}
  
  
.twCoefLogitnormMLEFlat_scalar <- function(mle){
  if (mle == 0.5) {
    #sigma =  sqrt(dlogit(mle)/2) # 1.414214
    return(c(mu = 0.0, sigma = sqrt(2)))
  } 
  is_right <- mle > 0.5
  mler = ifelse(is_right, mle, 1-mle)
  xt <- optimize(.ofModeFlat, interval = c(0,0.5), m=mler, logitm=logit(mler))$minimum
  sigma2 <- (1/xt + 1/(1-xt))/2
  mur <- logit(mler) - sigma2*(2*mler - 1)
  mu <- ifelse(is_right, mur, -mur)
  c(mu = mu, sigma = sqrt(sigma2))
}

.ofModeFlat <- function(x, m, logitm = logit(m)){
  # lhs = 1/x + 1/(1-x)
  # rhs = (logitm - logit(x))/(m-x)
  # lhs = (m-x)/x + (m-x)/(1-x)
  # rhs = (logitm - logit(x))
  lhs = m/x + (m-1)/(1-x)
  rhs = logitm - logit(x)
  d = lhs - rhs
  d*d
}


.ofLogitnormE <- function(
  ### Objective function used by \code{\link{coefLogitnormE}}. 
  theta				##<< theta[1] is the mu, theta[2] is the sigma
  , mean				##<< the expected value of the density distribution
  , quant				##<< q are the quantiles for perc
  , perc = c(0.975) 
  , ...				##<< further argument to \code{\link{momentsLogitnorm}}.
){
  tmp.predp = plogitnorm(quant, mu = theta[1], sigma = theta[2] )
  tmp.diff = tmp.predp - perc
  .exp <- momentsLogitnorm(theta[1],theta[2],...)["mean"]
  tmp.diff.e <- mean - .exp
  sum(tmp.diff^2) + tmp.diff.e^2
}


twCoefLogitnormE <- function(
  ### Estimating coefficients of logitnormal distribution from expected value, i.e. mean, and upper quantile.	
  mean					##<< the expected value of the density function
  , quant					##<< the quantile values
  , perc = c(0.975)			##<< the probabilities for which the quantiles were 
  ## specified
  , method = "BFGS"			##<< method of optimization (see \code{\link{optim}})
  , theta0 = c(mu = 0,sigma = 1)	##<< starting parameters
  , returnDetails = FALSE	##<< if TRUE, the full output of optim is returned 
  ## with attribute resOptim
  , ...                   ##<< further arguments to optim
){
  ##seealso<< \code{\link{logitnorm}}
  # twCoefLogitnormE
  names(theta0) <- c("mu","sigma")
  mqp <- cbind(mean,quant,perc)
  n <- nrow(mqp)
  res <- matrix( as.numeric(NA), n,2, dimnames = list(NULL,c("mu","sigma")))
  resOptim <- list()
  for (i in 1:n ) {
    mqpi <- mqp[i,]
    tmp <- optim(
      theta0, .ofLogitnormE, mean = mqpi[1], quant = mqpi[2], perc = mqpi[3]
      , method = method, ...)
    resOptim[[i]] <- tmp
    if (tmp$convergence != 0)
      warning(paste(
        "coefLogitnorm: optim did not converge. theta0 = ",
        paste(theta0,collapse = ",")))
    else
      res[i,] <- tmp$par
  }
  if (returnDetails )
    attr(res,"resOptim") <- resOptim
  res
  ### named numeric matrix with estimated parameters of the logitnormal 
  ### distribution.
  ### colnames: \code{c("mu","sigma")}
}
#mtrace(coefLogitnorm)
attr(twCoefLogitnormE,"ex") <- function(){
  # estimate the parameters
  (thetaE <- twCoefLogitnormE(0.7,0.9))
  
  x <- seq(0,1,length.out = 41)[-c(1,41)]	# plotting grid
  px <- plogitnorm(x,mu = thetaE[1],sigma = thetaE[2])	#percentiles function
  plot(px~x); abline(v = c(0.7,0.9),col = "gray"); abline(h = c(0.5,0.975),col = "gray")
  dx <- dlogitnorm(x,mu = thetaE[1],sigma = thetaE[2])	#density function
  plot(dx~x); abline(v = c(0.7,0.9),col = "gray")
  
  z <- rlogitnorm(1e5, mu = thetaE[1],sigma = thetaE[2])
  mean(z)	# about 0.7
  
  # vectorized
  (theta <- twCoefLogitnormE(mean = seq(0.4,0.8,by = 0.1),quant = 0.9))
}

momentsLogitnorm <- function(
  ### First two moments of the logitnormal distribution by numerical integration
  mu	##<< parameter mu 
  ,sigma		##<< parameter sigma
  ,abs.tol = 0	##<< changing default to \code{\link{integrate}}
  ,...		##<< further parameters to the \code{\link{integrate}} function
){
  fExp <- function(x)  plogis(x)*dnorm(x,mean = mu,sd = sigma)
  .exp <- integrate(fExp,-Inf,Inf, abs.tol = abs.tol, ...)$value
  fVar <- function(x)   (plogis(x) - .exp)^2 * dnorm(x,mean = mu,sd = sigma)
  .var <- integrate(fVar,-Inf,Inf, abs.tol = abs.tol, ...)$value
  c( mean = .exp, var = .var )
  ### named numeric vector with components \itemize{
  ### \item{ \code{mean}: expected value, i.e. first moment}
  ### \item{ \code{var}: variance, i.e. second moment }
  ### }
}
attr(momentsLogitnorm,"ex") <- function(){
  (res <- momentsLogitnorm(4,1))
  (res <- momentsLogitnorm(5,0.1))
}

.ofModeLogitnorm <- function(
  ### Objective function used by \code{\link{coefLogitnormMLE}}.
  mle		##<< proposed mode
  ,mu	##<< parameter mu 
  ,sd2	##<< parameter sigma^2
){
  if (mle <= 0 | mle >= 1) return(.Machine$double.xmax)
  tmp.diff.mle <- mu - sd2*(1 - 2*mle) - logit(mle)
  tmp.diff.mle^2
}

modeLogitnorm <- function(
  ### Mode of the logitnormal distribution by numerical optimization
  mu	##<< parameter mu 
  ,sigma		##<< parameter sigma
  ,tol = invlogit(mu)/1000	##<< precisions of the estimate
){
  ##seealso<< \code{\link{logitnorm}}
  itv <- if(mu<0) c(0,invlogit(mu)) else c(invlogit(mu),1)
  tmp <- optimize( .ofModeLogitnorm, interval = itv, mu = mu, sd2 = sigma^2, tol = tol)
  tmp$minimum
}

twSigmaLogitnorm <- function(
  ### Estimating coefficients of logitnormal distribution from mode and given mu	
  mle		##<< numeric vector: the mode of the density function
  ,mu = 0	##<< for mu = 0 the distribution will be the flattest case (maybe bimodal) 
){
  ##details<<
  ## For a mostly flat unimodal distribution use \code{\link{twCoefLogitnormMLE}(mle,0)}
  sigma = sqrt( (logit(mle)-mu)/(2*mle-1) )
  ##seealso<< \code{\link{logitnorm}}
  # twSigmaLogitnorm
  cbind(mu = mu, sigma = sigma)
  ### numeric matrix with columns \code{c("mu","sigma")}
  ### rows correspond to rows in mle and mu
}
#mtrace(coefLogitnorm)
attr(twSigmaLogitnorm,"ex") <- function(){
  mle <- 0.8
  (theta <- twSigmaLogitnorm(mle))
  #
  x <- seq(0,1,length.out = 41)[-c(1,41)]	# plotting grid
  px <- plogitnorm(x,mu = theta[1],sigma = theta[2])	#percentiles function
  plot(px~x); abline(v = c(mle),col = "gray")
  dx <- dlogitnorm(x,mu = theta[1],sigma = theta[2])	#density function
  plot(dx~x); abline(v = c(mle),col = "gray")
  # vectorized
  (theta <- twSigmaLogitnorm(mle = seq(0.401,0.8,by = 0.1)))
}





