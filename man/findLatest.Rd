% Generated by roxygen2 (4.0.2): do not edit by hand
\name{findLatest}
\alias{findLatest}
\title{Find newest file in folder matching pattern}
\usage{
findLatest(path = ".", pattern = "")
}
\arguments{
\item{path}{character, relative or absolute path}

\item{patterm}{an optional \code{\link{regex}}. Only file names which match the regular expression will be returned. Passed to \code{\link{dir}}}
}
\description{
Given a folder and a pattern, rerurns the file that was modified latest.
}
\seealso{
\code{dir}
}

