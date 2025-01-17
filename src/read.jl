function read_entry(file, blocks, name)
    data_block = getindex(blocks, name)
    data = read(file, data_block)
    @debug "Reading $name"
    store_entry(data_block, data, file, blocks)
end

function read_selected(file, blocks, name, skip_grid)
    data_block = getindex(blocks, name)
    # don't read grid for particles
    isnothing(get_mesh_id(data_block)) && return nothing
    data = read(file, data_block)

    if get_mesh_id(data_block) in skip_grid
        (data=data, block=data_block)
    else
        store_entry(data_block, data, file, blocks)
    end
end

function get_mesh_id(file, idx)
    block = getindex(file.blocks, idx)
    get_mesh_id(block)
end

get_mesh_id(block::AbstractBlockHeader) = hasproperty(block, :mesh_id) ? Symbol(block.mesh_id) : nothing

store_entry(data_block::T, data, file, blocks) where T = store_entry(data_kind(T), data_block, data, file, blocks)

store_entry(::Grid, ::T, data, file, blocks) where T = store_entry(discretization_type(T), data)

function store_entry(::Data, data_block, data, file, blocks)
    mesh_block = getindex(blocks, get_mesh_id(data_block))
    grid = make_grid(mesh_block, data_block, file)

    @debug "Grid for data: $grid"
    store_entry(data_block, data, grid)
end

store_entry(data_block::T, data, grid) where T = store_entry(discretization_type(T), data_block, data, grid)
store_entry(::Variable, data::NTuple) = VectorVariable(data)

function store_entry(::StaggeredField, data_block, data, grid)
    ScalarField(data, grid)
end

function store_entry(::Variable, data_block, data, grid)
    ScalarVariable(data, grid)
end

make_grid(mesh_block::T, data_block, file) where T =
    make_grid(discretization_type(T), mesh_block, data_block, file)

function make_grid(::StaggeredField, mesh_block, data_block, file)
    units = get_units(mesh_block.units)
    minval = mesh_block.minval .* units
    maxval = mesh_block.maxval .* units
    dims = mesh_block.dims

    original_grid = map(eachindex(dims)) do i
        range(minval[i], maxval[i], length=dims[i])
    end
    @debug "Creating grid from $original_grid"

    stagger = data_block.stagger
    @debug "Staggering: $stagger"
    grid = apply_stagger(original_grid, Val(stagger))

    # Fix grid in the cases where it doesn't match the data. See
    # https://cfsa-pmw.warwick.ac.uk/SDF/SDF_C/-/blob/master/src/sdf_control.c#L775-780
    for i in axes(grid)[1]
        if length(grid[i]) ≠ data_block.dims[i]
            grid = setindex!!(grid, grid[i][begin:end-1], i)
        end
    end

    return SparseAxisGrid(grid)
end

function make_grid(::Variable, mesh_block, data_block, file)
    grid = read(file, mesh_block)
    units = get_units(mesh_block.units)

    minvals = (mesh_block.minval...,) .* units
    maxvals = (mesh_block.maxval...,) .* units

    ParticlePositions(grid, MVector(minvals), MVector(maxvals))
end

apply_stagger(grid, ::Val{CellCentre}) = (midpoints.(grid)...,)

function apply_stagger(grid, ::Val{FaceX})
    n = length(grid)
    if n == 1
        grid
    # TODO: 2D
    else
        (grid[1], midpoints.(grid[2:end])...)
    end
end

function apply_stagger(grid, ::Val{FaceY})
    n = length(grid)
    if n == 1
        grid
    else
        (midpoints(grid[1]), grid[2], midpoints(grid[3]))
    end
end

function apply_stagger(grid, ::Val{FaceZ})
    n = length(grid)
    if n == 1
        grid
    else
        (midpoints.(grid[1:2])..., grid[3])
    end
end

function apply_stagger(grid, ::Val{EdgeX})
    n = length(grid)
    if n == 1
        grid
    else
        (midpoints(grid[1]), grid[2:end]...)
    end
end

function apply_stagger(grid, ::Val{EdgeY})
    n = length(grid)
    if n == 1
        grid
    else
        (grid[1], midpoints(grid[2]), grid[3])
    end
end

function apply_stagger(grid, ::Val{EdgeZ})
    n = length(grid)
    if n == 1
        grid
    else
        (grid[1:2]..., midpoints(grid[3]))
    end
end

apply_stagger(grid, ::Val{Vertex}) = (grid...,)
