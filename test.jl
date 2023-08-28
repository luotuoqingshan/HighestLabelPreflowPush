using SparseArrays

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

B, s, t, stdans = read_flow_network("680/data1", ".in", ".ans")