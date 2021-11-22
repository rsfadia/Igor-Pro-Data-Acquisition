	#pragma TextEncoding = "UTF-8"	
#pragma rtGlobals=1		// Use modern global access method and strict wave access.

LoadWave/J/D/W/K=0 "Macintosh HD:Users:suecarter:Desktop:PhotoDiode calibration Data.txt"
	  Delimited text load from "PhotoDiode calibration Data.txt"
  Data length: 76, waves: wavelength_nm, Responsivity_A/W

Function valueInitialization()
	
	String saveDF = GetDataFolder(1) //almost like 'pwd' - 'print working directory'
	NewDataFolder/O/S root:EQE // creates new folder.
	
	variable/G compliance = 0.015
	variable/G initialVoltage = -1
	variable/G finalVoltage = 5
	variable/G stepSize = 0.1
	variable/G totalSteps = (finalVoltage - initialVoltage)/stepSize + 1
	
	variable/G peakWavelength = 550
	variable/G responsivity = 1.939718E-1
	
	SetDataFolder saveDF
End


Function ammeter()
	valueInitialization()	
	NVAR compliance = root:EQE:compliance
	NVAR initialVoltage = root:EQE:initialVoltage
	NVAR finalVoltage = root:EQE:finalVoltage
	NVAR stepSize = root:EQE:stepSize
	NVAR totalSteps = root:EQE:totalSteps

	NVAR peakWavelength = root:EQE:peakWavelength
	NVAR responsivity = root:EQE:responsivity
	
	make/N=(totalsteps)/O current 
	make/N=(totalsteps)/O currentDensity
	make/N=(totalsteps)/O absCurrDensity
	make/N=(totalsteps)/O voltage
	make/N=(totalsteps)/O photoCurrent 
	make/T/N=(totalsteps)/O dates
	make/T/N=(totalsteps)/O times
	
	Variable defaultRM, ammeter, sourcemeter
 	Variable status
 
 	// first thing you do before any VISA operations. Manages instruments
	status = viOpenDefaultRM(defaultRM)  
	// confirm resource manager created
	Printf "DefaultRM=%d\r", defaultRM
 
 	// resources = instruments
	String ammeterAddress = "GPIB0::22::INSTR" 
 	String sourcemeterAddress = "GPIB0::24::INSTR"
 	
 	//  opens session with instrument
	status = viOpen(defaultRM, ammeterAddress, 0, 0, ammeter)
	status = viOpen(defaultRM, sourcemeterAddress, 0, 0, sourcemeter)
	
	// confirms instrument session has begun
	Printf "instr=%d\r", ammeter
	Printf "instr=%d\r", sourcemeter
 	// variableWrite is used to pass commands to SourceMeter
	String variableWrite, variableRead
	
	
	
	
	// Restores instruments to default conditions
	variableWrite = "*RST"
	VISAWrite ammeter, variableWrite
	VISAWrite sourcemeter, variableWrite

	// sourcemeter will be voltage source	
	variableWrite = ":SOUR:FUNC VOLT"
	VISAWrite sourcemeter, variableWrite	
	
	// sourcemeter will have fixed voltage (as opposed to sweeping)
	variableWrite = ":SOUR:VOLT:MODE FIXED"
	VISAWrite sourcemeter, variableWrite

	// current compliance will be variable 'compliance'	
	variableWrite = "SENS:CURR:PROT " + num2str(compliance)
	VISAWrite sourcemeter, variableWrite
	
	// only output the current
	variableWrite = ":FORM:ELEM CURR"
	VISAWrite sourcemeter, variableWrite
	
	variableWrite = ":OUTP ON"
	VISAWrite sourcemeter, variableWrite
	
	int i = 0
	for (i = 0; i < totalSteps; i++)
		
		variable newVoltage = initialVoltage + i*stepSize
		voltage[i] = newVoltage
		
		// tell sourcemeter new voltage
		variableWrite = ":SOUR:VOLT:LEV " + num2str(newVoltage)
		VISAWrite sourcemeter, variableWrite
		
		sleep/s 1
		
		// request read from sourcemeter
		variableWrite = ":READ?"
		VISAWrite sourcemeter, variableWrite
		
		// read from sourcemeter 
		VISARead sourcemeter, variableRead
		current[i] = str2num(variableRead)
		currentDensity[i] = current[i]/0.03
		absCurrDensity[i] = abs(currentDensity[i])
		print(variableRead)
		
		// read from ammeter
		VISARead ammeter, variableRead
		Variable photocurrentElement = str2num(ReplaceString("NDCA",variableRead,""))
		photocurrent[i] = photocurrentElement
		print(variableRead)
		
		// this is a throwaway reading because ammeter throws in a \n in its buffer with ever measurement
		VISARead ammeter, variableRead
		dates[i] = date()
		times[i] = time()
		
		
		sleep/s 0.5

		endfor

	Display current vs voltage
	ModifyGraph log(left)=1
	Display photocurrent vs voltage
	ModifyGraph log(left)=1
	Display currentDensity vs voltage
	ModifyGraph log(left)=1
	Display absCurrDensity vs voltage
	ModifyGraph log(left)=1
	Edit voltage, photoCurrent, currentDensity, current, dates, times
	
	variableWrite = ":OUTP OFF"
	VISAWrite sourcemeter, variableWrite
		
	viClose(ammeter)
	viClose(sourcemeter)
	viClose(defaultRM)
End