#' Lesion distribution of a dataset or convert values specified by 1D array 
#' 
#' @description The lesion distribution for a dataset or convert values 
#'    specified by 1D array.
#' 
#' @param datasetOrLesDistr A dataset or a one-dimensional array containing the lesion 
#'    distribution. For example, c(0.1, 0.2, 0, 0.7) specifies 10 percent of 
#'    diseased cases have one lesion, 20 percent have two lesions, 0 percent 
#'    have 3 lesions and 70 percent have four lesions. See 3rd example below.
#'
#' @return lesDistr The 2D lesion distribution array; 2D array currently needed
#'    by cpp functions.
#' 
#' @details Two characteristics of an FROC dataset, apart from the ratings, 
#'    affect the FOM: the distribution of lesions per case and the distribution 
#'    of lesion weights. This function addresses the lesions. The distribution 
#'    of weights are addressed by \link{UtilLesionWeightsDistr}. \code{lesDistr} is a 
#'    [1:nRow,2] array, where \code{nRow} is the number of \bold{unique} 
#'    values of lesions per case in the dataset, 1, 2, ..., etc. The first 
#'    column of the array contains the number of lesions per case. The second 
#'    column contains the corresponding fraction of diseased cases. 
#'    See \link{PlotRsmOperatingCharacteristics} for a function that depends on 
#'    \code{lesDistr}. See TBA Chapter00Vignette2 for more details.
#'    The underlying assumption is that lesion 1 is the same type across all 
#'    diseased cases, lesion 2 is the same type across all diseased cases, 
#'    etc. This allows assignment of weights independent of the case index.
#'    In the third example below, \code{relWeights} = [0.2, 0.4, 0.1, 0.3] means that
#'    on cases with one lesion the weight of lesion 1 is unity, on cases with two 
#'    lesions the weight of the first lesion to that of the second lesion is
#'    in the ratio 0.2 : 0.4, i.e., lesion 2 is twice as important as lesion 1. 
#'    On cases with 4 lesions the weights are in the ratio 0.2 : 0.4 : 0.1 : 0.3.
#'    There are no cases with 3 lesions in this example. Of course, on any case
#'    the weights sum to unity.
#' 
#' 
#' @examples
#' UtilLesionDistr (dataset01) # FROC dataset
#' UtilLesionDistr (dataset02) # ROC dataset
#' UtilLesionDistr (c(0.1, 0.2, 0, 0.7)) # We specify the distribution
#' 
#' @export 
UtilLesionDistr <- function(datasetOrLesDistr)
{ 
  if (is.list(datasetOrLesDistr) && (length(datasetOrLesDistr) == 3)) {
    dataset = datasetOrLesDistr
    # a dataset has been supplied
    lesionNum <- dataset$lesions$perCase
    lesDistr <- table(lesionNum)
    if (length(lesDistr) == 1) {
      lesDistr <- c(lesionNum[1], 1)
      dim(lesDistr) <- c(1, 2)
    }else{
      lesDistr <- t(rbind(as.numeric(unlist(attr(lesDistr, "dimnames"))), as.vector(lesDistr)))
    }
    lesDistr[,2] <- lesDistr[,2]/sum(lesDistr[,2])
  } else if (is.numeric(datasetOrLesDistr)) { 
    # datasetOrLesDistr is a one dimensional array specifying the lesion distribution
    lesDistr <- datasetOrLesDistr
    lesDistr <- lesDistr/sum(lesDistr) # make sure it sums to 1
    lesDistr <- t(rbind(seq(1:length(lesDistr)), lesDistr))  
    colnames(lesDistr) <- NULL
    rownames(lesDistr) <- NULL
  } else stop("Unknown argment type in UtilLesionDistr")
  return(lesDistr)
}
