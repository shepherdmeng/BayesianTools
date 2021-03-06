#' Creates a standardized likelihood class#'
#' @author Florian Hartig
#' @param likelihood Log likelihood density
#' @param names Parameter names (optional)
#' @param parallel parallelization , either i) no parallelization --> F, ii) native R parallelization --> T / "auto" will select n-1 of your available cores, or provide a number for how many cores to use, or iii) external parallelization --> "external". External means that the likelihood is already able to execute parallel runs in form of a matrix with 
#' @param catchDuplicates Logical, determines whether unique parameter combinations should only be evaluated once. Only used when the likelihood accepts a matrix with parameter as columns. 
#' @param parallelOptions list containing two lists. First "packages" determines the R packages necessary to run the likelihood function. Second "objects" the objects in the global envirnment needed to run the likelihood function (for details see \code{\link{createBayesianSetup}}).
#' @param sampler sampler
#' @seealso \code{\link{likelihoodIidNormal}} \cr
#'          \code{\link{likelihoodAR1}} \cr
#' @export
createLikelihood <- function(likelihood, names = NULL, parallel = F, catchDuplicates=T, 
                             sampler = NULL, parallelOptions = NULL){
  
  catchingLikelihood <- function(x, ...){
    out <- tryCatch(
    {
      y = likelihood(x, ...)
      if (any(y == Inf )){
        y[is.infinite(y)] = -Inf
        warning("Positive Inf values occured in the likelihood. Set to -Inf")
      }
      y 
    },
    error=function(cond){
      cat(c("Parameter values ", x, "\n"))
      warning("Problem encountered in the calculation of the likelihood with parameter ", x, "\n Error message was", cond, "\n set result of the parameter evaluation to -Inf ", "ParaeterValues ")
      return(-Inf)
    }
        )
    return(out)
  }

  # initalize cl 
  cl <- NULL
  
  if (parallel == T | parallel == "auto" | is.numeric(parallel)) {
    tmp <- generateParallelExecuter(likelihood, parallel, parallelOptions) 
    parallelLikelihood <- tmp$parallelFun
    cl <- tmp$cl
    parallel = T
  }

  
  parallelDensity<- function(x, ...){
    if (is.vector(x)) return(catchingLikelihood(x, ...))
    else if(is.matrix(x)){
      if(catchDuplicates == TRUE){
        # Check for the rows that are not duplicated
        wn <- which(!duplicated(x))
        if(length(wn) <2) {
          return(parallelLikelihood(x, ...)) }
        else {
        # Define a output vector 
        out1 <- rep(0,length=nrow(x))
       
        # Run the likelihood function for unique values
        if (parallel == "external"){ 
          out1[wn]<-likelihood(x[wn,], ...)
          }
        else{
          if (parallel == T){ 
            out1[wn]<-parallelLikelihood(x[wn,], ...)
          }
            else{
              out1[wn]<-apply(x[wn,], 1, likelihood, ...)   
            }
        }
        # Copy the values for the duplicates
        for(i in 1:length(out1)){
          if(out1[i] != 0) next
          else{
            same <- numeric()
            for(k in 1:length(out1)){
              if(all(x[k,]== x[i,])){
                same <- c(same,k)
              }
            }
            out1[same[-1]] <- out1[same[1]]
          }
        }
      
        return(out1)
        }}
      
      else{
      if (parallel == "external") return(likelihood(x, ...))
      else if (parallel == T){
      return(parallelLikelihood(x, ...))}
      else return(apply(x, 1, likelihood, ...))   
 
      }
    }
    else stop("parameter must be vector or matrix")
  }
  out<- list(density = parallelDensity, sampler = sampler, cl = cl)
  class(out) <- "likelihood"
  return(out)
}



#library(mvtnorm)
#library(sparseMVN)

#' Normal / Gaussian Likelihood function
#' @author Florian Hartig
#' @param predicted vector of predicted values
#' @param observed vector of observed values
#' @param sd standard deviation of the i.i.d. normal likelihood
#' @export
likelihoodIidNormal <- function(predicted, observed, sd){
  notNAvalues = !is.na(observed)
  if (sd <= 0) return (-Inf)
  else return(sum(dnorm(predicted[notNAvalues], mean = observed[notNAvalues], sd = sd, log = T)))
}

# TODO - gibbs sample out the error terms 

#' AR1 type likelihood function
#' @author Florian Hartig
#' @param predicted vector of predicted values
#' @param observed vector of observed values
#' @param sd standard deviation of the iid normal likelihood
#' @param a temporal correlation in the AR1 model
#' @note The AR1 model considers the process: \cr y(t) = a y(t-1) + E \cr e = i.i.d. N(0,sd) \cr |a| < 1 \cr At the moment, no NAs are allowed in the time series.
#' @export
likelihoodAR1 <- function(predicted, observed, sd, a){
  if (any(is.na(observed))) stop("AR1 likelihood cannot work with NAs included, split up the likelihood")
  if (sd <= 0) return (-Inf)
  if (abs(a) >= 1) return (-Inf)
  
  n = length(observed)
  
  res = predicted - observed
  ll =  0.5 * (  - log(2*pi)
                 - n * log(sd^2) 
                 + log( 1- a^2 )
                 - (1- a^2) / sd^2 * res[1]^2
                 - 1 / sd^2 * sum( (res[2:n] - a * res[1:(n-1)])^2)
                )
  return(ll)
}
# Tests
# library(stats)
# data<-arima.sim(n=1000,model = list(ar=0.9))
# x <- ar(data, aic = F, order.max = 1)
# opt <- function(par){
#   -likelihoodAR1(data, rep(0,1000), sd = par[1], a = par[2] )
# }
# optim(c(1.1,0.7), opt  )









