# implement formulae in Hillis 2014 appropriately modified for unequal 
# numbers of readers in different treatments
# for split plot A design only
# TBA this code assumes two treatments
ORAnalysisSplitPlotA <- function(dataset, FOM, FPFValue, alpha = 0.05, analysisOption = "ALL")  
{
  
  if (dataset$descriptions$design != "SPLIT-PLOT-A") stop("This functions requires a SPLIT-PLOT-A dataset")  
  
  I <- dim(dataset$ratings$NL)[1]; if (I != 2) stop(" ORAnalysisSplitPlotA assumes two treatments")
  J <- dim(dataset$ratings$NL)[2]
  modalityID <- dataset$descriptions$modalityID
  
  theta_ij <- as.matrix(UtilFigureOfMerit(dataset, FOM, FPFValue))
  
  theta_i_dot <- array(dim = I) # average over readers, the indices are i followed by j
  J_i <- array(dim = I) # number of readers in treatment i
  for (i in 1:I) {
    J_i[i] <- length(theta_ij[i,][!is.na(theta_ij[i,])])
    theta_i_dot[i] <- mean(theta_ij[i,][!is.na(theta_ij[i,])])
  }
  theta_dot_dot <- mean(theta_i_dot) # average over rdrs and trts
  
  trtMeanDiffs <- theta_i_dot[1] - theta_i_dot[2] # restricted to two modalities for now
  diffTRName <- paste0("trt", modalityID[1], sep = "-", "trt", modalityID[2])
  trtMeanDiffs_df <- data.frame("Estimate" = trtMeanDiffs,
                                row.names = diffTRName,
                                stringsAsFactors = FALSE)
  
  FOMs <- list(
    foms = theta_ij,
    trtMeans = theta_i_dot,
    trtMeanDiffs = trtMeanDiffs_df
  )
  
  # msT denotes MS(T), in Hillis 2014 p 344
  msT <- 0
  for (i in 1:I) {
    # adapted from Hillis 2014, definition of MS(T), just after Eqn. 4
    # move the treatment specific J_i[i] inside the i-summation showed there
    msT <- msT + J_i[i]*(mean(theta_i_dot[i]) - theta_dot_dot)^2
  }
  msT <- msT/(I - 1) # the common J used to appear here: J*msT/(I - 1)
  
  # following is needed for CI on avg. FOM, see below
  # MS(R)_i = sum_j(theta_dot_j - theta_dot_dot)^2/(J_i-1)
  msR_i <- array(0, dim = I)
  for (i in 1:I) {
    for (j in 1:J_i[i]) {
      msR_i[i] <- msR_i[i] + 
        (mean(theta_ij[,j][!is.na(theta_ij[,j])]) - theta_dot_dot)^2
      # first term on rhs is theta_dot_j
    }
    msR_i <- msR_i / (J_i[i] - 1 )
  }
  
  # msR_T_ denotes MS[R(T)], in Hillis 2014 p 344, where R(T) is reader nested within treatment
  # adapted from Hillis 2014, definition of MS[R(T)], last line on page 344
  # move the treatment specific J_i[i] inside the i-summation showed there
  msR_T_ <- 0
  msR_T_i <- rep(0,I)
  for (i in 1:I) {
    for (j in 1:J) {
      if (is.na(theta_ij[i, j])) next
      msR_T_i[i] <- msR_T_i[i] + (theta_ij[i, j] - theta_i_dot[i])^2 / (J_i[i] - 1)
    }
  }
  msR_T_ <- sum(msR_T_i) / I
  
  trtNames <- NULL
  for (i in 1:I) {
    trtNames <- c(trtNames, paste0("trt", modalityID[i]))
  }
  
  ret1 <- UtilPseudoValues(dataset, FOM, FPFValue)
  ret <- FOMijk2VarCovSpA(ret1$jkFomValues, varInflFactor = TRUE)
  Var_i <- ret$Var_i
  Cov2_i <- ret$Cov2_i
  Cov3_i <- ret$Cov3_i
  
  ANOVA <- data.frame("msT" = c(msT, NA),
                      "msR" = msR_i,
                      "msR_T_" = msR_T_,
                      "Var_i" = Var_i,
                      "Cov2_i" = Cov2_i,
                      "Cov3_i" = Cov3_i,
                      stringsAsFactors = FALSE)  
  rownames(ANOVA) <- trtNames
  
  # now do the F_OR statistic; den = denominator of last equation on page 344
  # minus the MS[R(T)] term
  # the contributions of the two reader groups have been separately added
  den <- 0
  for (i in 1:I) den <- den + J_i[i] * max(Cov2_i[i]-Cov3_i[i],0)
  F_OR <- msT/(msR_T_ + den) # add the the MS[R(T)] term to den
  # Note: above expression reduces to equal-reader form
  
  # now implement the df3 formula on page 345
  # Assumption: degrees of freedom for each treatment can be added
  df2 <- 0
  for (i in 1:I) { 
    # temp = num. of expression on r.h.s. of Eqn. 27, 
    # separated into contribution from each treatment
    temp <- (msR_T_i[i] +  J_i[i] * max(Cov2_i[i]-Cov3_i[i],0))^2
    # divide by the denominator and multiply by (J_i[i]-1)
    # The I term is not needed, as we are summing contribution from each treatment
    temp <- temp /(msR_T_i[i]^2)*(J_i[i]-1)
    # cat("df2 for modality = ", temp, "\n")
    # Add to df2
    df2 <- df2 + temp
  } 
  # above expression reduces to equal-reader form 
  # note absence of I-factor on rhs
  # because it is effectively "in there" due to the summation over i
  
  # compute the p-value
  pValue <- 1 - pf(F_OR, I - 1, df2)
  # F_OR_num_den = array with two elements, the numerator of the expression for
  # F_OR followed by the denominator
  # DF = degrees of freedom array, numerator followed by denominator
  RRRC <- list()
  RRRC$FTests <- data.frame(DF = c((I-1),df2),
                            "F_OR_num_den" = c(msT, msR_T_ + den),
                            FStat = c(F_OR, NA),
                            p = c(pValue, NA),
                            row.names = c("Treatment", "Error"),
                            stringsAsFactors = FALSE)
  
  # confidence intervals for difference FOM, trtMeanDiffs, 
  # as on page 346, first para; note that trtMeanDiffs = theta_1_dot - theta_2_dot
  # l_1 = 1; l_2 = - 1
  # Note to myself: Hillis does not state a constraint on the l_i, namely they 
  # should sum to zero; otherwise one could use l_1 = l_2 = 1/2 and compute the CI
  # on the average FOM using the very same method, which is not right
  V_hat <- 0
  for (i in 1:I) {
    V_hat <- V_hat + 
      (1 / J_i[i]) * 2 * (msR_T_i[i] + J_i[i] * max(Cov2_i[i]-Cov3_i[i],0))
  }
  stdErr <- sqrt(V_hat)
  
  # again, this is restricted to two modalities  
  alpha <- 0.05
  CI <- sort(c(trtMeanDiffs - qt(alpha/2, df2) * stdErr, 
               trtMeanDiffs + qt(alpha/2, df2) * stdErr))
  RRRC$ciDiffTrt <- data.frame(Estimate = trtMeanDiffs, 
                               StdErr = stdErr, 
                               DF = df2, 
                               CILower = CI[1],
                               CIUpper = CI[2], 
                               row.names = "trt1-trt2", 
                               stringsAsFactors = FALSE)
  
  # confidence intervals for average FOM, as on page 346, first para
  # second method, using only data from each modality
  V_hat_i <- array(0, dim = I)
  df2_i <- array(dim = I)
  stdErr_i <- array(dim = I)
  ciAvgRdrEachTrt <- array(dim = c(I,2))
  ci <- data.frame()
  for (i in 1:I) {
    V_hat_i[i] <- {
      V_hat_i[i] + 
        # this is the formula for V_hat_i[i] in the text area in the middle of page 346
        # after we account for the different number of readers in each treatment
        (1 / J_i[i]) * (msR_i[i] + J_i[i] * max(Cov2_i[i],0))
    }
    # this is the formula for df2_i[i] in the text area in the middle of page 346
    # after we account for the different number of readers in each treatment
    df2_i[i] <- (msR_i[i] +  J_i[i] * max(Cov2_i[i],0))^2/(msR_i[i]^2)*(J_i[i]-1)
    stdErr_i[i] <- sqrt(V_hat_i[i])
    ciAvgRdrEachTrt[i,] <- sort(c(theta_i_dot[i] - qt(alpha/2, df2_i[i]) * stdErr_i[i], 
                                  theta_i_dot[i] + qt(alpha/2, df2_i[i]) * stdErr_i[i]))
    rowName <- paste0("trt", modalityID[i])
    ci <- rbind(ci, data.frame(Estimate = theta_i_dot[i], 
                               StdErr = stdErr_i[i],
                               DF = df2_i[i],
                               CILower = ciAvgRdrEachTrt[i,1],
                               CIUpper = ciAvgRdrEachTrt[i,2],
                               row.names = rowName,
                               stringsAsFactors = FALSE))
  }
  RRRC$ciAvgRdrEachTrt <- ci  
  
  return(list(
    FOMs = FOMs,
    ANOVA = ANOVA,
    RRRC = RRRC
  ))
  
} 



