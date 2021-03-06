# voronoi polygon neighbourhood function ----------------------------------
## so far requires that the sf object includes an integer, indicator column
## called strat
neighbours_define <- function(real_strata_map = realized_strata_map,
                              strat_link_fill = 10000,
                              plot_neighbours = TRUE,
                              species = "",
                              plot_dir = "route_maps/",
                              plot_file = "_route_maps.pdf",
                              save_plot_data = TRUE,
                              voronoi = FALSE){
  
  require(spdep)
  require(sf)
  require(tidyverse)
  
  # function to prep spatial data for stan model ----------------------------
  mungeCARdata4stan = function(adjBUGS,numBUGS) {
    N = length(numBUGS);
    nn = numBUGS;
    N_edges = length(adjBUGS) / 2;
    node1 = vector(mode="numeric", length=N_edges);
    node2 = vector(mode="numeric", length=N_edges);
    iAdj = 0;
    iEdge = 0;
    for (i in 1:N) {
      for (j in 1:nn[i]) {
        iAdj = iAdj + 1;
        if (i < adjBUGS[iAdj]) {
          iEdge = iEdge + 1;
          node1[iEdge] = i;
          node2[iEdge] = adjBUGS[iAdj];
        }
      }
    }
    return (list("N"=N,"N_edges"=N_edges,"node1"=node1,"node2"=node2));
  }
  
  # neighbourhood define ----------------------------------------------------
  
  if(voronoi == FALSE){
    #check if input layer is polygon, if not set voronoi to TRUE
    if(any(grepl("POLYGON",class(real_strata_map$geometry[[1]])))){
      
      vintj = arrange(real_strata_map,strat)
      
      nb_db = poly2nb(vintj,row.names = vintj$strat,queen = FALSE)
      
      
      # plotting the neighbourhoods to check ------------------------------------
      if(plot_neighbours){
        
        species_dirname <- gsub(pattern = " ",
                                replacement = "_",
                                x = species)
        
        
        plot_file_name = paste0(plot_dir,species_dirname,plot_file)
        
        cc = suppressWarnings(st_coordinates(st_centroid(vintj)))
        
        ggp = ggplot(data = real_strata_map)+
          geom_sf(data = vintj,alpha = 0.3,colour = grey(0.8))+ 
          geom_sf(data = real_strata_map,alpha = 0.1)+ 
          geom_sf(aes(col = strat))+
          geom_sf_text(aes(label = strat),size = 5,alpha = 0.8)+
          labs(title = species)+
          theme(legend.position = "none")
        pdf(file = plot_file_name,
            width = 11,
            height = 8.5)
        plot(nb_db,cc,col = "pink")
        text(labels = rownames(cc),cc ,pos = 2)
        print(ggp)
        dev.off()
        
        if(save_plot_data){
          save_file_name = paste0(plot_dir,species_dirname,"_route_data.RData")
          
          save(list = c("real_strata_map",
                        "vintj",
                        "nb_db",
                        "cc"),
               file = save_file_name)
        }
      }
      
      nb_info = spdep::nb2WB(nb_db)
      
      if(min(nb_info$num) == 0){
        voronoi <- TRUE
        message("Some strata have no neighbours, trying voronoi neighbours on centroids")}
      
    }else{
      voronoi <- TRUE
    }
  }
  
  if(voronoi){
    centres = suppressWarnings(st_centroid(real_strata_map))
    coords = st_coordinates(centres)
    
    cov_hull <- st_convex_hull(st_union(centres))
    cov_hull_buf = st_buffer(cov_hull,dist = strat_link_fill) #buffering the realised strata by (strat_link_fill/1000)km
    
    # Voronoi polygons from centres -----------------------------------
    box <- st_as_sfc(st_bbox(centres))
    
    v <- st_cast(st_voronoi(st_union(centres), envelope = box))
    
    vint = st_sf(st_cast(st_intersection(v,cov_hull_buf),"POLYGON"))
    vintj = st_join(vint,centres,join = st_contains)
    vintj = arrange(vintj,strat)
    
    nb_db = poly2nb(vintj,row.names = vintj$strat,queen = FALSE)
    
    
    # plotting the neighbourhoods to check ------------------------------------
    if(plot_neighbours){
      
      species_dirname <- gsub(pattern = " ",
                              replacement = "_",
                              x = species)
      
      
      plot_file_name = paste0(plot_dir,species_dirname,plot_file)
      
      cc = suppressWarnings(st_coordinates(st_centroid(vintj)))
      
      ggp = ggplot(data = centres)+
        geom_sf(data = vintj,alpha = 0.3,colour = grey(0.8))+ 
        geom_sf(data = real_strata_map,alpha = 0.1)+ 
        geom_sf(aes(col = strat))+
        geom_sf_text(aes(label = strat),size = 5,alpha = 0.8)+
        labs(title = species)+
        theme(legend.position = "none")
      pdf(file = plot_file_name,
          width = 11,
          height = 8.5)
      plot(nb_db,cc,col = "pink")
      text(labels = rownames(cc),cc ,pos = 2)
      print(ggp)
      dev.off()
      
      if(save_plot_data){
        save_file_name = paste0(plot_dir,species_dirname,"_route_data.RData")
        
        save(list = c("centres",
                      "real_strata_map",
                      "vintj",
                      "nb_db",
                      "cc"),
             file = save_file_name)
      }
    }
    ## stop here and look at the maps (2 pages)
    ## in the first page each route location is plotted as a point and all neighbours are linked by red lines 
    ## in the second page all of the voronoi polygons with their route numbers are plotted
    ### assuming the above maps look reasonable 
    nb_info = spdep::nb2WB(nb_db)
    
    if(min(nb_info$num) == 0){stop("ERROR some strata have no neighbours")}
    
    
  }#end if voronoi
  
  
  
  
  ### re-arrange GEOBUGS formated nb_info into appropriate format for Stan model
  car_stan <- mungeCARdata4stan(adjBUGS = nb_info$adj,
                                numBUGS = nb_info$num)
  
  return(car_stan)
} ### end of function
