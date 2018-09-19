using HDF5

import HDF5: h5read

export IMTFile, IMTFileCalib, IMTFileMeas, addTrailingSingleton

abstract type IMTFile <: MPIFile end

# We use a dedicated type for calib and meas. If both versions
# are the same we use the abstract type IMTFile
mutable struct IMTFileCalib <: IMTFile
  filename::String
  file::HDF5File
end

#IMTFileCalib(filename::String, file=h5open(filename,"r")) =
#   IMTFileCalib(filename, file, nothing)

function IMTFileCalib(filename::String, file=h5open(filename,"r"))
  f = IMTFileCalib(filename, file, nothing)

 return f
end

mutable struct IMTFileMeas <: IMTFile
  filename::String
  file::HDF5File
end

function IMTFileMeas(filename::String, file=h5open(filename,"r"))
  f = IMTFileMeas(filename, file, nothing)

  return f
end

# Dispatch on file extension
function (::Type{IMTFile})(filename::String, file = h5open(filename,"r"))
 if !exists(file, "/measurements")
   return IMTFileCalib(filename, file)
 else
   return IMTFileMeas(filename, file)
 end
end


function Base.show(io::IO, f::IMTFileCalib)
  print(io, "IMT calib: ", f.filename)
end

function Base.show(io::IO, f::IMTFileMeas)
  print(io, "IMT meas: ", f.filename)
end


function getindex(f::IMTFile, parameter)
  if exists(f.file, parameter)
    return read(f.file, parameter)
  else
    return nothing
  end
end

function getindex(f::IMTFile, parameter, default)
  if exists(f.file, parameter)
    return read(f.file, parameter)
  else
    return default
  end
end


# general parameters
version(f::IMTFile) = v"0.0.0"
uuid(f::IMTFile) = uuid4()
time(f::IMTFile) = Dates.unix2datetime(0)

# study parameters
studyName(f::IMTFile) = "n.a."
studyNumber(f::IMTFile) = 0
studyUuid(f::IMTFile) = uuid4()
studyDescription(f::IMTFile) = "n.a."

# experiment parameters
experimentName(f::IMTFile) = "n.a."
experimentNumber(f::IMTFile) = 0
experimentUuid(f::IMTFile) = uuid4()
experimentDescription(f::IMTFile) = "n.a."
experimentSubject(f::IMTFile) = "n.a."
experimentIsSimulation(f::IMTFile) = true
experimentIsCalibration(f::IMTFileMeas) = false
experimentIsCalibration(f::IMTFileCalib) = true
experimentHasReconstruction(f::IMTFile) = false
experimentHasMeasurement(f::IMTFile) = true

# tracer parameters
tracerName(f::IMTFile)::Vector{String} = _makeStringArray(["n.a"])
tracerBatch(f::IMTFile)::Vector{String} = ["n.a"]
tracerVolume(f::IMTFile)::Vector{Float64} = [0.0]
tracerConcentration(f::IMTFile)::Vector{Float64} = [0.0]
tracerSolute(f::IMTFile)::Vector{String} = ["Fe"]
tracerInjectionTime(f::IMTFile) = Dates.unix2datetime(0) 
tracerVendor(f::IMTFile)::Vector{String} = ["n.a."] 

# scanner parameters
scannerFacility(f::IMTFile)::String = "n.a."
scannerOperator(f::IMTFile)::String = "n.a."
scannerManufacturer(f::IMTFile)::String = "n.a."
scannerName(f::IMTFile)::String = "n.a."
scannerTopology(f::IMTFile)::String = "n.a."

# acquisition parameters
acqStartTime(f::IMTFile)::DateTime = Dates.unix2datetime(0) 
acqNumAverages(f::IMTFileCalib)::Int = 1 
acqNumAverages(f::IMTFileMeas)::Int = 1
acqNumFrames(f::IMTFileCalib)::Int = 1 
acqNumFrames(f::IMTFileMeas)::Int = 1 
acqNumPeriodsPerFrame(f::IMTFile)::Int = 1