ORAnalysisSplitPlotC <- function(dataset, FOM, FPFValue, alpha = 0.05, analysisOption = "ALL")  
{
  
  RRRC <- NULL
  FRRC <- NULL
  RRFC <- NULL
  
  modalityID <- dataset$descriptions$modalityID
  I <- length(modalityID)
  
  # `as.matrix` is NOT absolutely necessary as `mean()` function is not used
  foms <- UtilFigureOfMerit(dataset, FOM, FPFValue)
  
  ret <- ORVarComponentsSpC(dataset, FOM, FPFValue)
  
  TRanova <- ret$TRanova
  VarCom <-  ret$VarCom
  IndividualTrt <- ret$IndividualTrt
  IndividualRdr <- ret$IndividualRdr
  
  ANOVA <- list()
  ANOVA$TRanova <- TRanova
  ANOVA$VarCom <- VarCom
  ANOVA$IndividualTrt <- IndividualTrt
  ANOVA$IndividualRdr <- IndividualRdr
  
  trtMeans <- rowMeans(foms)
  trtMeans <- as.data.frame(trtMeans)
  colnames(trtMeans) <- "Estimate"
  
  trtMeanDiffs <- array(dim = choose(I, 2))
  diffTrtName <- array(dim = choose(I, 2))
  ii <- 1
  for (i in 1:I) {
    if (i == I) 
      break
    for (ip in (i + 1):I) {
      trtMeanDiffs[ii] <- trtMeans[i,1] - trtMeans[ip,1]
      diffTrtName[ii] <- paste0("trt", modalityID[i], sep = "-", "trt", modalityID[ip]) # !sic
      ii <- ii + 1
    }
  }
  trtMeanDiffs <- data.frame("Estimate" = trtMeanDiffs,
                             row.names = diffTrtName,
                             stringsAsFactors = FALSE)
  
  FOMs <- list(
    foms = foms,
    trtMeans = trtMeans,
    trtMeanDiffs = trtMeanDiffs
  )
  
  if (analysisOption == "RRRC") {
    RRRC <- ORSummaryRRRC(dataset, FOMs, ANOVA, alpha, diffTrtName)
    return(list(
      FOMs = FOMs,
      ANOVA = ANOVA,
      RRRC = RRRC
    ))
  }  
  
  if (analysisOption == "FRRC") {
    FRRC <- ORSummaryFRRC(dataset, FOMs, ANOVA, alpha, diffTrtName)
    return(list(
      FOMs = FOMs,
      ANOVA = ANOVA,
      FRRC = FRRC
    ))
  }  
  
  if (analysisOption == "RRFC") {
    RRFC <- ORSummaryRRFC(dataset, FOMs, ANOVA, alpha, diffTrtName)
    return(list(
      FOMs = FOMs,
      ANOVA = ANOVA,
      RRFC = RRFC
    ))
  }  
  
  if (analysisOption == "ALL") {
    RRRC <- ORSummaryRRRC(dataset, FOMs, ANOVA, alpha, diffTrtName)
    FRRC <- ORSummaryFRRC(dataset, FOMs, ANOVA, alpha, diffTrtName)
    RRFC <- ORSummaryRRFC(dataset, FOMs, ANOVA, alpha, diffTrtName)
    return(list(
      FOMs = FOMs,
      ANOVA = ANOVA,
      RRRC = RRRC,
      FRRC = FRRC,
      RRFC = RRFC
    ))
  }  else stop("Incorrect analysisOption: must be `RRRC`, `FRRC`, `RRFC` or `ALL`")
  
} 



