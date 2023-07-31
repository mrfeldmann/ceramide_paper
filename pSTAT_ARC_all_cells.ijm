
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
NUCLEI_ANALYSIS = true;
MANUAL_BACKGROUND = true;
AUTOMATIC_COUNTING = true;
MANIPULATE_AUTOMATIC_COUNTS = true;
MEAS_PER_CELL = false;
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

	//stat for intensity 
	selectWindow("C3-" + title);
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

	if (AUTOMATIC_COUNTING) {
	//stat
	selectWindow("stat_processed");
	run("Duplicate...", " ");
	setAutoThreshold("Triangle dark");
	setOption("BlackBackground", true);
	run("Convert to Mask");
	run("Adjustable Watershed", "tolerance=0.5");
	rename("stat_binarized");	
	}

	
	//---------------
	//merge channel for display
	//---------------
	run("Merge Channels...", "c1=[dapi_processed] c2=[stat_processed] create keep");
	run("Channels Tool...");
	Stack.setDisplayMode("color");
	Stack.setChannel(1);
	run("Cyan");
	Stack.setChannel(2);
	run("Magenta");

	Stack.setDisplayMode("composite");

	if (SAVE) {
	run("Duplicate...", "duplicate");
	saveAs("PNG", dir + animal_id + "_" + slice_id + "_composite_raw_arc.png");
	run("Close");
	}
}


//---------------------------------------------------------------------------------------------
//background ROIs
//---------------------------------------------------------------------------------------------

if(MANUAL_BACKGROUND){

	analyze_background();
	encircle_ROIs(0, roiManager("count"), "Composite", "yellow");
	encircle_ROIs(0, roiManager("count"), "stat_raw", "yellow");
	save_and_delete_ROIs("bckgrnd");
}


//---------------------------------------------------------------------------------------------
//nuclei analysis
//---------------------------------------------------------------------------------------------

if(NUCLEI_ANALYSIS){
/* 
 *  I know that from a coding standpoint it would be better to iterate over the nuclei.
 *  However, I don't want to risk any potential race conflicts that I cannot really solve atm
 *  using the ImageJ macro scripting language.
 *  The select none, show none + waiting time blocks seem to be required to resolve a racing 
 *  conflict where a wrong color would be used to encircle the ROIs.
 */

	//ARC
	analyze_ARC = getBoolean("Wanna analyze the ARC?");
	if (analyze_ARC) {
		analyze_nucleus("arc");
		run("Select None");
		roiManager("Show None");
		save_and_delete_ROIs("arc");
		wait(3000);
	}

}

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
			
	if (AUTOMATIC_COUNTING) {
	close("stat_binarized");
	}

	run("Clear Results");
	close("Results");

};

//---------------------------------------------------------------------------------------------
//functions
//---------------------------------------------------------------------------------------------

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

