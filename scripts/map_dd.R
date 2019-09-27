##########################################################################################
################## Read, manipulate and write raster data
##########################################################################################

########################################################################################## 
# Contact: remi.dannunzio@fao.org
# Last update: 2018-10-14
##########################################################################################

time_start  <- Sys.time()

####################################################################################
####### PREPARE COMMODITY MAP
####################################################################################
shp <- readOGR(paste0(seg_dir,"bioko3SEPAL5-80-11.shp"))
dbf <- shp@data
tif <- raster(paste0(edd_dir,"uni_map_dd_bioko_aea_20171206.tif"))

head(shp)
length(unique(shp@data$DN))

shp <- spTransform(shp,proj)

writeOGR(shp,paste0(seg_dir,"seg_bioko.shp"),paste0(seg_dir,"seg_bioko"),"ESRI Shapefile",overwrite_layer = T)

system(sprintf("python %s/oft-rasterize_attr_32.py -v %s -i %s -o %s -a %s",
               scriptdir,
               paste0(seg_dir,"seg_bioko.shp"),
               paste0(edd_dir,"uni_map_dd_bioko_aea_20171206.tif"),
               paste0(seg_dir,"seg_bioko.tif"),
               "DN"
))


#################### ALIGN PRODUCTS PL1
input  <- paste0(gfc_dir,"gfc_GNQ_lossyear.tif")

mask   <- paste0(edd_dir,"uni_map_dd_bioko_aea_20171206.tif")

proj   <- proj4string(raster(mask))
extent <- extent(raster(mask))
res    <- res(raster(mask))[1]

ouput  <- paste0(gfc_dir,"gfc_GNQ_lossyear_aea.tif")

system(sprintf("gdalwarp -co COMPRESS=LZW -t_srs \"%s\" -te %s %s %s %s -tr %s %s %s %s -overwrite",
               proj4string(raster(mask)),
               extent(raster(mask))@xmin,
               extent(raster(mask))@ymin,
               extent(raster(mask))@xmax,
               extent(raster(mask))@ymax,
               res(raster(mask))[1],
               res(raster(mask))[2],
               input,
               ouput
))


#################### FOREST NON FOReST DEGRADATION FOR 2000-2014
system(sprintf("gdal_calc.py -A %s --co COMPRESS=LZW --outfile=%s --calc=\"%s\"",
               paste0(edd_dir,"uni_map_dd_bioko_aea_20171206.tif"),
               paste0(edd_dir,"bnb_2014.tif"),
               paste0("(A==100)*0+",    #### NO DATA
                      "((A==11)+(A>=17)*(A<=27)+(A>=37)*(A<=44)+(A>=61)*(A<100))*1+",  #### NO BOSQUE
                      "((A>=12)*(A<=14))*2+",  #### BOSQUE
                      "((A>=31)*(A<=34)+(A>=51)*(A<=54))*3"  #### DEGRADACION
               )
))


#################### LOSS NO LOSS MASK FOR 2014-2018
system(sprintf("gdal_calc.py -A %s --co COMPRESS=LZW --outfile=%s --calc=\"%s\"",
               paste0(gfc_dir,"gfc_GNQ_lossyear_aea.tif"),
               paste0(gfc_dir,"pnp_aea.tif"),
               paste0("(A<14)*0+(A>=14)*(A<=18)*1")
))

##########################################################################################
#### Compute stats de mapa dd 2000_2014
system(sprintf("oft-his -i %s -o %s -um %s -maxval %s",
               paste0(edd_dir,"bnb_2014.tif"),
               paste0(rootdir,"stat_mapa_dd_2000_2014.txt"),
               paste0(seg_dir,"seg_bioko.tif"),
               3
))

##########################################################################################
#### Compute stats de mapa dd 2000_2014
system(sprintf("oft-his -i %s -o %s -um %s -maxval %s",
               paste0(gfc_dir,"pnp_aea.tif"),
               paste0(rootdir,"stat_perdidas_gfc_2014_2018.txt"),
               paste0(seg_dir,"seg_bioko.tif"),
               1
))

#########################################################################################
### Read and create a reclass code for clumps > 50 pixels
df_perdidas <- read.table(paste0(rootdir,"stat_perdidas_gfc_2014_2018.txt"))
df_mapadd   <- read.table(paste0(rootdir,"stat_mapa_dd_2000_2014.txt"))

head(df_perdidas)
head(df_mapadd)


################ LET US UPDATE THE DECISION TREE
names(df) <- c("clump_id","size")
summary(df)

df$new <- 1
df[df$size > 50,]$new <- 2

