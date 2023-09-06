using SparseArrays, LinearAlgebra, Printf

function del_selfloops!(
    A::SparseMatrixCSC{Tf, Ti}
)where {Ti <: Integer, Tf}
    A[diagind(A)] .= zero(Tf) 
    dropzeros!(A)
end


function read_flow_network(
    filename, 
    inext,  # extension of input file
    outext, # extension of output file
    filefolder=homedir()*"/HighestLabelPreflowPush/data/"
)
    U = Int64[]; V = Int64[]; Val = Int64[]
    n = 0; m = 0; s = 0; t = 0
    open(filefolder*filename*inext) do file
        line_counter = 0
        for l in eachline(file)
            line_counter += 1
            l = split(l, ' ')
            if line_counter == 1
                n = parse(Int64, l[1]); m = parse(Int64, l[2])
                s = parse(Int64, l[3]); t = parse(Int64, l[4])
            else
                u = parse(Int64, l[1]); v = parse(Int64, l[2]); c = parse(Int64, l[3])
                push!(U, u); push!(V, v); push!(Val, c)
            end
        end
    end
    B = sparse(U, V, Val, n, n)
    stdans = 0
    open(filefolder*filename*outext) do file
        for l in eachline(file)
            l = split(l, ' ')
            stdans = parse(Int64, l[1])
        end
    end
    return B, s, t, stdans 
end

include("hlpp.jl")
include("hlpp_csc.jl")

for dataset = ["blocked_zadeh_ex_negiizhao_1", "line_ex_negiizhao_1", 
    "zadeh_ex_negiizhao_1", "zadeh_ex_negiizhao_2", "zadeh_ex_negiizhao_3"] 
    @printf("dataset: %s\n", dataset)
    B, s, t, stdans = read_flow_network("TestDataLOJ127/"*dataset, ".in", ".out")
    del_selfloops!(B)
    B = Float64.(B)
    @show stdans
    hlpp_dt = @elapsed begin 
        hlpp_res = hlpp.maxflow(B, s, t)
        @show hlpp_res.cutvalue
        @assert hlpp_res.cutvalue == stdans
    end
    @show hlpp_dt
    hlpp_csc_dt = @elapsed begin
        hlpp_csc_res = hlpp_csc.maxflow(B, s, t)
        @show hlpp_csc_res.cutvalue
        @assert hlpp_csc_res.cutvalue == stdans
    end
    @show hlpp_csc_dt
end


for i = 1:36
    @printf("dataset: %s\n", "680/data$i")
    B, s, t, stdans = read_flow_network("680/"*"data$i", ".in", ".ans")
    del_selfloops!(B)
    B = Float64.(B)
    @show stdans
    hlpp_dt = @elapsed begin 
        hlpp_res = hlpp.maxflow(B, s, t, 0.0)
        @show hlpp_res.cutvalue
        @assert hlpp_res.cutvalue == stdans
    end
    @show hlpp_dt
    hlpp_csc_dt = @elapsed begin
        hlpp_csc_res = hlpp_csc.maxflow(B, s, t, 0.0)
        @show hlpp_csc_res.cutvalue
        @assert hlpp_csc_res.cutvalue == stdans
    end
    @show hlpp_csc_dt
end


for i = 1:12
    @printf("dataset: %s\n", "$i")
    B, s, t, stdans = read_flow_network("$i", ".in", ".out")
    del_selfloops!(B)
    B = Float64.(B)
    @show stdans
    hlpp_dt = @elapsed begin 
        hlpp_res = hlpp.maxflow(B, s, t, 0.0)
        @show hlpp_res.cutvalue
        @assert hlpp_res.cutvalue == stdans
    end
    @show hlpp_dt
    hlpp_csc_dt = @elapsed begin
        hlpp_csc_res = hlpp_csc.maxflow(B, s, t, 0.0)
        @show hlpp_csc_res.cutvalue
        @assert hlpp_csc_res.cutvalue == stdans
    end
    @show hlpp_csc_dt
end