ORVarComponentsSpC <- function (dataset, FOM, FPFValue = 0.2)
{
  
  if (dataset$descriptions$design != "SPLIT-PLOT-C") stop("This functions requires a SPLIT-PLOT-C dataset")  
  
  I <- dim(dataset$ratings$NL)[1]
  J <- dim(dataset$ratings$NL)[2]
  
  theta_ij <- as.matrix(UtilFigureOfMerit(dataset, FOM, FPFValue))
  
  theta_dot_dot <- mean(theta_ij[,]) # this fails if `theta_ij` is a dataframe; true for `mean` and `median`
  
  if (I > 1) {
    msT <- 0
    for (i in 1:I) {
      msT <- msT + (mean(theta_ij[i, ]) - theta_dot_dot)^2
    }
    msT <- J * msT/(I - 1)
  } else msT <- NA
  
  if (J > 1) {
    msR <- 0
    for (j in 1:J) {
      msR <- msR + (mean(theta_ij[, j]) - theta_dot_dot)^2
    }
    msR <- I * msR/(J - 1)
  } else msR <- NA
  
  if ((I > 1) && (J > 1)) {
    msTR <- 0
    for (i in 1:I) {
      for (j in 1:J) {
        msTR <- msTR + (theta_ij[i, j] - mean(theta_ij[i, ]) - mean(theta_ij[, j]) + theta_dot_dot)^2
      }
    }
    msTR <- msTR/((J - 1) * (I - 1))
  } else msTR <- NA
  
  msArray <- c(msT, msR, msTR)
  dfArray <- c(I - 1, J - 1, (I - 1) * (J - 1))
  ssArray <- msArray * dfArray
  
  TRanova <- data.frame("SS" = ssArray, 
                        "DF" = dfArray, 
                        "MS" = msArray,
                        stringsAsFactors = FALSE)  
  rownames(TRanova) <- c("T", "R", "TR")
  
  # single treatment msR_i ############################################################
  if (J > 1) {
    msR_i <- array(0, dim = I)
    for (i in 1:I) {
      for (j in 1:J) {
        msR_i[i] <- msR_i[i] + (theta_ij[i, j] -  mean(theta_ij[i,]))^2
      }
    }
    msR_i <- msR_i/(J - 1)
  } else msR_i <- NA
  
  cov2EachTrt <- vector(length = I)
  varEachTrt <- vector(length = I)
  for (i in 1:I) {
    dsi <- DfExtractDataset(dataset, trts = i)
    ret <- OrVarCovMatrixSpC(dsi, FOM, FPFValue)
    varEachTrt[i] <- ret$Var
    cov2EachTrt[i] <- ret$Cov2
  }
  
  modID <- as.vector(dataset$descriptions$modalityID)
  IndividualTrt <- data.frame(DF = rep(J-1, I), 
                              msREachTrt = msR_i, 
                              varEachTrt = varEachTrt, 
                              cov2EachTrt = cov2EachTrt, 
                              row.names = paste0("trt", modID),
                              stringsAsFactors = FALSE)
  # } else IndividualTrt <- NA # these are not defined for split-plot-c datasets
  
  # single reader msT_j ###############################################################
  if (I > 1) {
    msT_j <- array(0, dim = J)
    for (j in 1:J) {
      for (i in 1:I) {
        msT_j[j] <- msT_j[j] + (mean(theta_ij[i, j]) -  mean(theta_ij[,j]))^2
      }
      msT_j[j] <- msT_j[j]/(I - 1)
    }
  } else msT_j <- NA
  
  varEachRdr <- vector(length = J)
  cov1EachRdr <- vector(length = J)
  for (j in 1:J) {
    dsj <- DfExtractDataset(dataset, rdrs = j)
    ret <- OrVarCovMatrixSpC(dsj, FOM, FPFValue)
    varEachRdr[j] <- ret$Var
    cov1EachRdr[j] <- ret$Cov1
  }
  
  rdrID <- as.vector(dataset$descriptions$readerID)
  if (I > 1) {
    IndividualRdr <- data.frame(DF = rep(I-1, J), 
                                msTEachRdr = msT_j, 
                                varEachRdr = varEachRdr, 
                                cov1EachRdr = cov1EachRdr, 
                                row.names = paste0("rdr", rdrID),
                                stringsAsFactors = FALSE)
  } else IndividualRdr <- NA
  #####################################################################################
  ret <- OrVarCovMatrixSpC(dataset, FOM, FPFValue)
  Var <- ret$Var
  Cov1 <- ret$Cov1
  Cov2 <- ret$Cov2
  Cov3 <- ret$Cov3
  
  if (I > 1) {
    # Following equation is in marginal means paper, page 333
    # and in Hillis 2011 Eqn 9
    VarTR <- msTR - Var + Cov1 + max(Cov2 - Cov3, 0)
    # NOTE on discrepancy between Var(R) and Var(TR) values reported by
    # OR-DBM MRMC 2.51 Build 20181028 and my code for Franken dataset
    # Their code does not implement the max() constraint while mine does
    # my code reports VarTR = -0.00068389146 while their code reports
    # VarTR = -0.00071276; This is shown explicitly next:
    # msTR - Var + Cov1 + max(Cov2 - Cov3, 0) = -0.00068389146 
    # msTR - Var + Cov1 +     Cov2 - Cov3     = -0.00071276 
    # This also affects the VarR values calculated next (see next block of comments)
    # Cov1, Cov2, Cov3 and Var are the same between both codes
  } else VarTR <- NA
  
  # See Hillis 2006 Table 1 2nd eauation
  VarR <- (msR - VarTR - Var + Cov2 - (I-1)*(Cov1 - Cov3))/I
  # Their code reports: VarR = 0.00003766 
  # my code reports: VarR = 2.3319942e-05
  # This is shown explicitly next:
  # (msR - Var - (I - 1) * Cov1 + Cov2 + (I - 1) * Cov3 - (-0.00071276))/I = 3.7754211e-05
  # (msR - Var - (I - 1) * Cov1 + Cov2 + (I - 1) * Cov3 - VarTR)/I = 2.3319942e-05
  VarCom <- data.frame(Estimates = c(VarR, VarTR, Cov1, Cov2, Cov3, Var), 
                       Rhos = c(NA, NA, Cov1/Var, Cov2/Var, Cov3/Var, NA),
                       row.names = c("VarR", "VarTR", "Cov1", "Cov2", "Cov3", "Var"),
                       stringsAsFactors = FALSE)
  return(list(
    TRanova = TRanova,
    VarCom = VarCom,
    IndividualTrt = IndividualTrt,
    IndividualRdr = IndividualRdr
  ))
  
}