table(df$new)

write.table(df,paste0(rootdir,"bioko_clump_gt_50.txt"),row.names = F,col.names = F)

####### Reclassificar para la masquera
system(sprintf("(echo %s; echo 1; echo 1; echo 3; echo 0) | oft-reclass  -oi %s  -um %s %s",
               paste0(rootdir,"bioko_clump_gt_50.txt"),
               paste0(rootdir,"bioko_classificacion_clump_gt_50.tif"),
               paste0(rootdir,"bioko_classificacion_clump.tif"),
               paste0(rootdir,"bioko_classificacion_clump.tif")
               
))



####################################################################################
####### COMBINE GFC LAYERS
####################################################################################

#################### CREATE GFC TREE COVER MAP IN 2007 AT THRESHOLD
system(sprintf("gdal_calc.py -A %s -B %s --co COMPRESS=LZW --outfile=%s --calc=\"%s\"",
               paste0(gfc_dir,"gfc_treecover2000.tif"),
               paste0(gfc_dir,"gfc_lossyear.tif"),
               paste0(dd_dir,"tmp_gfc_2007_gt",gfc_threshold,".tif"),
               paste0("(A>",gfc_threshold,")*((B==0)+(B>6))*A")
))

#################### CREATE GFC LOSS MAP AT THRESHOLD between 2007 and 2016
system(sprintf("gdal_calc.py -A %s -B %s --co COMPRESS=LZW --outfile=%s --calc=\"%s\"",
               paste0(gfc_dir,"gfc_treecover2000.tif"),
               paste0(gfc_dir,"gfc_lossyear.tif"),
               paste0(dd_dir,"tmp_gfc_loss_0716_gt",gfc_threshold,".tif"),
               paste0("(A>",gfc_threshold,")*(B>6)*(B<16)")
))

#################### SIEVE TO THE MMU
system(sprintf("gdal_sieve.py -st %s %s %s ",
               mmu,
               paste0(dd_dir,"tmp_gfc_loss_0716_gt",gfc_threshold,".tif"),
               paste0(dd_dir,"tmp_gfc_loss_0716_gt",gfc_threshold,"_sieve.tif")
))

#################### DIFFERENCE BETWEEN SIEVED AND ORIGINAL
system(sprintf("gdal_calc.py -A %s -B %s --co COMPRESS=LZW --outfile=%s --calc=\"%s\"",
               paste0(dd_dir,"tmp_gfc_loss_0716_gt",gfc_threshold,".tif"),
               paste0(dd_dir,"tmp_gfc_loss_0716_gt",gfc_threshold,"_sieve.tif"),
               paste0(dd_dir,"tmp_gfc_loss_0716_gt",gfc_threshold,"_inf.tif"),
               paste0("(A>0)*(A-B)+(A==0)*(B==1)*0")
))


#################### CREATE GFC TREE COVER MASK IN 2016 AT THRESHOLD
system(sprintf("gdal_calc.py -A %s -B %s --co COMPRESS=LZW --outfile=%s --calc=\"%s\"",
               paste0(dd_dir,"tmp_gfc_2007_gt",gfc_threshold,".tif"),
               paste0(gfc_dir,"gfc_lossyear.tif"),
               paste0(dd_dir,"tmp_gfc_2016_gt",gfc_threshold,".tif"),
               paste0("(A>0)*((B>=16)+(B==0))")
))


#################### SIEVE TO THE MMU
system(sprintf("gdal_sieve.py -st %s %s %s ",
               mmu,
               paste0(dd_dir,"tmp_gfc_2016_gt",gfc_threshold,".tif"),
               paste0(dd_dir,"tmp_gfc_2016_gt",gfc_threshold,"_sieve.tif")
))

#################### DIFFERENCE BETWEEN SIEVED AND ORIGINAL
system(sprintf("gdal_calc.py -A %s -B %s --co COMPRESS=LZW --outfile=%s --calc=\"%s\"",
               paste0(dd_dir,"tmp_gfc_2016_gt",gfc_threshold,".tif"),
               paste0(dd_dir,"tmp_gfc_2016_gt",gfc_threshold,"_sieve.tif"),
               paste0(dd_dir,"tmp_gfc_2016_gt",gfc_threshold,"_inf.tif"),
               paste0("(A>0)*(A-B)+(A==0)*(B==1)*0")
))

