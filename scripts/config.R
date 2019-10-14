##############################################################################################
root <- "~"
setwd(root)
root       <- paste0(getwd(),'/')
gfcdwn_dir <- paste0(root,"downloads/gfc/2018/")
rootdir     <- paste0(root,"GNQ_DD_14_18/")
scriptdir   <- paste0(rootdir,"scripts/")
data_dir    <- paste0(rootdir,"data/")
tmp_dir     <- paste0(rootdir,"tmp/")
gfc_dir     <- paste0(data_dir,"gfc/")
seg_dir     <- paste0(data_dir,"segmentation/")
edd_dir     <- paste0(data_dir,"dd_2004_2014_map/")
stt_dir     <- paste0(data_dir,"stat/")
map_dir     <- paste0(data_dir,"dd_2014_2018/")

dir.create(scriptdir,showWarnings = F)
dir.create(gfcdwn_dir,recursive=T,showWarnings = F)
dir.create(data_dir,showWarnings = F)
dir.create(gfc_dir,showWarnings = F)
dir.create(seg_dir,showWarnings = F)
dir.create(edd_dir,showWarnings = F)
dir.create(stt_dir,showWarnings = F)
dir.create(tmp_dir,showWarnings = F)
dir.create(map_dir,showWarnings = F)
####################################################################################################
#################### load packages
source(paste0(scriptdir,'packages.R'))

#################### load parameters
source(paste0(scriptdir,'my_parameters.R'))

####################################################################################################

#################### CREATE A COLOR TABLE FOR THE OUTPUT MAP
my_classes <- 0:8

legend <- data.frame(cbind(
  my_classes,
  c("nodata",rep("forest",4),rep("non_forest",4)),
  c("nodata",rep("forest",2),rep("non_forest",2),rep("forest",2),rep("non_forest",2)),
  c("nodata","Stable","Loss","Loss","Stable","Gain","Stable","Gain","Stable"),
  c("nodata","Yes","No","Yes","No","Yes","No","No","Yes")
))

names(legend) <- c("code","fnf_gfc_2000","fnf_glad_2010","chg_gfc","agree")

my_colors  <- col2rgb(c("black",
                        "green",
                        "red",
                        "yellow",
                        "purple",
                        "blue",
                        "lightblue",
                        "darkblue",
                        "grey"))

pct <- data.frame(cbind(my_classes,
                        my_colors[1,],
                        my_colors[2,],
                        my_colors[3,]))

write.table(pct,paste0(gfc_dir,"color_table_glad.txt"),row.names = F,col.names = F,quote = F)

#################### CREATE A COLOR TABLE FOR THE OUTPUT MAP
my_classes <- 0:3

my_colors  <- col2rgb(c("black",
                        "green",
                        "grey",
                        "darkblue"))

pct <- data.frame(cbind(my_classes,
                        my_colors[1,],
                        my_colors[2,],
                        my_colors[3,]))

write.table(pct,paste0(gfc_dir,"color_table_tandem.txt"),row.names = F,col.names = F,quote = F)

types       <- c("treecover2000","lossyear","gain","datamask")

####################################################################################################
################# PIXEL COUNT FUNCTION
pixel_count <- function(x){
  info    <- gdalinfo(x,hist=T)
  buckets <- unlist(str_split(info[grep("bucket",info)+1]," "))
  buckets <- as.numeric(buckets[!(buckets == "")])
  hist    <- data.frame(cbind(0:(length(buckets)-1),buckets))
  hist    <- hist[hist[,2]>0,]
}
