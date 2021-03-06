% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/UtilORVarComponentsFactorial.R
\name{UtilORVarComponentsFactorial}
\alias{UtilORVarComponentsFactorial}
\title{Utility for estimating Obuchowski-Rockette variance components for factorial datasets}
\usage{
UtilORVarComponentsFactorial(
  dataset,
  FOM,
  FPFValue = 0.2,
  covEstMethod = "jackknife",
  nBoots = 200,
  seed = NULL
)
}
\arguments{
\item{dataset}{The factorial dataset object}

\item{FOM}{The figure of merit}

\item{FPFValue}{Only needed for \code{LROC} data \strong{and} FOM = "PCL" or "ALROC";
where to evaluate a partial curve based figure of merit. The default is 0.2.}

\item{covEstMethod}{The covariance estimation method, "jackknife" 
(the default) or "bootstrap" or "DeLong" (DeLongt is applicable only for 
FOM = Wilcoxon).}

\item{nBoots}{Only needed for bootstrap covariance estimation method. The number 
of bootstraps, defaults to 200.}

\item{seed}{Only needed for the bootstrap covariance estimation method. The initial 
seed for the random number generator, the default is \code{NULL}, as if no seed 
has been specified.}
}
\value{
A list object containing the following \code{data.frames}: 
    \itemize{
    \item{\code{foms}}: the figures of merit for different treatment-reader combinations 
    \item{\code{TRanova}}: the OR treatment-reader ANOVA table 
    \item{\code{VarCom}}: the OR variance-components \code{Cov1}, \code{Cov2}, 
    \code{Cov3}, \code{Var} and correlations \code{rho1}, \code{rho2} and \code{rho3} 
    \item{\code{IndividualTrt}}: the individual treatment mean-squares, \code{Var} and \code{Cov2} values
    \item{\code{IndividualRdr}}: the individual reader mean-squares, \code{Var} and \code{Cov1} values
    }
}
\description{
Utility for estimating Obuchowski-Rockette variance components for factorial datasets
}
\details{
The variance components are obtained using \link{StSignificanceTesting} 
    with \code{method = "OR"}.
}
\examples{
## use the default jackknife for covEstMethod
vc <- UtilORVarComponentsFactorial(dataset02, FOM = "Wilcoxon")
str(vc) 

UtilORVarComponentsFactorial(dataset02, FOM = "Wilcoxon", 
   covEstMethod = "bootstrap", nBoots = 2000, seed = 100)$VarCom 

UtilORVarComponentsFactorial(dataset02, FOM = "Wilcoxon", covEstMethod = "DeLong")$VarCom 
  
}