#################### COMBINATION INTO DD MAP (1==NF, 2==F, 3==Df, 4==Dg, 11==agriculture)
system(sprintf("gdal_calc.py -A %s -B %s -C %s -D %s -E %s -F %s --co COMPRESS=LZW --outfile=%s --calc=\"%s\"",
               paste0(dd_dir,"tmp_gfc_2007_gt",gfc_threshold,".tif"),
               paste0(dd_dir,"tmp_gfc_loss_0716_gt",gfc_threshold,"_sieve.tif"),
               paste0(dd_dir,"tmp_gfc_loss_0716_gt",gfc_threshold,"_inf.tif"),
               paste0(ag_dir,"commodities.tif"),
               paste0(dd_dir,"tmp_gfc_2016_gt",gfc_threshold,"_sieve.tif"),
               paste0(dd_dir,"tmp_gfc_2016_gt",gfc_threshold,"_inf.tif"),
               paste0(dd_dir,"tmp_dd_map_0716_gt",gfc_threshold,".tif"),
               paste0("(A==0)*1+(A>0)*(D==0)*((B==0)*(C==0)*((E>0)*2+(F>0)*1)+(B>0)*3+(C>0)*4)+(A>0)*(D>0)*11")
))

################################################################################
#################### PROJECT IN UTM 29
################################################################################
system(sprintf("gdalwarp -t_srs \"%s\" -overwrite -ot Byte -co COMPRESS=LZW %s %s",
               "EPSG:32629",
               paste0(dd_dir,"tmp_dd_map_0716_gt",gfc_threshold,".tif"),
               paste0(dd_dir,"tmp_dd_map_0716_gt",gfc_threshold,"_utm.tif")
))

#################### Create a country boundary mask at the GFC resolution (TO BE REPLACED BY NATIONAL DATA IF AVAILABLE) 
system(sprintf("python %s/oft-rasterize_attr.py -v %s -i %s -o %s -a %s",
               scriptdir,
               paste0(gadm_dir,"Liberia_dd_utm.shp"),
               paste0(dd_dir,"tmp_dd_map_0716_gt",gfc_threshold,"_utm.tif"),
               paste0(gadm_dir,"Liberia_dd_utm.tif"),
               "ID"
))

#################### CLIP TO COUNTRY BOUNDARIES
system(sprintf("gdal_calc.py -A %s -B %s  --co COMPRESS=LZW --outfile=%s --calc=\"%s\"",
               paste0(dd_dir,"tmp_dd_map_0716_gt",gfc_threshold,"_utm.tif"),
               paste0(gadm_dir,"Liberia_dd_utm.tif"),
               paste0(dd_dir,"tmp_dd_map_0716_gt",gfc_threshold,"_utm_country.tif"),
               paste0("(B>0)*A")
))

#################### CREATE A COLOR TABLE FOR THE OUTPUT MAP
my_classes <- c(0,1,2,3,4,11)
my_colors  <- col2rgb(c("black","grey","darkgreen","red","orange","purple"))

pct <- data.frame(cbind(my_classes,
                        my_colors[1,],
                        my_colors[2,],
                        my_colors[3,]))

write.table(pct,paste0(dd_dir,"color_table.txt"),row.names = F,col.names = F,quote = F)




################################################################################
#################### Add pseudo color table to result
################################################################################
system(sprintf("(echo %s) | oft-addpct.py %s %s",
               paste0(dd_dir,"color_table.txt"),
               paste0(dd_dir,"tmp_dd_map_0716_gt",gfc_threshold,"_utm_country.tif"),
               paste0(dd_dir,"tmp_dd_map_0716_gt",gfc_threshold,"pct.tif")
))

################################################################################
#################### COMPRESS
################################################################################
system(sprintf("gdal_translate -ot Byte -co COMPRESS=LZW %s %s",
               paste0(dd_dir,"tmp_dd_map_0716_gt",gfc_threshold,"pct.tif"),
               paste0(dd_dir,"dd_map_0716_gt",gfc_threshold,"_utm_20181014.tif")
))



#############################################################
### ADAPT PRIORITY LANDSCAPE MAPS FOR CROPPING
#############################################################
pls <- readOGR(paste0(pl_dir,"priority_areas_20190925.shp"))
proj4string(pls)
head(pls)
pls@data$Id <- 1:2
names(pls@data)[1] <- "id"
writeOGR(pls,paste0(pl_dir,"priority_areas_20190925.shp"),"priority_areas_20190925","ESRI Shapefile",overwrite_layer = T)

#################### RASTERIZE THE PRIORITY LANDSCAPE
system(sprintf("python %s/oft-rasterize_attr.py -v %s -i %s -o %s -a %s",
               scriptdir,
               paste0(pl_dir,"priority_areas_20190925.shp"),
               paste0(dd_dir,"dd_map_0716_gt",gfc_threshold,"_utm_20181014.tif"),
               paste0(pl_dir,"priority_areas_20190925.tif"),
               "id"
))

