	#pragma rtGlobals=1

// DAQ: GUI FOR LINEAR SWEEP ACROSS VOLTAGE FOR KEITHLEY 2400 SOURCEMETER

// Written by Roy Sfadia. June-July 2017
// Update 1: January 2018
// Update 2: August 2018
// contact: rsfadia@ucssc.edu...or, if eons later, probably roy.sfadia@gmail.com

// Requirements: 
// must install NI 488.2 driver to communicate with GPIB
// must install NI VISA to configure instruments via GPIB

// Resources used:
// * Keithley 2400 Manual lists common IEEE & SCPI  commands such as "*IDN?" or ":DISPlay:"
// * National Instrument's VISA documentation, by googling viOpen( ) to find out what it does.
// * Igor Pro's "VISA XOR help.ihf" file which explains how to set up VISA for Igor. 
// * Obscure forum post from 'Thor_GT' providing a test code 

// January 2018: upgrades made
// only one table and one graph
// graphs and values are in one window/ gui
// also displays semilog plot
// accepts hysteresis values (sign of step size does not matter)
// browse folders and choose preferred save folder
// remembers values of last sweep

// May 2018: El Capitan made everything go to...shoot.
// had to upgrade NI VISA to support Mac OS X 10.11.x (i.e not the latest version)
// had to upgrade NI 488.2 driver to support Mac OS X 10.11.x (i.e. not the latest version)
// THEN! Since Igor Pro has a 64-bit and 32-bit one must be careful to use VISA64.xop
// finally, make sure to place VISA64.xop in "Igor Extensions (64-bit)", not its 32x counterpart
// finally finally, place VISA.ipf and VISA.ihf in normal folders.

// August 2018: Added auto-save functionality so stupid save dialogue window won't open every time

// September 2018: despite SaveTableCopy not having the overwrite flag /O, it was overwriting files 
// when using the auto-save funciton. Since I'm dumb and kept forgetting to change my device number, 
// I had to manually write in an overwrite function. Basically, in the SaveTableCopy section of the 
// code, it checks if there is already a file with the file name we were going to use. If that file 
// exists, it saves the file with that name, but appended with the current time.

// October 2018: Added 'Carter Lab' menu in menu bar above. Added a quick-run feature that saved me
// negative time when considering how long it took to implement. -RMS


//outputs current time as a string
Function/S timeString()

	String timeString = time()
	String timeEdited = ReplaceString(":", timeString, "-")
	return timeEdited
end

// name measurement based on users input, appended with time
Function/S nameFunctionWithTime(int slideNumber, int deviceNumber)
	slideNumber = slideNumber
	deviceNumber = deviceNumber
	
	string measurementName = ""
	
	ControlInfo dark // retrieves status of dark checkbox
	if (V_value == 0) // if not a dark measurement
		measurementName = "cell" + num2str(slideNumber) + "-" + num2str(deviceNumber) + " " + timeString() + ".iv"
	elseif (V_value == 1)
		measurementName = "cell" + num2str(slideNumber) + "-" + num2str(deviceNumber) + " " + timeString() + "d.iv"
		endif
	return measurementName
End	


// Names measurement based on user inputs
Function/S nameFunction(int slideNumber, int deviceNumber)
	slideNumber = slideNumber
	deviceNumber = deviceNumber

	string measurementName = ""
	
	ControlInfo dark // retrieves status of dark checkbox
	if (V_value == 0) // if not a dark measurement
		measurementName = "cell" + num2str(slideNumber) + "-" + num2str(deviceNumber) + ".iv"
	elseif (V_value == 1)
		measurementName = "cell" + num2str(slideNumber) + "-" + num2str(deviceNumber) + "d.iv"
		endif
	return measurementName
End	
	
	
	
