using SDFResults
using Test
using Unitful
using PICDataStructures
using RecursiveArrayTools: recursive_bottom_eltype

@testset "SDFResults.jl" begin
    dir = "gauss"
    sim = read_simulation(dir)
    @test sim isa EPOCHSimulation
    file = sim[1]
    @test file isa SDFFile

    # test for different code paths in expensive grid detection
    Ex, Ey = sim[1][:ex, :ey]
    Ez = sim[1][:ez]
    @test Ex isa ScalarField{3}
    @test Ey isa ScalarField{3}
    @test Ez isa ScalarField{3}
    @test unit(eltype(Ex)) == u"V/m"
    @test unit(recursive_bottom_eltype(getdomain(Ex))) == u"m"

    vars = (:grid, Symbol("py/electron"), Symbol("pz/electron"))
    @task all(vars .∈ keys(file))
    (x,y,z), py, pz = read(file, vars...)
    @test all(unit.(x) .== u"m")
    @test all(unit.(py) .== u"kg*m/s")

    t = get_time(file)
    @test (t |> u"fs") ≈ 10u"fs" atol = 0.1u"fs"

    nx, ny, nz = get_parameter.((file,), (:nx, :ny, :nz))
    @test nx == ny == nz == 10

    λ = get_parameter(file, :laser, :lambda)
    @test (λ |> u"nm") ≈ 800u"nm"

    @test ndims(file) == 3
    @test cell_volume(file) ≠ 0
end
