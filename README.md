# Processing chain for the generation of activity data for the Equatorial Guinea REDD+ process
The material on this repo has been developed to run inside SEPAL (https://sepal.io)

The aim of the processing chain is to develop activity data for the Equatorial Guinea REDD+ process

## Characteristics of the FREL 
The FREL combine the 'deforestation an forest degradation map of 2004-14', which was developed from the GFC dataset, with the new forest losses between 2014-2018 also from the GFC dataset, to produce the new 'deforestation and degradation map of 20014-18'.

- Period for 2014-2018

- 30% canopy cover threshold for the forest definition

- 1ha threshold for separation of tree cover loss between deforestation and degradation

### Legend
1: Non Forest

2: Stable Forest

3: Degradation

4: Deforestation

### How to run the processing chain
In SEPAL, open a terminal and start an instance #4 

Clone the repository with the following command:

``` git clone https://github.com/lorena-hojas/GNQ_DD_14_18.git ```

Open another SEPAL tab, go to Apps/ Rstudio and under the clone directory, open and ``` source()``` the following scripts under `scrips`:

##### config.R
This script needs to be run EVERY TIME your R session is restarted. 

It will setup the working directories, load the packeges, the right parameters and variables environment.

The first time it runs, it can take a few minutes as the necessary packages may be installed.

Once it has run the first time, it takes a few seconds and initializes everything.

##### .R 
It will download the necessary data tiles from [GFC repository](https://earthenginepartners.appspot.com/science-2013-global-forest/download_v1.5.html) merge tiles together and clip it to the boundaing boxes of your AOI
Result in data/gfc/gfc_GNQ_lossyear.tif


###### importing input data
In the terminal copy the input data from the "input_data" folder of the "GNQ_DD_14_18" directory into their corresponding folders with the commands: 
```mv input_data/uni_map_dd_bioko_aea_20171206.tif GNQ_DD_14_18/dd_map_2004_14/´´´ ----DD map 2004-14 Bioko

```mv input_data/bioko3SEPAL5-80-11 GNQ_DD_14_18/segmentation/´´´ ---------------------Landsat 2018 segmentation Bioko
```mv input_data/continent3SEPAL5-80-11 GNQ_DD_14_18/segmentation/´´´ -----------------Landsat 2018 segmentation Continental Region
```mv input_data/continent3SEPAL5-80-11 GNQ_DD_14_18/segmentation/´´´

****In docs there is a description of how the segmentations from 2018 landsat mosaics was done. 

##### map_dd_20191002.R

PREPARE COMMODITY MAP
Rasterized the segmentation to the same projection, extent and cell size of the DD map 2004-14 (seg_bioko.tif)

ALIGN PRODUCTS PL1
Convert GFC forest year losses 2000-2018 to the same projection, extent and cell size of the DD map 2004-14

FOREST NON FOREST DEGRADATION FOR 2000-2014
Reclassify the DD map 2004-14 into Non forest (NF), Intact Forest (FF), Degradation (DG) and Non Data (bnb_2014.tif) 

LOSS NO LOSS MASK FOR 2014-2018
Reclassify GFC forest year losses 2000-2018 into Loss (L) or Non loss (NL) between 2014-18 (pnp_aea.tif) 

RECLASS EACH GROUP OF PIXELS FROM THE SEGMENTATION INTO DEFORESTATION AND DEGRADATION BETWEEEN 2014-18
Clases:
1 – non forest
32 – deforestation of degraded forest
2 – stable forest (degraded)
31 – deforestation of intact forest
21 – degradation of intact forest
2 – stable forest (intact)

Rules: 
1: NF(2004-14)-> Non Forest

Si FF/DG(2004-14):
2: Stable Forest (intact OR degraded)-> DG(2004-14) <30% and (L(2014-18) of FF/DG(2004-14) <10%) OR DG(2004-14) >30% and (L(2014-18) of FF/DG(2004-14) <10%)
3: Degradation (in intact OR degraded forest)-> DG(2004-14) <30% and (L(2014-18) of FF/DG(2004-14) >10% but <30%)  OR DG(2004-14) >30% and (L(2014-18)  of FF/DG(2004-14) >10% but <30%)
4: Deforestation (in intact OR degraded forest) -> DG(2004-14) <30% and (L(2014-18) of FF/DG(2004-14) >30%)  OR DG(2004-14) >30% and (L(2014-18)  of FF/DG(2004-14) >30%)

(output: bioko_mapa_2014_2018.tif)

##### reclass_map_dd_20191002.R


# 1- No stable forest
# 2- Stable forest
# 3- Degradation (joining classes 21-22)
# 4- Deforestation (joining classes 31-32)
# no data- the rest of the values (0-255)

(output: bioko_mapa_2014_2018_reclass.tif)