// initializes values for Panel/GUI
Function valueInitialization()

	String saveDF = GetDataFolder(1) //almost like 'pwd' - 'print working directory'
	NewDataFolder/O/S root:IVCurve // creates new folder. "/O/S" flag says "if this folder already exits, just go there."
	
	variable/G i = 0 // introduction of multisweep, need a global iteration variable to know how to name iv curve iterations automatically
	Variable/G slideNumber = NumVarOrDefault("slideNumberSAVE", 1)
	Variable/G deviceNumber = NumVarOrDefault("deviceNumberSAVE", 1)
	String/G measurementName = nameFunction(slideNumber, deviceNumber)
	Variable/G initialVoltage = NumVarOrDefault("initialVoltageSAVE", -1)
	Variable/G finalVoltage = NumVarOrDefault("finalVoltageSAVE", +1)
	Variable/G step = NumVarOrDefault("stepSAVE", 0.02)
	Variable/G currentCompliance = NumVarOrDefault("currentComplianceSAVE", 0.01)
	Variable/G delay = NumVarOrDefault("delaySAVE", 0.150)
	String/G exportDir = StrVarOrDefault("exportDirSAVE", "Macintosh HD:Users:suecarter:Desktop:Data:")
	
	Variable number = abs(finalVoltage-initialVoltage)/abs(step) + 1 //number of data points
	
	Make/O voltage
	Make/O current
	Make/O currentAbs 
	Make/N=6 deviceIterations = {1,2,3,4,5,6} // for quick auto-saving runs
	// Save for next time
	
	Variable/G slideNumberSAVE = slideNumber
	Variable/G deviceNumberSAVE = deviceNumber
	String/G measurementNameSAVE = measurementName
	Variable/G intitialVoltageSAVE = initialVoltage 
	Variable/G finalVoltageSAVE = finalVoltage
	Variable/G stepSAVE = step
	Variable/G currentComplianceSAVE = currentCompliance
	Variable/G delaySAVE = delay
	String/G exportDirSAVE = exportDir
	
	SetDataFolder saveDF
End



// the /S flag declares this function will return a string type
Function/S ExportPath(ctrlName) : ButtonControl //see JVDeviceLoad
	String ctrlName
	SVAR exportDir = root:IVCurve:exportDir
	exportDir = selectPath()
	return exportDir
End



Function/S selectPath()
	newpath/O/M="Select Export Directory"/Q pathUserSelected
	If(V_flag == 0)	// V_flag = 0 if user chose directory
		PathInfo pathUserSelected 
		KillPath pathUserSelected
		return S_path
	Else
		KillPath tmpPath
		return ""
	EndIf
End



// Sweep function
Function initiateSweep(ctrlName) : ButtonControl //see JVDeviceLoad

	String ctrlName  
	
	ControlInfo quickRuns // retrieves status of quick-run checkbox, stores it in V_value
	 if (V_value == 1) //if it is checked
	 	Checkbox autoSave value = 1 // turns on auto-save
	 	sleep/s 10 
	 	sixSweeps() // runs six. User expected to be in GB switching swiches
	 elseif (V_value == 0) // if it is not checked	
		singleSweep() // single run. Auto-save may me on or off
	 endif
