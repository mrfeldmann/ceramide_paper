
//---------------------------------------------------------------------------------------------
//parameter setup
//---------------------------------------------------------------------------------------------
setOption("BlackBackground", true);
setBackgroundColor(0);
run("Set Measurements...", "area mean integrated display redirect=None decimal=3");

//---------------------------------------------------------------------------------------------
//constants and settings
//---------------------------------------------------------------------------------------------
PRE_PROCESS = true;
MANIPULATE_AUTOMATIC_COUNTS = true;
MEAS_PER_CELL = true;
SAVE = true;

//---------------------------------------------------------------------------------------------
//extract image info
//---------------------------------------------------------------------------------------------


//store the title in a variable
dir = getDirectory("image");
run("Duplicate...", "duplicate");
title = getTitle();

//extract the animal_id and the slice_id of the title
strings = split(title, "_");
animal_id = strings[0];
slice_id = substring(strings[3], 0, lastIndexOf(strings[3], "."));

//---------------------------------------------------------------------------------------------
//preprocessing
//---------------------------------------------------------------------------------------------

if (PRE_PROCESS == true) {


	selectWindow(title);
	run("Rotate 90 Degrees Right");
	run("Split Channels");



	//---------------
	//filtering, background correction, contrast enhancement
	//---------------

	//DAPI
	selectWindow("C1-" + title);
	run("Z Project...", "projection=[Max Intensity]");
	run("Gaussian Blur...", "sigma=1");
	run("Subtract Background...", "rolling=100 sliding");
	run("Enhance Contrast...", "saturated=0.1"); 
	rename("dapi_processed");
	close("C1-" + title);

	//POMC for visualization
	selectWindow("C2-" + title);
	run("Z Project...", "projection=[Max Intensity]");
	rename("pomc_raw");
	close("C1-" + title);

	//stat for intensity 
	selectWindow("C3-" + title);
	//run("Z Project...", "projection=[Average Intensity]");
	run("Z Project...", "projection=[Max Intensity]");
	rename("stat_raw");
	run("Duplicate...", " ");
	rename("stat_raw_enc");


	//stat for counting
	selectWindow("C3-" + title);
	run("Z Project...", "projection=[Max Intensity]");	
	run("Gaussian Blur...", "sigma=3");
	run("Subtract Background...", "rolling=100  sliding");
	run("Enhance Contrast...", "saturated=0.01");
	rename("stat_processed");
	run("Duplicate...", " ");
	rename("stat_processed_enc");	
	close("C3-" + title);

	//---------------
	//binarizing
	//---------------

	//dapi
	selectWindow("dapi_processed");
	run("Duplicate...", " ");
	setThreshold(25, 255, "raw");
	setOption("BlackBackground", true);
	run("Convert to Mask");
	run("Adjustable Watershed", "tolerance=0.2");
	rename("dapi_binarized");

	//stat
	selectWindow("stat_processed");
	run("Duplicate...", " ");
	setAutoThreshold("Triangle dark");
	setOption("BlackBackground", true);
	run("Convert to Mask");
	run("Adjustable Watershed", "tolerance=0.5");
	rename("stat_binarized");	

	
	//---------------
	//merge channel for display
	//---------------
	run("Merge Channels...", "c1=[dapi_processed] c2=[stat_processed] c3=[pomc_raw] create keep");
	run("Channels Tool...");
	Stack.setDisplayMode("color");
	Stack.setChannel(1);
	run("Cyan");
	Stack.setChannel(2);
	run("Magenta");
	Stack.setChannel(3);
	run("Yellow");

	Stack.setDisplayMode("composite");
	Stack.setActiveChannels("011");

	if (SAVE) {
	run("Duplicate...", "duplicate");
	saveAs("PNG", dir + animal_id + "_" + slice_id + "_composite_raw_arc.png");
	run("Close");
	}
}

//---------------------------------------------------------------------------------------------
//POMC analysis
//---------------------------------------------------------------------------------------------

analyze_pomc();


//---------------------------------------------------------------------------------------------
//saving and clean up
//---------------------------------------------------------------------------------------------

if(SAVE){

	//images
	selectWindow("Composite");	
	run("Select None");
	roiManager("Show None");
	saveAs("Jpeg", dir + animal_id + "_" + slice_id + "_composite_arc.jpg");

	selectWindow("stat_raw");	
	run("Select None");
	roiManager("Show None");
	saveAs("Jpeg", dir + animal_id + "_" + slice_id + "_stat_raw_arc.jpg");
	
	selectWindow("stat_raw_enc");	
	run("Select None");
	roiManager("Show None");
	saveAs("Jpeg", dir + animal_id + "_" + slice_id + "_stat_raw_enc_arc.jpg");

	selectWindow("stat_processed_enc");	
	run("Select None");
	roiManager("Show None");
	saveAs("Jpeg", dir + animal_id + "_" + slice_id + "_stat_proc_enc_arc.jpg");

	
	//clean
	close("dapi_processed");
	close("stat_raw");
	close("dapi_binarized");
	close("stat_raw_enc");
	close("C2-" + title);
	close("stat_processed_enc");	
	close("stat_processed");
	close("stat_binarized");
	close("pomc_raw");
	
	run("Clear Results");
	close("Results");

	roiManager("deselect");
	roiManager("Delete");
};

//---------------------------------------------------------------------------------------------
//functions
//---------------------------------------------------------------------------------------------

function combine_all_ROIs() { 
	//simple helper function to select all ROIs up to the given count of the ROI manager
	//https://forum.image.sc/t/selecting-all-roi-in-roi-manager/43374/2
	//thanks to Ellen TA Dobson
	count = roiManager("count");
	array = newArray(count);
  		for (i=0; i<array.length; i++) {
      	array[i] = i;
  	}

	roiManager("select", array);
	roiManager("Combine");
	roiManager("Add");
}


