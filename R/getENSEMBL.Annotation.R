#' @title Helper function for retrieving gff files from ENSEMBL
#' @description This function downloads gff 
#' files of query organisms from ENSEMBL.
#' @param organism scientific name of the organism of interest.
#' @param type specification type.
#' @param id.type id type.
#' @param path location where file shall be stored.
#' @author Hajk-Georg Drost
#' @noRd

getENSEMBL.Annotation <-
    function(organism,
             type = "dna",
             id.type = "toplevel",
             path) {
        
        if (!is.element(type, c("dna", "cds", "pep")))
            stop("Please a 'type' argument supported by this function: 
                 'dna', 'cds', 'pep'.")
        
        ensembl_summary <-
            suppressMessages(is.genome.available(
                organism = organism,
                db = "ensembl",
                details = TRUE
            ))
        
        if (nrow(ensembl_summary) == 0) {
            message("Unfortunately, organism '",organism,"' does not exist in this database. Could it be that the organism name is misspelled? Thus, download has been omitted.")
            return(FALSE)
        }
        
        taxon_id <- assembly <- name <- accession <- NULL
        
        if (nrow(ensembl_summary) > 1) {
            if (is.taxid(organism)) {
                ensembl_summary <-
                    dplyr::filter(ensembl_summary, taxon_id == as.integer(organism), !is.na(assembly))
            } else {
                
                ensembl_summary <-
                    dplyr::filter(
                        ensembl_summary,
                        (name == stringr::str_to_lower(stringr::str_replace_all(organism, " ", "_"))) |
                            (accession == organism),
                        !is.na(assembly)
                    )
            }
        }
        
        new.organism <- ensembl_summary$name[1]
        new.organism <-
            paste0(
                stringr::str_to_upper(stringr::str_sub(new.organism, 1, 1)),
                stringr::str_sub(new.organism, 2, nchar(new.organism))
            )
        
        
        rest_url <- paste0(
            "http://rest.ensembl.org/info/assembly/",
            new.organism,
            "?content-type=application/json"
        )
        
        rest_api_status <- test_url_status(url = rest_url, organism = organism)   
        if (is.logical(rest_api_status)) {
            return(FALSE)
        } else {
        
            species_api_url <- "http://rest.ensembl.org/info/species?content-type=application/json"
            if (curl::curl_fetch_memory(species_api_url)$status_code != 200) {
                message("The API connection to 'http://rest.ensembl.org/info/species?content-type=application/json' was not available.",
                        " Please make sure that you have a stable internet connection or are not blocked by any firewall.")
                return(FALSE)
            }
            
            ensembl.available.organisms <-
                jsonlite::fromJSON(species_api_url)
            
            
            aliases <- groups <- NULL
            # transform list object returned by 'fromJSON' to tibble
            ensembl.available.organisms <-
                tibble::as_tibble(dplyr::select(
                    ensembl.available.organisms$species,
                    -aliases,
                    -groups
                ))
            
            # readr::write_delim(ensembl.available.organisms,
            #                  file.path(tempdir(), "ensembl_summary.txt"), 
            # col_names = TRUE, delim = "\t")
        }
        
        
            
            json.qry.info <- rest_api_status
        # construct retrieval query
        ensembl.qry <-
            paste0(
                "ftp://ftp.ensembl.org/pub/current_gff3/",
                stringr::str_to_lower(new.organism),
                "/",
                paste0(
                    stringr::str_to_title(new.organism, locale = "en"),
                    ".",
                    json.qry.info$default_coord_system_version,
                    ".",
                    ensembl.available.organisms$release[1],
                    ".gff3.gz"
                )
            )
        
        if (file.exists(file.path(
            path,
            paste0(
                stringr::str_to_title(new.organism, locale = "en"),
                ".",
                json.qry.info$default_coord_system_version,
                ".",
                ensembl.available.organisms$release[1],
                "_ensembl",
                ".gff3.gz"
            )
        ))) {
            message(
                "File ",
                file.path(
                    path,
                    paste0(
                        stringr::str_to_title(new.organism, locale = "en"),
                        ".",
                        json.qry.info$default_coord_system_version,
                        ".",
                        ensembl.available.organisms$release[1],
                        "_ensembl",
                        ".gff3.gz"
                    )
                ),
                " exists already. Thus, download has been skipped."
            )
        } else {
            tryCatch({
                custom_download(ensembl.qry,
                                destfile = file.path(
                                    path,
                                    paste0(
                                        stringr::str_to_title(new.organism, locale = "en"),
                                        ".",
                                        json.qry.info$default_coord_system_version,
                                        ".",
                                        ensembl.available.organisms$release[1],
                                        "_ensembl",
                                        ".gff3.gz"
                                    )
                                ),
                                mode = "wb")
            }, error = function(e)
                stop(
                    "The FTP site of ENSEMBL 
                    'ftp://ftp.ensembl.org/pub/current_gff3/' does not seem to 
                    work properly. Are you connected to the internet? 
                    Is the site 'ftp://ftp.ensembl.org/pub/current_gff3/' or 
                    'http://rest.ensembl.org' currently available?",
                    call. = FALSE
                ))
        }
        
        return(file.path(
            path,
            paste0(
                stringr::str_to_title(new.organism, locale = "en"),
                ".",
                json.qry.info$default_coord_system_version,
                ".",
                ensembl.available.organisms$release[1],
                "_ensembl",
                ".gff3.gz"
            )
        ))
}