End
	
	
Function singleSweep( )	
	
	// with introduction of sixsweeps(), having all this stored in singleSweep() seems redundent. 
	// I think to lower the redundency, I could make singleSweep a function of all these values
	// loads values from panel
	NVAR slideNumber = root:IVCurve:slideNumber
	NVAR deviceNumber = root:IVCurve:deviceNumber
	NVAR initialVoltage = root:IVCurve:initialVoltage
	NVAR finalVoltage = root:IVCurve:finalVoltage
	NVAR step = root:IVCurve:step
	NVAR currentcompliance = root:IVCurve:currentCompliance
	NVAR delay = root:IVCurve:delay
	SVAR exportDir = root:IVCurve:exportDir
	SVAR exportDirSAVE = root:IVCurve:exportDirSAVE
	
	NewPath/O DataFolder exportDir // export directory from user
	Variable number = abs(initialVoltage-finalVoltage)/abs(step) + 1 // number of data poins
	
	
	//Naming measurement
	String measurementName = nameFunction(slideNumber, deviceNumber)
	
	// Sourcemeter outputs V, I, R, time stamp, and system state with every data point. So. Much. Anguish.
	Make/O/D/N=(number) resistance, measurementTime, stat
	
	// since we use these waves in panel, we keep them as global variables
	WAVE voltage = root:IVCurve:voltage
	WAVE current = root:IVCurve:current
	WAVE currentAbs = root:IVCurve:currentAbs	
	
	// redimension voltage and current in case user is using different step size or range
	Redimension/N=(number) voltage
	Redimension/N=(number) current	
	Redimension/N=(number) currentAbs
	
	// verifies step size is correct
	if ( finalVoltage < initialVoltage )
		step = -1*abs(step)  // garantees negative step size for  a hyseresis sweep (initial voltage > final) 
	elseif ( finalVoltage > initialVoltage )
		step = +1*abs(step)
	else
		Abort "Final and Initial voltages must differ from each other."
	endif
	
	// begin talking to instrument(s)
	Variable defaultRM, instr
 	Variable status
 
 	// first thing you do before any VISA operations. Manages instruments
	status = viOpenDefaultRM(defaultRM)  
	// confirm resource manager created
	Printf "DefaultRM=%d\r", defaultRM
 
 	// resources = instruments
	String resourceName = "GPIB0::24::INSTR" 
 	
 	//  opens session with instrument "resourceName". "instr" is output pointing to session
	status = viOpen(defaultRM, resourceName, 0, 0, instr)
	// confirms instrument session has begun
	Printf "instr=%d\r", instr
	
 	// variableWrite is used to pass commands to SourceMeter
	String variableWrite, variableRead
	
	
	// *** Below, we initialize Keithry Sourcemeter and set settings to user input ***
	// helpful source: Keithley 2400 manual, pages (10-22) to (10-25)


	// Restore GPIB to default conditions
	variableWrite = "*RST"
	VISAWrite instr, variableWrite
	
	// Clears buffer * not sure if necessary *
	variableWrite = ":TRAC:CLE"
	VISAWrite instr, variableWrite
	
	// Turns off concurrent functions
	variableWrite = ":SENS:FUNC:CONC OFF"
	VISAWrite instr, variableWrite
	
	// Makes sourcemeter a voltage source
	variableWrite = ":SOUR:FUNC VOLT"
	VISAWrite instr, variableWrite
	
	// Makes sourcemeter a ammeter
	variableWrite = ":SENS:FUNC 'CURR:DC'"
	VISAWrite instr, variableWrite

	// Sets current compliance
	variableWrite = ":SENS:CURR:PROT " +num2str(currentCompliance)
	VISAWrite instr, variableWrite

	// Sets initial voltage, final voltage, and step size
	variableWrite = ":SOUR:VOLT:START " +num2str(initialVoltage)
	VISAWrite instr, variableWrite
	variableWrite = ":SOUR:VOLT:STOP " +num2str(finalVoltage)
	VISAWrite instr, variableWrite	
	variableWrite = ":SOUR:VOLT:STEP " +num2str(step)
	VISAWrite instr, variableWrite

	// Sets source to voltage sweep mode
	variableWrite = ":SOUR:VOLT:MODE SWE"
	VISAWrite instr, variableWrite
	
	// Sets sweep mode to linear  (0.02 V, 0.04 V, 0.06 V, etc)
	variableWrite = ":SOUR:SWE:SPAC LIN"
	VISAWrite instr, variableWrite
	
	// Sets number of points to be measured
	variableWrite = ":TRIG:COUN " + num2str(number)
	VISAWrite instr, variableWrite

	// Sets delay between measured points of 400 ms
	 variableWrite = ":SOUR:DEL " + num2str(delay)
	VISAWrite instr, variableWrite
	
	// reads number of points to be measured * not sure if necessary *
	variableWrite = ":TRAC:POIN " + num2str(number)
	VISAWrite instr, variableWrite
	
	// Begins feeding to buffer
	variableWrite = ":TRAC:FEED:CONT NEXT"
	VISAWrite instr, variableWrite
	
	// Turns on Source output
	variableWrite = ":OUTP ON"
	VISAWrite instr, variableWrite
	
	// Our old-ass 2400 doesn't have the CABort command so I took out the checkbox referenced below
	// if 'End Sweep at Current Compliance' is checked 
	//ControlInfo stopAtCurrentCompliance // retrieves status of auto-save checkbox
	// if (V_value == 1) //if it is checked
	// 	variableWrite = ":SOURce:SWEep:CABort EARLy"// abort at compliance
	//	VISAWrite instr, variableWrite	
	// elseif (V_value == 0) // if it is not checked	
	//	variableWrite = ":SOURce:SWEep:CABort NEVer"// do not abort at compliance
	//	VISAWrite instr, variableWrite	
	// endif
	
	
	// Initiates sweep, and then requests data as output
	variableWrite = ":READ?"
	VISAWrite instr, variableWrite	

	// requests data as waves
	VISAReadWave instr, voltage, current, resistance, measurementTime, stat
	currentAbs = abs(current)
	
	// Beep signals end of sweep
	variableWrite = ":SYSTem:BEEPer:IMMediate 800, .3"
	VISAWrite instr, variableWrite
	
	// turns off voltage, and shows output so one may see when current d		ies down.
	VISAWrite instr, ":SOURce:VOLT 0.0"
	VISAWrite instr, ":SYSTem:LOCal"

	viClose(instr)
	viClose(defaultRM)

	// create table to be saved as .iv file
	// check if a graph with the name "Table0" exists
	// maybe better to make table at beginning of program, just once?
	DoWindow/F Table0   // /F means 'bring to front if it exists'
	if (V_flag == 0)
    		// window does not exist
    	edit voltage
   	AppendToTable current
	else
		// window does exist
	AppendToTable voltage
	AppendToTable current    		
   endif
	
	saveTable(slideNumber, deviceNumber)
	DoWindow/B Table0 // brings table to back