#################### MASK MAP FOR PRIORITY LANDSCAPE 1
system(sprintf("gdal_calc.py -A %s -B %s --co COMPRESS=LZW --outfile=%s --calc=\"%s\"",
               paste0(dd_dir,"dd_map_0716_gt",gfc_threshold,"_utm_20181014.tif"),
               paste0(pl_dir,"priority_areas_20190925.tif"),
               paste0(dd_dir,"tmp_dd_map_0716_gt",gfc_threshold,"_utm_pl1.tif"),
               paste0("(B==1)*A")
))

#################### MASK MAP FOR PRIORITY LANDSCAPE 2
system(sprintf("gdal_calc.py -A %s -B %s --co COMPRESS=LZW --outfile=%s --calc=\"%s\"",
               paste0(dd_dir,"dd_map_0716_gt",gfc_threshold,"_utm_20181014.tif"),
               paste0(pl_dir,"priority_areas_20190925.tif"),
               paste0(dd_dir,"tmp_dd_map_0716_gt",gfc_threshold,"_utm_pl2.tif"),
               paste0("(B==2)*A")
))

#################### MASK MAP FOR NON PRIORITY LANDSCAPE
system(sprintf("gdal_calc.py -A %s -B %s --co COMPRESS=LZW --outfile=%s --calc=\"%s\"",
               paste0(dd_dir,"dd_map_0716_gt",gfc_threshold,"_utm_20181014.tif"),
               paste0(pl_dir,"priority_areas_20190925.tif"),
               paste0(dd_dir,"tmp_dd_map_0716_gt",gfc_threshold,"_utm_npl.tif"),
               paste0("(B==0)*A")
))


################################################################################
#################### Add pseudo color table to result
################################################################################
system(sprintf("(echo %s) | oft-addpct.py %s %s",
               paste0(dd_dir,"color_table.txt"),
               paste0(dd_dir,"tmp_dd_map_0716_gt",gfc_threshold,"_utm_pl1.tif"),
               paste0(dd_dir,"tmp_dd_map_0716_gt",gfc_threshold,"_utm_pl1_pct.tif")
))

################################################################################
#################### COMPRESS
################################################################################
system(sprintf("gdal_translate -ot Byte -co COMPRESS=LZW %s %s",
               paste0(dd_dir,"tmp_dd_map_0716_gt",gfc_threshold,"_utm_pl1_pct.tif"),
               paste0(dd_dir,"dd_map_0716_gt",gfc_threshold,"_utm_pl1_20190925.tif")
))

################################################################################
#################### Add pseudo color table to result
################################################################################
system(sprintf("(echo %s) | oft-addpct.py %s %s",
               paste0(dd_dir,"color_table.txt"),
               paste0(dd_dir,"tmp_dd_map_0716_gt",gfc_threshold,"_utm_pl2.tif"),
               paste0(dd_dir,"tmp_dd_map_0716_gt",gfc_threshold,"_utm_pl2_pct.tif")
))

################################################################################
#################### COMPRESS
################################################################################
system(sprintf("gdal_translate -ot Byte -co COMPRESS=LZW %s %s",
               paste0(dd_dir,"tmp_dd_map_0716_gt",gfc_threshold,"_utm_pl2_pct.tif"),
               paste0(dd_dir,"dd_map_0716_gt",gfc_threshold,"_utm_pl2_20190925.tif")
))

################################################################################
#################### Add pseudo color table to result
################################################################################
system(sprintf("(echo %s) | oft-addpct.py %s %s",
               paste0(dd_dir,"color_table.txt"),
               paste0(dd_dir,"tmp_dd_map_0716_gt",gfc_threshold,"_utm_npl.tif"),
               paste0(dd_dir,"tmp_dd_map_0716_gt",gfc_threshold,"_utm_npl_pct.tif")
))

################################################################################
#################### COMPRESS
################################################################################
system(sprintf("gdal_translate -ot Byte -co COMPRESS=LZW %s %s",
               paste0(dd_dir,"tmp_dd_map_0716_gt",gfc_threshold,"_utm_npl_pct.tif"),
               paste0(dd_dir,"dd_map_0716_gt",gfc_threshold,"_utm_npl_20190925.tif")
))

################################################################################
####################  CLEAN
################################################################################
system(sprintf("rm %s",
               paste0(dd_dir,"tmp*.tif")
))

(time_decision_tree <- Sys.time() - time_start)

