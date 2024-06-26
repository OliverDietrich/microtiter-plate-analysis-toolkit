#' Import plate layout
#'
#' Import plate layout from excel file
#'
#' @param file_path Location of file
#' @param well_key Column indicating wells in microtiter plate
#'
#' @export
#'
import_plateLayout <- function(
    file_path = NULL,
    well_key  = "well"
) {

  stopifnot(
    !is.null(file_path),
    file.exists(file_path)
  )

  # Read data
  object <- as.data.frame(readxl::read_excel(file_path))

  # Remove empty rows
  object <- object[!is.na(object$well), ]

  # Extract rows (A, B, C, ...) from well_key (A1, B1, ...) and store as factor
  object$row <- as.character(stringr::str_split_fixed(object$well, "", n = 2)[, 1])
  object$row <- factor(object$row, LETTERS[1:match(tail(sort(object$row), 1), LETTERS)])

  # Extract cols (1, 2, 3, ...) from well_key (A1, A2, ...) and store as factor
  object$col <- as.numeric(stringr::str_split_fixed(object$well, "", n = 2)[, 2])
  object$col <- factor(object$col, 1:max(object$col))

  return(object)
}

#' Import data from Tekan Spark
#'
#' Import plate reader data from an excel sheet using the formatting by
#' Tekan's Spark.
#'
#' @param file_path Location of file (must be xls or xlsx)
#'
#' @returns Tidy data frame with six columns (cycle, time, temp, well, count, mode)
#' @export
#'
import_tekanSpark <- function(
    file_path = NULL
) {

  stopifnot(
    file.exists(file_path)
  )

  # Check input type
  if (!any(endsWith(file_path, c("xlsx", "xls")))) {
    stop("Unknown data format. Please specify excel file (.xlsx)")
  }

  # Read data
  object <- as.data.frame(readxl::read_excel(file_path, col_names = FALSE))

  # Re-format data
  data <- list()
  index <- which(stringr::str_detect(object[[1]], "Label"))
  names(index) <- paste("Label", 1:length(index), sep = "_")
  for (ind in names(index)) {

    # Set index
    i <- index[[ind]]

    # Extract measurement modes
    name <- object[[1]][i]
    mode <- object[[2]][which(stringr::str_detect(object[[2]], name))-1]

    # Detect data frame
    top <- which(object[[1]] == name) + 1
    na_vert <- which(is.na(object[[1]]))
    bottom <- min(na_vert[na_vert > top]) - 1

    # Extract data frame
    df <- object[top:bottom, ]
    col_names <- as.character(df[, 1])
    col_names[1:3] <- c("cycle", "time", "temp")
    df <- as.data.frame(t(df)) # Note: if colnames are not extracted above, formatting errors might occur (R 3.5.1)
    df <- df[-1, ]
    colnames(df) <- col_names

    # Re-format with tidyr::gather throws error in Jupyter !!!

    # Add measurement mode
    df$mode <- mode

    # Add to list
    data[[ind]] <- df
    rm(df)
  }

  # Concatenate lists
  data <- dplyr::bind_rows(data)

  # Re-format
  data <- tidyr::gather(data, "well", "count", -cycle, -time, -temp, -mode)

  # Adjust data types
  for (i in c("time", "temp", "count")) {
    data[[i]] <- as.numeric(as.character(data[[i]]))
  }
  data[["time"]] <- data[["time"]] / 60 / 60
  for (i in c("well", "mode", "cycle")) {
    data[[i]] <- as.character(data[[i]])
  }

  return(data)
}
