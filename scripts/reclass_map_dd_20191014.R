library(raster)

r1 <- raster('GNQ_DD_14_18/data/dd_2014_2018/continente_mapa_2014_2018.tif')


# RECLASIFICACION
# 
# 1- No stable forest
# 2- Stable forest
# 21- New degradation
# 22- Degradation on previous degradation
# 31- New deforestation
# 32- Deforestation on previous degradation
# (joining classes 21-22 and 31-32)
# 
# TO
# 1- No stable forest
# 2- Stable forest
# 3- Degradation
# 4- Deforestation
# no data- the rest of the values (0-255)

## create a new raster r2
r2 <- r1

## reclassify
r2 [ r1 ==21 ] <- 3
r2 [ r1 ==22 ] <- 3
r2 [ r1 ==31 ] <- 4
r2 [ r1 ==32 ] <- 4

# 
writeRaster(r2, filename=file.path('GNQ_DD_14_18/data/dd_2014_2018',"continente_mapa_2014_2018_reclass.tif"), format="GTiff", overwrite=TRUE)


