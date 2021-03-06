

#' # 
#' 
#' nested_cv.plscorr_result_contrast <- function(x, innerFolds, heldout, metric="AUC", min.comp=1) {
#'   res <- lapply(innerFolds, function(fidx) {
#'     print(fidx)
#'     exclude <- sort(c(fidx,heldout))
#'     prescv <- plscorr_contrast(x$X[-exclude,,drop=FALSE], x$G[-exclude,], x$strata[-exclude], ncomp=x$ncomp, 
#'                       center=x$center, scale=x$scale, svd.method=x$svd.method)
#'             
#'     pscores <- lapply(seq(min.comp, x$ncomp), function(n) {
#'       Xdat <- x$X[fidx,,drop=FALSE]
#'       Xb <- t(t(Xdat) %*% x$G[fidx,])
#'       list(pred=predict.plscorr_result_da(prescv, Xb, ncomp=n, type="prob"), obs=colnames(x$G))
#'     })
#'   })
#'   
#'   metric <- unlist(lapply(seq(min.comp, x$ncomp), function(n) {
#'     Plist <- lapply(res, "[[", n)
#'     obs <- unlist(lapply(Plist, "[[", "obs"))
#'     obs <- factor(obs, levels=colnames(x$G))
#'     pred <- do.call(rbind, lapply(Plist, "[[", "pred"))
#'     if (metric == "AUC") {
#'       combinedACC(pred, obs)
#'     } else if (metric == "ACC") {
#'       combinedAUC(pred, obs)
#'     }
#'   }))
#' }
#' 
#' 
#' 
#' 
#' 
#' 
#' stratified_folds <- function(strata, nfolds=2) {
#'   blocks <- split(1:length(strata), strata)
#'   bfolds <- caret::createFolds(1:length(blocks), nfolds)
#'   lapply(bfolds, function(f) unlist(blocks[f]))
#' }
#' 
#' cross_validate.plscorr_result_contrast <- function(x, nfolds=2, nrepeats=10, metric=c("ACC", "distance"), nested=FALSE, max.comp=2) {
#'   
#'   M <- list()
#'   for (i in 1:nrepeats) {
#'     message("cross-validation iteration:", i)
#'     folds <- stratified_folds(x$strata, nfolds)
#'     
#'     ret <- lapply(1:length(folds), function(j) {
#'       exclude <- folds[[j]]
#'       prescv <- plscorr_contrast(x$X[-exclude,,drop=FALSE], x$G[-exclude,], x$strata[-exclude], ncomp=x$ncomp, 
#'                                center=x$center, scale=x$scale, svd.method=x$svd.method)
#'     
#'       pscores <- lapply(seq(1, max.comp), function(n) {
#'         Xdat <- x$X[exclude,,drop=FALSE]
#'         Xb <- blockwise_average(Xdat, x$G[exclude,], factor(strata[exclude]), center=FALSE, scale=FALSE)
#'         #Xb <- t(t(Xdat) %*% x$G[exclude,])
#'         list(pred=predict.plscorr_result_da(prescv, Xb, ncomp=n, type="class"), obs=colnames(x$G))
#'       })
#'     })
#'     
#'     M[[i]]  <- unlist(lapply(seq(1, max.comp), function(n) {
#'       Plist <- lapply(ret, "[[", n)
#'       obs <- unlist(lapply(Plist, "[[", "obs"))
#'       obs <- factor(obs, levels=colnames(x$G))
#'       pred <-unlist(lapply(Plist, "[[", "pred"))
#'       sum(obs == pred)/length(obs)
#'     }))
#'   }
#'   
#' }
#' 
#' 
#' 
#' plscorr_lm <- function(X, formula, design, random=NULL, ncomp=2, center=TRUE, scale=TRUE, svd.method="base") {
#'   tform <- terms(formula)
#'   facs <- attr(tform, "factors")
#'   
#'   termorder <- apply(facs,2, sum)
#'   orders <- seq(1, max(termorder))
#'   
#'   strata <- if (!is.null(random)) {
#'     design[[random]]
#'   }
#'   
#'   
#'   get_lower_form <- function(ord) {
#'     tnames <- colnames(facs)[termorder < ord]
#'     
#'     meat <- if (!is.null(random)) {
#'       paste0("(", paste(tnames, collapse= " + "), ")*", random)
#'     } else {
#'       paste(tnames, collapse= " + ")
#'     }
#'     
#'     as.formula(paste("X ~ ", meat))
#'   }
#'   
#'   fit_betas <- function(X, G) {
#'     if (!is.null(strata)) {
#'       dummy_matrix <- turner::factor_to_dummy(as.factor(strata))
#'       
#'       Xblocks <- lapply(1:ncol(dummy_matrix), function(i) {
#'         ind <- dummy_matrix[,i] == 1
#'         Xs <- X[ind,]
#'         lsfit(G[ind,], Xs, intercept=FALSE)$coefficients
#'       })
#'       
#'       Reduce("+", Xblocks)/length(Xblocks)
#'     
#'     } else {
#'       lsfit(G, X, intercept=FALSE)$coefficients
#'     }
#'     
#'   }
#'   
#'   res <- lapply(1:length(termorder), function(i) {
#'     ord <- termorder[i]
#'     if (ord == 1) {
#'       form <- as.formula(paste("X ~ ", colnames(facs)[i], "-1"))
#'       G <- model.matrix(form,data=design)
#'       betas <- fit_betas(X, G)
#'       plsres <- plscorr_contrast(betas, turner::factor_to_dummy(factor(colnames(G))), strata=NULL, 
#'                                  center=center, scale=scale, ncomp=ncomp, svd.method=svd.method)
#'       list(G=G, form=form, lower_form = ~ 1, plsres=plsres)
#'     } else {
#'       lower_form <- get_lower_form(ord)
#'       Glower <- model.matrix(lower_form, data=design)
#'       Xresid <- resid(lsfit(Glower, X, intercept=FALSE))
#'       form <- as.formula(paste("Xresid ~ ", colnames(facs)[i], "-1"))
#'       G <- model.matrix(form, data=design)
#'       betas <- fit_betas(Xresid, G)
#'       plsres <- plscorr_contrast(Xresid, turner::factor_to_dummy(factor(colnames(G))), center=center, scale=scale, ncomp=ncomp, svd.method=svd.method)
#'       list(G=G, form=form, lower_form = lower_form, plsres=plsres)
#'     }
#'   })
#'   
#'   names(res) <- colnames(facs)
#'   ret <- list(
#'     results=res,
#'     formula=formula,
#'     design=design,
#'     terms=colnames(facs)
#'   )
#'   
#'   
#'   class(ret) <- "plscorr_result_cpca"
#'   ret
#'   
#' }
#'  
#' 
#' #' plscorr_aov
#' #' 
#' #' @export
#' #' @param X the data matrix
#' #' @param formula a formula specifying the design
#' #' @param design a \code{data.frame} providing the variables provided in \code{formula} argument.
#' #' @param random a \code{character} string indicating the name of the random effects variable
#' #' @param ncomp of components to compute
#' plscorr_aov <- function(X, formula, design, random=NULL, ncomp=2, center=TRUE, scale=TRUE, svd.method="base") {
#'   tform <- terms(formula)
#'   facs <- attr(tform, "factors")
#'   
#'   termorder <- apply(facs,2, sum)
#'   orders <- seq(1, max(termorder))
#'   
#'   #if (!is.null(random)) {
#'   #  random2 <- update.formula(random,  ~ . -1)
#'   #  Grandom <- model.matrix(random, data=design)
#'   #  random_list <- turner::dummy_to_list(Grandom)
#'   #}
#'   
#'   strata <- if (!is.null(random)) {
#'     as.factor(design[[random]])
#'   } else {
#'     NULL
#'   }
#'   
#'   
#'   get_lower_form <- function(ord) {
#'     tnames <- colnames(facs)[termorder < ord]
#'     
#'     meat <- if (!is.null(random)) {
#'       paste0("(", paste(tnames, collapse= " + "), ")*", random)
#'     } else {
#'       paste(tnames, collapse= " + ")
#'     }
#'     
#'     
#'     as.formula(paste("X ~ ", meat))
#'   }
#'   
#'   res <- lapply(1:length(termorder), function(i) {
#'     ord <- termorder[i]
#'     if (ord == 1) {
#'       form <- as.formula(paste("X ~ ", colnames(facs)[i], "-1"))
#'       G <- model.matrix(form,data=design)
#'       cnames <- colnames(G)
#'       Y <- factor(cnames[apply(G, 1, function(x) which(x==1))], levels=cnames)
#'       plsres <- plscorr_contrast(X, G, strata, center=center, scale=scale, ncomp=ncomp, svd.method=svd.method)
#'       list(G=G, Y=Y, Glower=NULL, form=form, lower_form = ~ 1, plsres=plsres)
#'     } else {
#'       lower_form <- get_lower_form(ord)
#'       Glower <- model.matrix(lower_form, data=design)
#'       Xresid <- resid(lsfit(Glower, X, intercept=FALSE))
#'       form <- as.formula(paste("Xresid ~ ", colnames(facs)[i], "-1"))
#'       G <- model.matrix(form, data=design)
#'       cnames <- colnames(G)
#'       Y <- factor(cnames[apply(G, 1, function(x) which(x==1))])
#'       plsres <- plscorr_contrast(Xresid, G, strata=strata, center=center, scale=scale, ncomp=ncomp, svd.method=svd.method)
#'       list(G=G, Glower, form=form, lower_form = lower_form, plsres=plsres)
#'     }
#'   })
#'   
#'   permute <- function(obj) {
#'     idx <- sample(1:nrow(obj$X))
#'     list(X=obj$X, Y=obj$Y[idx,], idx=idx, group=group[idx])
#'   }
#'   
#'   names(res) <- colnames(facs)
#'   ret <- list(
#'     results=res,
#'     formula=formula,
#'     strata=strata,
#'     design=design,
#'     terms=colnames(facs)
#'   )
#'   
#'   
#'   class(ret) <- "plscorr_result_aov"
#'   ret
#'   
#' }
#' 
#' # 
#' #' @export
#' #' @import turner
#' plscorr_behav <- function(Y, X, group=NULL, random=NULL, ncomp=2, svd.method="base") {
#'     if (is.vector(Y)) {
#'       Y <- as.matrix(Y)
#'     }
#'     
#'     if (is.null(colnames(Y))) {
#'       colnames(Y) <- paste0("V", 1:ncol(Y))
#'     }
#'     
#'     assert_that(nrow(Y) == nrow(X))
#'     assert_that(length(group) == nrow(X))
#'     
#'     reduce <- function(obj) {
#'       blockids <- split(seq(1,nrow(obj$X)), obj$group)
#'       
#'       Xs <- turner::matrix_to_blocks(obj$X, blockids)
#'       Ys <- turner::matrix_to_blocks(obj$Y, blockids)
#'    
#'       Xs <- lapply(Xs, scale)
#'       Ys <- lapply(Ys, scale)
#'     
#'       R <- lapply(1:length(Xs), function(i) {
#'         t(cor(Xs[[i]], Ys[[i]]))
#'       })
#'     
#'       do.call(cbind, R)
#'     }
#'     
#'     bootstrap_sample <- function() {
#'       idx <- unlist(lapply(blockids, function(ids) sort(sample(ids, replace=TRUE))))
#'       YBoot <- Y[idx,]
#'       XBoot <- X[idx,]
#'       list(XBoot=XBoot, YBoot=YBoot, idx=idx, group=group[idx])
#'     }
#'     
#'     permute <- function(obj) {
#'       idx <- sample(1:nrow(obj$X))
#'       list(X=obj$X, Y=obj$Y[idx,], idx=idx, group=group[idx])
#'     }
#'     
#'     Yvars <- rep(colnames(Y), length(levels(group)))
#'     Gvars <- rep(levels(group), each=ncol(Y))
#'     
#'     Xred <- reduce(list(X=X, Y=Y, group=group))
#'     
#'     svdres <- svd.wrapper(t(Xred), ncomp, svd.method)
#'     scores <- svdres$v %*% diag(svdres$d, nrow=svdres$ncomp, ncol=svdres$ncomp)
#'     
#'     refit <- function(Y, X, group, ncomp, ...) { plscorr_behav(Y, X, group, ncomp, ...) }
#'       
#'     
#'     ret <- list(X=X, Y=Y, Xred=Xred, design=data.frame(Y=Yvars, group=Gvars), ncomp=svdres$ncomp, 
#'                 svd.method=svd.method, scores=scores, v=svdres$v, u=svdres$u, d=svdres$d, 
#'                 refit=refit, bootstrap=bootstrap_sample, reduce=reduce, permute=permute)
#'     
#'     class(ret) <- c("plscorr_result", "plscorr_result_behav")
#'     ret
#' }
#' 
#' blockwise_average <- function(X, G, strata, center=TRUE, scale=FALSE) {
#'   dummy_matrix <- turner::factor_to_dummy(as.factor(strata))
#'   
#'   Xblocks <- lapply(1:ncol(dummy_matrix), function(i) {
#'     ind <- dummy_matrix[,i] == 1
#'     scale(t(t(X[ind,]) %*% G[ind,]), center=center, scale=scale)
#'   })
#'   
#'   X0c <- Reduce("+", Xblocks)/length(Xblocks)
#'   
#'   if (center) {
#'     xc <- colMeans(do.call(rbind, lapply(Xblocks, function(x) attr(x, "scaled:center"))))
#'     attr(X0c, "scaled:center") <- xc
#'   }
#'   if (scale) {
#'     xs <- colMeans(do.call(rbind, lapply(Xblocks, function(x) attr(x, "scaled:scale"))))
#'     attr(X0c, "scaled:scale") <- xs
#'   }
#'   
#'   X0c
#'     
#' }
#' 
#' 
#' #' @export
#' #' @import turner
#' plscorr_contrast <- function(X, G, strata=NULL, ncomp=2, center=TRUE, scale=FALSE, svd.method="base") {
#'   assert_that(is.matrix(G))
#'   assert_that(nrow(G) == nrow(X))
#'   
#'   if (!is.null(strata)) {
#'     X0c <- blockwise_average(X, G, strata, center,scale)
#'   } else {
#'     X0 <- t(t(X) %*% G)
#'     X0c <- scale(X0, center=center, scale=scale)
#'   }
#'   
#'   svdres <- svd.wrapper(t(X0c), ncomp, svd.method)
#'   
#'   scores <- svdres$v %*% diag(svdres$d, nrow=svdres$ncomp, ncol=svdres$ncomp)
#'   row.names(scores) <- colnames(G)
#'   
#'   refit <- function(X, G, ncomp, ...) { plscorr_contrast(X, G, strata, ncomp,...) }
#'   
#'   ret <- list(X=X, G=G, ncomp=svdres$ncomp, condMeans=X0c, center=center, scale=scale, pre_process=apply_scaling(X0c), 
#'               svd.method=svd.method, scores=scores, v=svdres$v, u=svdres$u, d=svdres$d, refit=refit, strata=strata)
#'   
#'   class(ret) <- c("plscorr_result", "plscorr_result_contrast")
#'   ret
#'   
#' }
#' 
#' 
#' 
#' 
#' 
#' 