acqGradient(f::IMTFile)::Array{Float64,4} = reshape(diagm([0.0,0.0,0.0]), 3,3,1,1)
acqOffsetField(f::IMTFile)::Array{Float64,3} = reshape([0.0,0.0,0.0],3,1,1)

# drive-field parameters
dfNumChannels(f::IMTFile) = 3
dfStrength(f::IMTFile) = [0.0 0.0 0.0] # addTrailingSingleton( addLeadingSingleton(f["/acquisition/drivefield/strength"], 2), 3)
dfPhase(f::IMTFile) = [0.0 0.0 0.0]   
dfBaseFrequency(f::IMTFile) = 2.5e6
dfCustomWaveform(f::IMTFile) = "n.a."
dfDivider(f::IMTFile) = reshape([102; 96; 99],:,1) 
dfWaveform(f::IMTFile) = "sine"
dfCycle(f::IMTFile) = f["/timeLength"]

# receiver parameters
rxNumChannels(f::IMTFileMeas) = size(f["/measurements"],2)
rxNumChannels(f::IMTFileCalib) = size(f["/numberOfAvailableFrequencies"],1) 
rxBandwidth(f::IMTFile)::Float64 = 1.25e6
rxNumSamplingPoints(f::IMTFile) = (f["/numberOfAvailableFrequencies"][1]-1)*2
rxTransferFunction(f::IMTFile) = nothing
rxInductionFactor(f::IMTFile) = nothing

rxUnit(f::IMTFile) = "a.u."
rxDataConversionFactor(f::IMTFile) = repeat([1.0, 0.0], outer=(1,rxNumChannels(f)))
#rxDataConversionFactor(f::IMTFileMeas) = f["/acquisition/receiver/dataConversionFactor"]

# measurements
function measData(f::IMTFile, frames=1:acqNumFrames(f), periods=1:acqNumPeriodsPerFrame(f),
                  receivers=1:rxNumChannels(f))
  if !exists(f.file, "/measurements")
    # file is calibration
    dataFD = f["/systemResponseFrequencies"]
    dataFD = reshape(reinterpret(Complex{eltype(dataFD)}, vec(dataFD)), (20,size(dataFD,2),size(dataFD,3),size(dataFD,4)))
    return dataFD = reshape(dataFD, (size(dataFD,1)*size(dataFD,2)*size(dataFD,3), 26929, 3, 1))
  end
  
  tdExists = exists(f.file, "/measurements")

  if tdExists
    dataTD = f["/measurements"]
    #TODO implement for frames > 1 
    dataTD = reshape(dataTD, size(dataTD,1), size(dataTD,2), 1, length(frames))
    return dataTD
  end
end

#function measDataTDPeriods(f::IMTFileCalib, periods=1:acqNumPeriods(f),
#                  receivers=1:rxNumChannels(f))
#  tdExists = exists(f.file, "/measurement/dataTD")

#  if tdExists
#    if f.mmap_measData == nothing
#      f.mmap_measData = readmmap(f.file["/measurement/dataTD"])
#    end
#    data = f.mmap_measData[:, receivers, periods]
#    return data
#  else
#    if f.mmap_measData == nothing
#      f.mmap_measData = readmmap(f.file["/measurement/dataFD"])
#    end
#    data = f.mmap_measData[:, :, receivers, periods]

#    dataFD = reinterpret(Complex{eltype(data)}, data, (size(data,2),size(data,3),size(data,4)))
#    dataTD = irfft(dataFD, 2*(size(data,2)-1), 1)
#    return dataTD
#  end
#end


#function measDataTDPeriods(f::IMTFileMeas, periods=1:acqNumPeriods(f),
#                  receivers=1:rxNumChannels(f))
#  if measIsTransposed(f)
#    error("measDataTDPeriods can currently not handle transposed data!")
#  end

