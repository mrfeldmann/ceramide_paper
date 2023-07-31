//constant
ROI_NAME = "arc"

//store the title in a variable
dir = getDirectory("image");
title = getTitle();

//extract the animal_id and the slice_id of the title
strings = split(title, "_");
animal_id = strings[3];
slice_id = substring(strings[6], 0, lastIndexOf(strings[6], "."));

//extract the ROIs
 run("Rotate 90 Degrees Right");
 run("Create Mask");
 run("Adjustable Watershed", "tolerance=0.5");
 run("Analyze Particles...", "size=0-700 add composite");
 waitForUser("ROI check", "Delete background ROIs if present in selection.");

//save ROIs
roiManager("deselect");
roiManager("Save", dir + animal_id + "_" + slice_id + "_"+ ROI_NAME + "_POMC_ROIs.zip");
roiManager("Delete");

//close window
close("Mask");
//close(title);