End
	
Function saveTable(int slideNumber, int deviceNumber)

	SVAR measurementName = root:IVCurve:measurementName
	NVAR i = root:IVcurve:i
	WAVE deviceIterations = root:IVcurve:deviceIterations
	
	measurementName = nameFunction(slideNumber, deviceNumber) //by default, no time stamp
	ControlInfo quickRuns
	if (V_value == 0) // if quick runs is not checked
		
		ControlInfo autoSave // retrieves status of auto-save checkbox	
		if (V_value == 0) //if auto-save is not checked
			SaveTableCopy/I/N=0/T=1/P=DataFolder as measurementName
		elseif (V_value == 1) // if auto-save is checked
			GetFileFolderInfo/Z=1/P=DataFolder measurementName // checks if file already exists
			if (V_flag == 0) // if the file name is already taken
				measurementName = nameFunctionWithTime(slideNumber, deviceNumber)
				SaveTableCopy/N=0/T=1/P=DataFolder as measurementName
			else
				SaveTableCopy/N=0/T=1/P=DataFolder as measurementName
			endif
		endif
		
	elseif (V_value == 1) // if quick runs is checked
		measurementName = nameFunction(slideNumber, deviceIterations[i])
		GetFileFolderInfo/Z=1/P=DataFolder measurementName // checks if file already exists
			if (V_flag == 0) // if the file name is alrady taken
				measurementName = nameFunctionWithTime(slideNumber, deviceIterations[i])
				SaveTableCopy/N=0/T=1/P=DataFolder as measurementName
			else
				SaveTableCopy/N=0/T=1/P=DataFolder as measurementName
			endif
			 
	SaveTableCopy/N=0/T=1/P=DataFolder as measurementName
	endif
	
	nameFunction(slideNumber, deviceNumber) // takes away time append so display in gui is prettier
End



Function sixSweeps()
	variable n = 6 // number of sweeps
	NVAR i = root:IVcurve:i //so that function saveTable has access to what device on the slide we're on
	
	for (i = 0; i < n; i+=1) // why is this 0-indexed? because it is used in singlesweep to refer to wave with elements {1, 2, 3, 4, 5, 6}
		Printf "Device Measuring: %d", i
		singleSweep()
		DoUpdate
		if (i<5) // so we don't have to wait after last measurement
			sleep/s 10
		endif
	Endfor
End
	
		


