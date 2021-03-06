% Generated by roxygen2 (4.0.2): do not edit by hand
\name{addVersion}
\alias{addVersion}
\title{Adds version watermark to a plot}
\usage{
addVersion(v = NULL, cex = 0.5, col = "#12345655", lengthSHA = 6,
  description = NULL)
}
\arguments{
\item{v}{character vector, version(s) to add to plot}

\item{cex}{numeric, controls the font size}

\item{col}{A color code or name}

\item{description}{character vector, same length as \code{x}, description of each version}
}
\value{
Invisible NULL
}
\description{
Adds the version and, if installed from Github, the first part of the
SHA commit code
}
\details{
All versions in the \code{v} vector are added to the current plot,
each with a discription from \code{description} if it is not \code{NULL}.

If \code{v} is \code{NULL}, the version returned by the internal function \code{getVersion} is used.
}
\examples{
hist(simulateData3()$sample)
addVersion()
}
\author{
alko
}
\seealso{
"Color specification" in the documentation of \code{\link{par}}
}
\keyword{aplot}

