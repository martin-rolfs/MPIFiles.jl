@testset "Testing Cartesian Sequence submodule" begin

fnSMTD = "./data/mdf/systemMatrixCartesian.mdf"
fnSMFDMP = "./data/mdf/systemMatrixCartesianMP.mdf"
fnSMFDSP = "./data/mdf/systemMatrixCartesianSP.mdf"

smTD = MPIFile(fnSMTD)
@test typeof(smTD) <: MDFFileV2


@test acqNumPeriodsPerFrame(smTD) == 6500
@test size(getSystemMatrix(smTD,1:10)) == (81,6500*10)
@test size(getMeasurements(smTD)) == (76, 2, 6500, 81)
@test size(getMeasurements(smTD, numPeriodAverages=65)) == (76, 2, 100, 81)
@test size(getMeasurements(smTD, numPeriodAverages=65, numPeriodGrouping=100)) == (7600, 2, 1, 81)
@test size(getMeasurementsFD(smTD, frequencies=1:10)) == (10, 6500, 81)

saveasMDF(fnSMFDMP, smTD, numPeriodAverages=65, applyCalibPostprocessing=true)
smFDMP = MPIFile(fnSMFDMP)

@test acqNumPeriodsPerFrame(smFDMP) == 100
@test size(getSystemMatrix(smFDMP,1:10)) == (81,10*100)

saveasMDF(fnSMFDSP, smTD, numPeriodAverages=65, applyCalibPostprocessing=true, numPeriodGrouping=100)
smFDSP = MPIFile(fnSMFDSP)

@test acqNumPeriodsPerFrame(smFDSP) == 1
@test size(getSystemMatrix(smFDSP,1:10)) == (81,10)

end