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


#################### FOREST NON FOREST DEGRADED FOR 2015
system(sprintf("gdal_calc.py -A %s --co COMPRESS=LZW --outfile=%s --calc=\"%s\"",
               paste0(edd_dir,"uni_map_dd_bioko_aea_20171206.tif"),
               paste0(edd_dir,"bnb_2015.tif"),
               paste0("(A==100)*0+",    #### NO DATA
                      "((A==11)+(A>=17)*(A<=27)+(A==31)+(A>=37)*(A<=44)+(A>=61)*(A<100))*1+",  #### NO BOSQUE
                      "((A>=12)*(A<=14))*2+",  #### BOSQUE
                      "((A>=32)*(A<=34)+(A>=51)*(A<=54))*3"  #### DEGRADACION
               )
))

#################### FOREST NON FOREST DEGRADED FOR 2014
system(sprintf("gdal_calc.py -A %s -B %s --co COMPRESS=LZW --outfile=%s --calc=\"%s\"",
               paste0(edd_dir,"bnb_2015.tif"),
               paste0(gfc_dir,"gfc_GNQ_lossyear_aea.tif"),
               paste0(edd_dir,"bnb_2014.tif"),
               paste0("(B==14)*2+((B<14)+(B>14))*A ")
))

#################### LOSS NO LOSS MASK FOR 2014-2018
system(sprintf("gdal_calc.py -A %s --co COMPRESS=LZW --outfile=%s --calc=\"%s\"",
               paste0(gfc_dir,"gfc_GNQ_lossyear_aea.tif"),
               paste0(gfc_dir,"pnp_aea.tif"),
               paste0("(A<14)*0+(A>=14)*(A<=18)*1")
))

##########################################################################################
#### Compute stats de mapa dd 2004_2014
system(sprintf("oft-his -i %s -o %s -um %s -maxval %s",
               paste0(edd_dir,"bnb_2014.tif"),
               paste0(rootdir,"stat_mapa_dd_2004_2014.txt"),
               paste0(seg_dir,"seg_bioko.tif"),
               3
))

##########################################################################################
#### Compute stats de mapa dd 2004_2014
system(sprintf("oft-his -i %s -o %s -um %s -maxval %s",
               paste0(gfc_dir,"pnp_aea.tif"),
               paste0(rootdir,"stat_perdidas_gfc_2014_2018.txt"),
               paste0(seg_dir,"seg_bioko.tif"),
               1
))

#########################################################################################
### Read and create a reclass code for seg_bioko.tif > 50 pixels
df_perdidas <- read.table(paste0(rootdir,"stat_perdidas_gfc_2014_2018.txt"))
df_mapadd   <- read.table(paste0(rootdir,"stat_mapa_dd_2004_2014.txt"))

names(df_perdidas) <- c("poly_id","total","no_perdidas","perdidas")
names(df_mapadd)   <- c("poly_id","total","no_data","no_bosque","bosque","degradacion")
summary(df_perdidas$total - df_mapadd$total)

df <- data.frame(cbind(df_perdidas,df_mapadd[,3:6]))

df$final <- 0

head(df)


df[df$no_bosque >  0.7*df$total,]$final <- 1   #### NO BOSQUE == 1

df[df$no_bosque <= 0.7*df$total & df$degradacion > 0.3*df$total & df$perdidas > 0.7* (df$bosque + df$degradacion),]$final <- 32   
df[df$no_bosque <= 0.7*df$total & df$degradacion > 0.3*df$total & df$perdidas <= 0.7* (df$bosque + df$degradacion)  & df$perdidas > 0.1 * (df$bosque + df$degradacion) ,]$final <- 22
df[df$no_bosque <= 0.7*df$total & df$degradacion > 0.3*df$total & df$perdidas <= 0.1 * (df$bosque + df$degradacion) ,]$final <- 2

df[df$no_bosque <= 0.7*df$total & df$degradacion <= 0.3*df$total & df$perdidas > 0.7* (df$bosque + df$degradacion),]$final <- 31
df[df$no_bosque <= 0.7*df$total & df$degradacion <= 0.3*df$total & df$perdidas <= 0.7* (df$bosque + df$degradacion) & df$perdidas > 0.1 * (df$bosque + df$degradacion),]$final <- 21
df[df$no_bosque <= 0.7*df$total & df$degradacion <= 0.3*df$total & df$perdidas <= 0.1 * (df$bosque + df$degradacion) ,]$final <- 2

df[df$no_data > 0.2* df$total,]$final <- 0

table(df$final)




write.table(df,paste0(tmp_dir,"reclass.txt"),row.names = F,col.names = F)

####### Reclassificar para la masquera
system(sprintf("(echo %s; echo 1; echo 1; echo 9; echo 0) | oft-reclass  -oi %s  -um %s %s",
               paste0(tmp_dir,"reclass.txt"),
               paste0(tmp_dir,"tmp_bioko_mapa_2014_2018.tif"),
               paste0(seg_dir,"seg_bioko.tif"),
               paste0(seg_dir,"seg_bioko.tif")
               
))




#################### CREATE A COLOR TABLE FOR THE OUTPUT MAP
my_classes <- c(0,1,2,21,22,31,32)
my_colors  <- col2rgb(c("black","grey","darkgreen","orange","yellow","red","purple"))

pct <- data.frame(cbind(my_classes,
                        my_colors[1,],
                        my_colors[2,],
                        my_colors[3,]))

write.table(pct,paste0(tmp_dir,"color_table.txt"),row.names = F,col.names = F,quote = F)


system(sprintf("gdal_translate -ot Byte -co COMPRESS=LZW %s %s",
               paste0(tmp_dir,"tmp_bioko_mapa_2014_2018.tif"),
               paste0(tmp_dir,"tmp_byte_bioko_mapa_2014_2018.tif")
))


################################################################################
#################### Add pseudo color table to result
################################################################################
system(sprintf("(echo %s) | oft-addpct.py %s %s",
               paste0(tmp_dir,"color_table.txt"),
               paste0(tmp_dir,"tmp_byte_bioko_mapa_2014_2018.tif"),
               paste0(tmp_dir,"tmp_pct_bioko_mapa_2014_2018.tif")
))

################################################################################
#################### COMPRESS
################################################################################
system(sprintf("gdal_translate -ot Byte -co COMPRESS=LZW %s %s",
               paste0(tmp_dir,"tmp_pct_bioko_mapa_2014_2018.tif"),
               paste0(map_dir,"bioko_mapa_2014_2018.tif")
))



################################################################################
####################  CLEAN
################################################################################
system(sprintf("rm %s",
               paste0(tmp_dir,"tmp*.tif")
))

(time_decision_tree <- Sys.time() - time_start)

