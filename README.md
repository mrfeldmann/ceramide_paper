# ceramide_paper
Hammerschmidt et al. 



__pSTAT_ARC_all_cells__ is the ImageJ script used for the quantification of pSTAT in all cells in a user-specified ROI, i.e., ARC, 
while __pSTAT_POMC__ is the ImageJ script used for quantifying pSTAT-positive POMC neurons. 

Importantly, ROIs encircling POMC neurons had previously been created and saved in .tif files. 
To use these ROIs in the pSTAT_POMC script, they had to be scraped from the .tif files first, using the __ROI_scraper__ script.
Of note, sometimes, ROIs encircling background areas had been drawn, which were manually deleted in the scraping pipeline.

In the pSTAT_POMC analysis, user input steps in the macros were used to manually control for cases when the same cell would have been counted twice
due to a processing artefact, e.g., if one POMC cell was composed of two pSTAT objects, one of the objects was deleted to get the correct count. 

As outlined in the methods section of the paper, the analyst was blinded to the conditions. 

 