# select and retrieve covariance estimates according to value of `covEstMethod`
# works only for split plot C datasets
OrVarCovMatrixSpC <- function(dataset, FOM, FPFValue) 
{
  if (dataset$descriptions$design != "SPLIT-PLOT-C") stop("This functions requires a split plot C dataset")  
  
  ret <- varComponentsJackknifeSpC(dataset, FOM, FPFValue)
  
  return(ret)
  
}  



varComponentsJackknifeSpC <- function(dataset, FOM, FPFValue) {
  if (dataset$descriptions$design != "SPLIT-PLOT-C") stop("This functions requires a factorial dataset")  
  
  I <- length(dataset$ratings$NL[,1,1,1])
  J <- length(dataset$ratings$NL[1,,1,1])
  
  ret <- UtilPseudoValues(dataset, FOM, FPFValue)
  Var <- array(dim = J)
  Cov1 <- array(dim = J)
  caseTransitions <- ret$caseTransitions
  for (j in 1:J) {
    jkFOMs <- ret$jkFomValues[,j,(caseTransitions[j]+1):(caseTransitions[j+1]), drop = FALSE]
    kj <- length(jkFOMs)/I
    dim(jkFOMs) <- c(I,1,kj)
    x <- FOMijk2VarCov(jkFOMs, varInflFactor = FALSE)
    # not sure which way to go: was doing this until 2/18/20
    # Var[j]  <-  x$Var * (K-1)^2/K
    # Cov1[j]  <-  x$Cov1 * (K-1)^2/K
    # following seems more reasonable as reader j only interprets kj cases
    # updated file ~Dropbox/RJafrocChecks/StfrocSp.xlsx
    Var[j]  <-  x$Var * (kj-1)^2/kj
    Cov1[j]  <-  x$Cov1 * (kj-1)^2/kj
  }
  Cov <- list(
    Var = mean(Var),
    Cov1 = mean(Cov1),
    Cov2 = 0,
    Cov3 = 0
  )
  
  return(Cov)
  
}