#  data = reshape(f.mmap_measData,Val{3})[:, receivers, periods]

#  return data
#end

function systemMatrix(f::IMTFileCalib, rows, bgCorrection=true)
  if !experimentIsCalibration(f)
    return nothing
  end
  if f.mmap_measData == nothing
    f.mmap_measData = readmmap(f.file["/calibration/dataFD"])
  end

  data = reshape(f.mmap_measData,Val{3})[:, :, rows]
  return reinterpret(Complex{eltype(data)}, data, (size(data,2),size(data,3)))
end

function systemMatrix(f::IMTFileMeas, rows, bgCorrection=true)
  if !exists(f.file, "/measurement") || !measIsTransposed(f) ||
    !measIsFourierTransformed(f)
    return nothing
  end

  data_ = reshape(f.mmap_measData,size(f.mmap_measData,1),
                                  size(f.mmap_measData,2)*size(f.mmap_measData,3),
                                  size(f.mmap_measData,4))[:, rows, :]
  data = reshape(data_, Val{2})

  fgdata = data[measFGFrameIdx(f),:]
  if bgCorrection # this assumes equidistent bg frames
    println("Applying bg correction on system matrix (MDF)")
    bgdata = data[measBGFrameIdx(f),:]
    bgdataInterp = interpolate(bgdata, (BSpline(Linear()),NoInterp()), OnGrid())
    #Cubic does not work for complex numbers
    origIndex = measFramePermutation(f)
    M = size(fgdata,1)
    K = size(bgdata,1)
    N = M + K
    for m=1:M
      alpha = (origIndex[m]-1)/(N-1)*(K-1)+1
      for k=1:size(fgdata,2)
        fgdata[m,k] -= bgdataInterp[alpha,k]
      end
    end
  end
  return fgdata
end

function systemMatrixWithBG(f::IMTFileMeas)
  if !exists(f.file, "/measurement") || !measIsTransposed(f) ||
      !measIsFourierTransformed(f)
      return nothing
  end

  data = f.mmap_measData[:, :, :, :]
  return data
end

function measIsFourierTransformed(f::IMTFile)
  if !experimentIsCalibration(f)
    return false 
  else
    return true
  end
end

measIsTFCorrected(f::IMTFile) = false
measIsSpectralLeakageCorrected(f::IMTFile) = false

measIsBGCorrected(f::IMTFile) = false

measIsFrequencySelection(f::IMTFile) = false

measIsTransposed(f::IMTFileCalib) = true
measIsTransposed(f::IMTFileMeas) = false 

measIsFramePermutation(f::IMTFileCalib) = false 
measIsFramePermutation(f::IMTFileMeas) = false

measIsBGFrame(f::IMTFile) = zeros(Bool, acqNumFrames(f))

measFramePermutation(f::IMTFileCalib) = nothing
measFramePermutation(f::IMTFileMeas) = nothing

#fullFramePermutation(f::IMTFile) = fullFramePermutation(f, calibIsMeanderingGrid(f))

#calibrations
#calibSNR(f::IMTFile) = addTrailingSingleton(f["/calibration/snrFD"],3)
calibFov(f::IMTFile) = f["/fov"]
calibFovCenter(f::IMTFile) = [0.0,0.0,0.0]
calibSize(f::IMTFile) = nothing
calibOrder(f::IMTFile) = "xyz"
#calibOffsetField(f::IMTFile) = [0.0,0.0,0.0]
calibDeltaSampleSize(f::IMTFile) = [0.0,0.0,0.0]
calibMethod(f::IMTFile) = "simulation"
#calibIsMeanderingGrid(f::IMTFile) = Bool(f["/calibration/isMeanderingGrid", 0])
#calibPositions(f::IMTFile) = f["/calibration/positions"]


# additional functions that should be implemented by an MPIFile
filepath(f::IMTFile) = f.filename