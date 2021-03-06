% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/all_generic.R, R/bootstrap.R
\name{bootstrap}
\alias{bootstrap}
\alias{bootstrap.mubada}
\title{bootstrap a model}
\usage{
bootstrap(x, nboot, ...)

\method{bootstrap}{mubada}(
  x,
  niter,
  nboot = 100,
  ncomp = x$ncomp,
  type = c("projection", "rotated", "unrotated")
)
}
\arguments{
\item{x}{the model fit}

\item{nboot}{the number of bootstrap resamples}

\item{...}{extra args}
}
\description{
bootstrap a model
}
\examples{

## mubada bootstrap analysis
Xl <- lapply(1:5, function(i) matrix(rnorm(100*20), 100, 20))
Yl <- lapply(1:5, function(i) factor(rep(letters[1:5], length.out=100)))

mb <- mubada(Yl, Xl)
}