// edits displayed name every time slideNumber or deviceNumber changed in GUI
Function SetVarProc(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva

	SVAR measurementName = root:IVCurve:measurementName
	NVAR slideNumber = root:IVCurve:slideNumber
	NVAR deviceNumber = root:IVCurve:deviceNumber
	
	measurementName = nameFunction(slideNumber, deviceNumber)

	return 0
End

// edits displayed name every time user changes dark setting
Function CheckProc(cba) : CheckBoxControl
	STRUCT WMCheckboxAction &cba

	SVAR measurementName = root:IVCurve:measurementName
	NVAR slideNumber = root:IVCurve:slideNumber
	NVAR deviceNumber = root:IVCurve:deviceNumber
	
	measurementName = nameFunction(slideNumber, deviceNumber)


	return 0
End


// Creates menu option
Menu "Carter Lab"
	"IV Curves", ivcurve()
End



// Makes GUI / panel
Window ivcurve() : Panel

	valueInitialization()

	PauseUpdate; Silent 1		// building window...
	NewPanel /W=(432,49,1296,586) as "IV Parameters"
	ShowTools/A
	SetDrawLayer UserBack
	SetDrawEnv fsize= 10
	DrawText 270,130,"This is a beta version. If you run into any problems or see possible improvements, let me know! - RMS, 818-270-1298"
	SetVariable voltageInitial,pos={19.00,11.00},size={209.00,18.00},title="Initial Voltage (volts)"
	SetVariable voltageInitial,fSize=12
	SetVariable voltageInitial,limits={-21,21,0},value= root:IVCurve:initialVoltage
	SetVariable voltageFinal,pos={18.00,33.00},size={210.00,18.00},title="Final Voltage (volts)"
	SetVariable voltageFinal,fSize=12
	SetVariable voltageFinal,limits={-21,21,0},value= root:IVCurve:finalVoltage
	SetVariable stepSize,pos={15.00,56.00},size={212.00,18.00},title="Step (volts)"
	SetVariable stepSize,fSize=12,limits={-21,21,0},value= root:IVCurve:step
	SetVariable currentCompliance,pos={16.00,80.00},size={212.00,18.00},title="Current compliance (amps)"
	SetVariable currentCompliance,fSize=12
	SetVariable currentCompliance,limits={-1.05,1.05,0},value= root:IVCurve:currentCompliance
	SetVariable delay,pos={14.00,103.00},size={215.00,18.00},title="Delay (seconds)"
	SetVariable delay,fSize=12,limits={-21,21,0},value= root:IVCurve:delay
	Button browseDirectory,pos={279.00,12.00},size={80.00,20.00},proc=ExportPath,title="Browse..."
	SetVariable exportDirectoryName,pos={371.00,12.00},size={452.00,18.00},title="Export Directory"
	SetVariable exportDirectoryName,fSize=12
	SetVariable exportDirectoryName,value= root:IVCurve:exportDir,styledText= 1
	Button sweepVoltage,pos={278.00,93.00},size={150.00,20.00},proc=initiateSweep,title="Begin Voltage Sweep"
	CheckBox dark,pos={608.00,37.00},size={45.00,16.00},proc=CheckProc,title="Dark?"
	CheckBox dark,fSize=10,value= 1,side= 1
	SetVariable slideNumber,pos={458.00,37.00},size={65.00,18.00},proc=SetVarProc,title="Slide"
	SetVariable slideNumber,fSize=12
	SetVariable slideNumber,limits={0,inf,1},value= root:IVCurve:slideNumber
	SetVariable deviceNumber,pos={528.00,36.00},size={75.00,18.00},proc=changeFileNameDisplay,title="Device"
	SetVariable deviceNumber,fSize=12
	SetVariable deviceNumber,limits={0,inf,1},value= root:IVCurve:deviceNumber
	CheckBox autoSave,pos={280.00,37.00},size={172.00,16.00},title="Auto-Save (no dialogue pop-up)"
	CheckBox autoSave,help={"No save dialogue. Saves file based on slide number, device number, and dark checkbox."}
	CheckBox autoSave,fSize=10,value= 1,side= 1
	TitleBox name,pos={678.00,36.00},size={72.00,23.00},fSize=12,fStyle=1
	TitleBox name,variable= root:IVCurve:measurementName
	CheckBox quickRuns,pos={278.00,58.00},size={155.00,16.00},title="Run 6 in a row (10 sec delay)"
	CheckBox quickRuns,help={"If you want to quickly run through your devices on your slide, this will name them in your chosen directory in order 4, 1, 5, 2, 6, 3"}
	CheckBox quickRuns,fSize=10,value= 1,side= 1
	String fldrSav0= GetDataFolder(1)
	SetDataFolder root:IVCurve:
	Display/W=(14,140,392,483)/HOST=#  current vs voltage
	SetDataFolder fldrSav0
	ModifyGraph notation(left)=1
	Label left "Current (amps)"
	Label bottom "Volage (volts)"
	RenameWindow #,G0
	SetActiveSubwindow ##
	String fldrSav1= GetDataFolder(1)
	SetDataFolder root:IVCurve:
	Display/W=(437,141,811,485)/HOST=#  currentAbs vs voltage
	SetDataFolder fldrSav1
	ModifyGraph log(left)=1
	Label left "Current (amps)"
	Label bottom "Voltage (volts)"
	RenameWindow #,G1
	SetActiveSubwindow ##
	
	
EndMacro



Function changeFileNameDisplay(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva

		
	SVAR measurementName = root:ivcurve:measurementName
	NVAR slideNumber = root:ivcurve:slideNumber
	NVAR deviceNumber = root:ivcurve:deviceNumber
	
	//measurementName = "cell" + num2str(slideNumber) + "-" + num2str(deviceNumber) + ".iv"
	// July 10 2021: how am I still editing this program? The commented line above meant that
	// when I iterated device number, the displaced device name didn't check for if it was dark
	// or not, leading to confusion about what was being measured. Note that the software was
	// correctly saving it if "Dark?" checkbox was checked or not checked. Just the displayed name
	// in the box was wrong
	measurementName = nameFunction(slideNumber, deviceNumber)

	return 0
End



IVcurve() // initializes panel