function save_and_delete_ROIs(roi_name) { 
	/*
	 * function that saves and deletes all ROis present in the ROI manager under a given name
	 */
	roiManager("deselect");
	roiManager("Save", dir + animal_id + "_" + slice_id + "_"+ roi_name + "_ROIs.zip");
	roiManager("Delete");
}

function calculate_ROI_indices(start_count, stop_count) { 
/*
 * function that returns an array with the indices of the ROIs from the start count to stop count
 */
	//index calculations
	//all indices from the ROIs from 0 to the start idx
	//getSequence(n) creates sequence from 0 to n-1. thereby, the ROI_counts get transformed into the index number
	zero_to_start = Array.getSequence(start_count); 
	//all indices from 0 to the stop idx
	zero_to_stop = Array.getSequence(stop_count);
	//all indices from start idx to the stop idx
	start_to_stop = Array.slice(zero_to_stop, lengthOf(zero_to_start), lengthOf(zero_to_stop));

	return start_to_stop;

}

function encircle_ROIs(start_count, stop_count, image, color) { 
// draws the borders of all ROIs from start to stop count. 
// the count is the number of ROIs that were present at a particular condition.
// the borders of the ROIs will be added onto the iamge in a destructive overlay using the designated color

	indices = calculate_ROI_indices(start_count, stop_count);

	//select and draw
	selectWindow(image);	 
	roiManager("select", indices);
	roiManager("Combine");
    roiManager("Set Line Width", 1);
    roiManager("Set Color", color);
    run("Add Selection...");
   
}


function measure_per_cell(start_count, stop_count, ROI) { 
	/*
 	* function that iterates over all ROIs from start to stop index
 	* to obtain individual stat and area measurements.
 	* the start count and stop count will be transformed into their respective indices by the
 	* calculate_ROI_indices function
 	*/

	indices = calculate_ROI_indices(start_count, stop_count);

 	results_i = 0;
	for (i = indices[0]; i < indices[indices.length-1]+1; i++) { 

	//intensity measurements in raw stat
	selectWindow("stat_raw");
	roiManager("Select", i);
	ROI_name = Roi.getName;
	ROI_area = getValue("Area"); 
	stat_intensity = getValue("Mean");
	int_den = ROI_area * stat_intensity;
	
	setResult("Label", results_i, ROI_name);		
	setResult("Area", results_i, ROI_area);
	setResult("Mean", results_i, stat_intensity);
	setResult("IntDen", results_i, int_den);
	updateResults();
	results_i ++;
	}
	
	//save the results as csv
	saveAs("Results", dir + animal_id + "_" + slice_id + "_" + ROI + "_per_cell.csv");
	run("Clear Results");
	close("Results");

	//wait to get rid of color bug
	run("Select None");
	roiManager("Show None");
	wait(2000);
}

function analyze_pomc() {
		
		
	roiManager("Open", dir + animal_id + "_" + slice_id + "_arc_POMC_ROIs.zip");
	
	num_pomc = roiManager("count");
	setResult("num_pomc", 0, num_pomc);	
	updateResults();
	
	//combine the ROIs
	combine_all_ROIs();
	//update the count
	count_after_ROI_combination = roiManager("count");
	
	//encircle_ROI of the whole nucleus
	encircle_ROIs(0, num_pomc, "Composite", "blue");
	encircle_ROIs(0, num_pomc, "stat_raw", "blue");
	encircle_ROIs(0, num_pomc, "stat_raw_enc", "blue");
	encircle_ROIs(0, num_pomc, "stat_processed_enc", "blue");	
	encircle_ROIs(0, num_pomc, "pomc_raw", "blue");			
	
	//clear all pSTAT signal outside of POMC ROI
	selectWindow("stat_binarized");
	roiManager("Select", count_after_ROI_combination - 1); // -1 to shift index to start at 0
	run("Clear Outside");
	
	//clear ROI manager
	roiManager("deselect");
	roiManager("delete");
	
	//count stat-positive cells: select nucleus ROI, anaylze particles stat, count total # ROIs - previous # of ROIs; write into results; deselect ROIs
	selectWindow("stat_binarized");
	run("Analyze Particles...", "size=350-Infinity pixel add composite");//in situ has been renamed to composite in my fiji version
	if (MANIPULATE_AUTOMATIC_COUNTS) {
		waitForUser("Manipulate ROIs", "Inspect the pSTAT ROIs, and manipulate them as necessary.\n Press Okay once finished.");
	}
	num_pomc_stat = roiManager("count");	
	setResult("num_stat_pomc", 0, num_pomc_stat);	
	updateResults();
	//encircle_ROI of stat-positive cells
	encircle_ROIs(0, num_pomc_stat, "Composite", "red");
	encircle_ROIs(0, num_pomc_stat, "stat_raw_enc", "red");
	encircle_ROIs(0, num_pomc_stat, "stat_processed_enc", "red");
	encircle_ROIs(0, num_pomc_stat, "pomc_raw", "red");	

	//save the ROIs
	roiManager("save", dir + animal_id + "_" + slice_id  + "_pSTAT_pomc_ROIs.zip");
				
	// calc % activated cells
	perc_activ = num_pomc_stat / num_pomc;
	setResult("percent_activated", 0, perc_activ);	
	updateResults();		
		
	//save the results as csv
	saveAs("Results", dir + animal_id + "_" + slice_id + "_pomc_summary.csv");
	run("Clear Results");
	close("Results");

	//measure stat per cell
	if (MEAS_PER_CELL) {
		measure_per_cell(0, num_pomc_stat, "pomc");			
	}

		
}
