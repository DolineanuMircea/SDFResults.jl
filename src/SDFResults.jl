module SDFResults

export read_simulation, EPOCHSimulation, SDFFile,
    get_time, get_parameter, get_npart

using Unitful
using PhysicalConstants.CODATA2018: c_0, ε_0, μ_0, m_e, e
using Statistics, StatsBase
using BangBang
using Transducers, ThreadsX
using SDFReader
using SDFReader: get_units
using PICDataStructures
using EPOCHInput

include("files.jl")
include("simulation.jl")
include("traits.jl")
include("read.jl")
include("utils.jl")

end