function analyze_background() {
	

	//request ROI for background from user
	selectWindow("Composite");
	waitForUser("Background ROIs", "Draw ROIs manually,\nsave the ROIs by pressing t.");
		
	//error message if no ROi has been selected
	while (roiManager("count") < 1) {
	waitForUser("Background ROIs", "Error!\nDraw ROIs manually,\nsave the ROIs by pressing t.");
	}
	run("Select None");
	roiManager("deselect");
	
	//measure
	number_of_rois = roiManager("count");
	for (i = 0; i < number_of_rois; i++) { 

		//intensity measurements in raw stat
		selectWindow("stat_raw");
		roiManager("Select", i);
		ROI_name = Roi.getName;
		ROI_area = getValue("Area"); 
		stat_intensity = getValue("Mean");
		int_den = ROI_area * stat_intensity;
		
		setResult("Label", i, ROI_name);		
		setResult("Area", i, ROI_area);
		setResult("Mean", i, stat_intensity);
		setResult("IntDen", i, int_den);
		updateResults();
	}

	//save the results as csv
	saveAs("Results", dir + animal_id + "_" + slice_id + "_bckgrnd_stat.csv");
	run("Clear Results");
	close("Results");
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

function analyze_nucleus(ROI_name) {
		
		//get initial roi counts.
		//the roi count post ROI selection will be subtracted from the ROI count 
		//from the analyze particles selection, 
		//which will yield the number of extracted DAPI or stat positive cells, respectively
		roiManager("deselect");
		roi_count_pre_ROI = roiManager("count");	
		roi_count_post_ROI = roi_count_pre_ROI + 1;
	
		//request ROI for nuclei from user
		selectWindow("Composite");
		waitForUser("Nucleus ROI", "Draw a ROI for a nucleus,\nsave the ROI by pressing t.");
		
		//error message if no ROi has been selected
		while (roiManager("count") !=  roi_count_post_ROI) {
		waitForUser("Nuclei ROI", "Error!\nEither no ROI drawn or too many.\nDraw ROI around nucleus manually,\nsave the ROI by pressing t.");
		}
		
		run("Select None");
		
		//encircle_ROI of the whole nucleus
		encircle_ROIs(roi_count_pre_ROI, roi_count_post_ROI, "Composite", "white");
		encircle_ROIs(roi_count_pre_ROI, roi_count_post_ROI, "stat_raw", "white");
		encircle_ROIs(roi_count_pre_ROI, roi_count_post_ROI, "stat_raw_enc", "white");
		if (AUTOMATIC_COUNTING) {
		encircle_ROIs(roi_count_pre_ROI, roi_count_post_ROI, "stat_processed_enc", "red");			
		}


		//raw stat signal in the nucleus
		selectWindow("stat_raw");
		roiManager("Select", roi_count_post_ROI - 1); //indexing in the ROImanager starts at 0, so the roi count has to be subtracted by 1
		ROI_area = getValue("Area"); 
		stat_raw_mean = getValue("Mean");
		stat_int_den = ROI_area * stat_raw_mean;		
		setResult("ROI_area", 0, ROI_area);
		setResult("stat_raw_mean", 0, stat_raw_mean);
		setResult("stat_int_den", 0, stat_int_den);	
		updateResults();
		roiManager("deselect");
		
		//count stat-positive cells: select nucleus ROI, anaylze particles stat, count total # ROIs - previous # of ROIs; write into results; deselect ROIs
		if (AUTOMATIC_COUNTING) {
		selectWindow("stat_binarized");
		roiManager("Select", roi_count_post_ROI - 1);  //indexing in the ROImanager starts at 0, so the roi count has to be subtracted by 1
		run("Analyze Particles...", "size=350-Infinity pixel add composite");//in situ has been renamed to composite in my fiji version
		if (MANIPULATE_AUTOMATIC_COUNTS) {
			selectWindow("Composite");
			waitForUser("Manipulate ROIs", "Inspect the pSTAT ROIs, and manipulate them as necessary.\n Press Okay once finished.");
		}
		roi_count_w_stat = roiManager("count");	
		num_stat_cells = roi_count_w_stat - roi_count_post_ROI;
		setResult("num_stat_cells", 0, num_stat_cells);	
		updateResults();
		//encircle_ROI of stat-positive cells
		encircle_ROIs(roi_count_post_ROI, roi_count_w_stat, "Composite", "red");
		encircle_ROIs(roi_count_post_ROI, roi_count_w_stat, "stat_raw_enc", "red");
		encircle_ROIs(roi_count_post_ROI, roi_count_w_stat, "stat_processed_enc", "red");	

		//save the ROIs
		//getSequence creates sequence from 0 to n-1, thereby the count will be transformed into the index of the ROI manager automatically
		//idea: create indexes 0 to count_w_stat, then slice it by the respective indices 
		roiManager("select", Array.slice(Array.getSequence(roi_count_w_stat), roi_count_post_ROI,  roi_count_w_stat));
		roiManager("save selected", dir + animal_id + "_" + slice_id + "_"+ ROI_name + "_pSTAT_ROIs.zip");
		}
		
		// count DAPI: select nucleus ROI, analyze particles dapi, count total # ROIs - previous # of ROIs; write into results; deselect ROIs		
		selectWindow("dapi_binarized");
		roiManager("Select", roi_count_post_ROI - 1); //indexing in the ROImanager starts at 0, so the roi count has to be subtracted by 1
		run("Analyze Particles...", "size=350-Infinity pixel add composite");//in situ has been renamed to composite in my fiji version
		roi_count_w_dapi = roiManager("count");	
		if (AUTOMATIC_COUNTING) {
			num_dapi_cells = roi_count_w_dapi - roi_count_w_stat;
		} else {
			num_dapi_cells = roi_count_w_dapi - roi_count_post_ROI;		
		}

		setResult("num_dapi_cells", 0, num_dapi_cells);	
		updateResults();
		//encircle_ROI of DAPI-positive cells
		if (AUTOMATIC_COUNTING) {
			encircle_ROIs(roi_count_w_stat, roi_count_w_dapi, "Composite", "blue");	
		} else {
			encircle_ROIs(roi_count_post_ROI, roi_count_w_dapi, "Composite", "blue");		
		}

		// calc % activated cells
		if (AUTOMATIC_COUNTING) {
			perc_activ = num_stat_cells / num_dapi_cells;
			setResult("percent_activated", 0, perc_activ);	
			updateResults();		
		}	
		
		//save the results as csv
		saveAs("Results", dir + animal_id + "_" + slice_id + "_" + ROI_name + "_summary.csv");
		run("Clear Results");
		close("Results");

		//save the DAPI ROIs
		if (AUTOMATIC_COUNTING) {
			roiManager("select", Array.slice(Array.getSequence(roi_count_w_dapi), roi_count_w_stat,  roi_count_w_dapi));
			roiManager("save selected", dir + animal_id + "_" + slice_id + "_"+ ROI_name + "_DAPI_ROIs.zip");
		} else {
			roiManager("select", Array.slice(Array.getSequence(roi_count_w_dapi), roi_count_post_ROI,  roi_count_w_dapi));
			roiManager("save selected", dir + animal_id + "_" + slice_id + "_"+ ROI_name + "_DAPI_ROIs.zip");
		}

		//measure stat per cell
		if (MEAS_PER_CELL) {
			if (AUTOMATIC_COUNTING) {
				measure_per_cell(roi_count_w_stat, roi_count_w_dapi, ROI_name);			
			}else {
				measure_per_cell(roi_count_post_ROI, roi_count_w_dapi, ROI_name);			
			}	
		}
		

		
}

