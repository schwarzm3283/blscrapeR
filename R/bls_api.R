#
#' @title Basic Request Mechanism for BLS Tables
#' @description Return data frame from one or more requests via the US Bureau of Labor Statistics API. Provided arguments are in the form of BLS series ids.
#' @param seriesid The BLS id of the series your trying to load. A common format would be 'LAUCN040010000000005'. 
#' WARNING: All seriesIDs must contain the same time resolution. For example, monthly data sets can not be combined with annual or semi-annual data.
#' If you need help finding seriesIDs, check the BLS website \url{http://www.bls.gov/data/} or the BLS Data Finder \url{http://beta.bls.gov/dataQuery/search}
#' @param startyear The first year in your data set.
#' @param endyear The last year in your data set.
#' @param registrationKey The API key issued to you from the BLS website.
#' @param catalog Series description information available only for certian data sets.
#' @param calculations Returns year-over-year calculations if set to TRUE.
#' @param annualaverage Retruns an annual average if set to TRUE.
#' @keywords bls api economics cpi unemployment inflation
#' @import httr jsonlite data.table
#' @export bls_api
#' @examples
#' 
#' ## Not run:
#' ## API Version 1.0 R Script Sample Code
#' ## Single Series request
#' df <- bls_api('LAUCN040010000000005')
#' 
#' ## End (Not run)
#' 
#' ## Not run:
#' ## API Version 1.0 R Script Sample Code
#' ## Multiple Series request with date params.
#' df <- bls_api(c('LAUCN040010000000005', 'LAUCN040010000000006'), 
#' startyear = '2010', endyear = '2012')
#' 
#' ## End (Not run)
#' 
#' ## Not run:
#' ## API Version 1.0 R Script Sample Code
#' ## Multiple Series request with date params.
#' df <- bls_api(c('LAUCN040010000000005', 'LAUCN040010000000006'), 
#' startyear = '2010', endyear = '2012')
#' 
#' ## End (Not run)
#' #' ## Not run:
#' ## API Version 2.0 R Script Sample Code
#' ## Multiple Series request with full params allowed by v2.
#' df <- bls_api(c("LAUCN040010000000005", "LAUCN040010000000006"),
#' startyear = 2010, endyear = 2012,
#' registrationKey = "2a8526b8746f4889966f64957c56b8fd", 
#' calculations = TRUE, annualaverage = TRUE, catalog = TRUE)
#' 
#' 
#' ## End (Not run)
# TODO: Put an a warning if user exceeds maximun number of years allowed by the BLS.
bls_api <- function (seriesid, startyear = NULL, endyear = NULL, registrationKey = NULL, 
                      catalog = NULL, calculations = NULL, annualaverage = NULL){
    
    payload <- list(seriesid = seriesid)
    # Payload won't take NULL values, have to check every field.
    # Probably a more elegant way do do this using an apply function.
    if (exists("registrationKey") & !is.null(registrationKey)){ 
        payload["registrationKey"] <- as.character(registrationKey)
        # Base URL for V2 for folks who have a key.
        base_url <- "http://api.bls.gov/publicAPI/v2/timeseries/data/"
        if (exists("catalog") & !is.null(catalog)){
            if (!is.logical(catalog)){
                message("Please select TRUE or FALSE for catalog argument.")
            }
            payload["catalog"] <- tolower(as.character(catalog))
        }
        if (exists("calculations") & !is.null(calculations)){
            if (!is.logical(calculations)){
                message("Please select TRUE or FALSE for calculations argument.")
            }
            payload["calculations"] <- tolower(as.character(calculations))
        }
        if (exists("annualaverage") & !is.null(annualaverage)){
            if (!is.logical(annualaverage)){
                message("Please select TRUE or FALSE for calculations argument.")
            }
            payload["annualaverage"] <- tolower(as.character(annualaverage))
        }
    } else {
        # Base URL for everyone else.
        base_url <- "http://api.bls.gov/publicAPI/v1/timeseries/data/"
    }
    # Both sets of users can select these args.
    if (exists("startyear") & !is.null(startyear)){
        payload["startyear"] <- as.character(startyear)
    }
    if (exists("endyear") & !is.null(endyear)){
        payload["endyear"] <- as.character(endyear)
    }
    # Manually construct payload since the BLS formatting is wakey.
    payload <- toJSON(payload)
    loadparse <- regmatches(payload, regexpr("],", payload), invert = TRUE)
    parse1 <- loadparse[[1]][1]
    parse2 <- gsub("\\[|\\]", "", loadparse[[1]][2])
    payload <- paste(parse1, parse2, sep = "],")
    
    # Here's the actual API call.
    jsondat <- content(POST(base_url, body = payload, content_type_json()))
    
    if(length(jsondat$Results) > 0) {
        # Put results into data.table format.
        # Try to figure out a way to do this without importing data.table with the package.
        # Method borrowed from here:
        # https://github.com/fcocquemas/bulast/blob/master/R/bulast.R
        dt <- data.table::rbindlist(lapply(jsondat$Results$series, function(s) {
            dt <- data.table::rbindlist(lapply(s$data, function(d) {
                d[["footnotes"]] <- paste(unlist(d[["footnotes"]]), collapse = " ")
                d <- lapply(lapply(d, unlist), paste, collapse=" ")
            }), use.names = TRUE, fill=TRUE)
            dt[, seriesID := s[["seriesID"]]]
            dt
        }), use.names = TRUE, fill=TRUE)
        
        # Convert periods to dates.
        # This is for convenience--don't want to touch any of the raw data.
        if("M01" %in% names(dt[, period])){
        dt[, date := seq(as.Date(paste(year, ifelse(period == "M13", 12, substr(period, 2, 3)), "01", sep = "-")),
                         length = 2, by = "months")[2]-1,by="year,period"]
        }
        jsondat$Results <- dt
        df <- as.data.frame(jsondat$Results)
        df$value <- as.numeric(as.character(df$value))
        df$year <- as.numeric(as.character(df$year))
        return(df)
    }
    else{
        message("Woops, something went wrong. Your request returned zero rows! Are you over your daily query limit?")
    }   
}