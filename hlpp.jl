using MatrixNetworks
using SparseArrays

# Push Relabel solver for maximum s-t flow, minimum s-t cut problems

mutable struct stFlow{Tf, Ti}
    flowvalue::Tf # gives you the max-flow value
    cutvalue::Tf # gives min-cut value, which should equal flowvalue,
                      # but may differ by a small amount.
    source_nodes::Vector{Ti} # give the indices of the nodes attached to the source
    height::Vector{Ti} # gives the final height of each node
    C::SparseMatrixCSC{Tf, Ti} # gives the original capacity matrix
    F::SparseMatrixCSC{Tf, Ti} # gives the values of the flows on each edge
    s::Ti  # index of source node
    t::Ti # index of sink node
end


"""
maxflow implementation using the highest label preflow push method.

Given a sparse matrix A representing a weighted and possibly directed graph,
a source node s, and a sink node t, return the maximum s-t flow.

flowtol = tolerance parameter for whether there is still capacity available on
            an edge. Helps avoid rounding errors. Default is 1e-6.

Returns F, which is of type stFlow.
"""
function maxflow_hlpp(
    B::SparseMatrixCSC{Tf, Ti},
    s::Ti,
    t::Ti,
    flowtol=nothing,
) where {Ti <: Integer, Tf}
    # Set the default value of flowtol
    if flowtol === nothing
        if Tf <: AbstractFloat
            flowtol = 1e-6
        elseif Tf <: Integer
            flowtol = 0
        else
            error("Type of Flow not supported")
        end
    else
        if typeof(flowtol) != Tf
            error("Type of flowtol should match value type of capacity matrix.")
        end
        if Tf <: AbstractFloat
            # flowtol should be relatively small
            if flowtol >= .1
                println("flowtol is a tolerance parameter for rounding small \
                residual capacity edges to zero, and should be much \
                smaller than $flowtol. Changing it to default value 1e-6")
                flowtol = 1e-6
            end
        elseif Tf <: Integer 
            if flowtol != 0
                flowtol = 0
                println("For integral flow, flowtol should be 0. Changing it to 0.")
            end
        else
            error("Type of Flow not supported")
        end
    end

    n = size(B, 1)
    sWeights = Array(B[s,:])
    tWeights = Array(B[:,t])
    NonTerminal = setdiff(collect(1:n),[s t])

    sWeights = sWeights[NonTerminal]
    tWeights = tWeights[NonTerminal]

    # Extract the edges between non-terminal nodes
    A = B[NonTerminal,NonTerminal]

    # A = the matrix of capacities for all nodes EXCEPT the source and sink
    # sWeights = a vector of weights for edges from source to non-terminal nodes
    # tWeights = vector of weights from non-terminal nodes to the sink node t.

    # This is the map from the original node indices to the rearranged
    # version in which the source is the first node and the sink is the last
    Map = [s; NonTerminal; t]

    # Directly set up the flow matrix
    C = [spzeros(Tf, 1, 1) B[s, NonTerminal]' spzeros(Tf, 1, 1);
         spzeros(Tf, n - 2, 1) A spzeros(Tf, n - 2, 1);
         spzeros(Tf, 1, 1) B[t, NonTerminal]' spzeros(Tf, 1, 1)]

    #I, J, V = findnz(C)
    ## allocate space for reverse edges, assign the capacities of them as 0
    #Cundir = sparse([I; J], [J; I], [V; zeros(Tf, length(V))], n, n)

    ## Allocate space for the flow we will calculate
    #F = SparseMatrixCSC{Tf, Ti}(n,n,Cundir.colptr,Cundir.rowval,zeros(Tf, length(Cundir.rowval)))

    S, FlowMat, height, flowvalue = HLPP(C, flowtol)
    inS = zeros(Bool, n)
    inS[S] .= true
    cutvalue = zero(Tf) 
    for i = eachindex(I)
        if inS[I[i]] && !inS[J[i]]
            cutvalue += V[i]
        end
    end
    smap = sortperm(Map)
    @show B[s, t]
    return stFlow{Tf, Ti}(flowvalue + B[s, t], cutvalue + B[s, t], sort(Map[S]),
                          height, Cundir[smap, smap], FlowMat[smap, smap], s, t)
end


"""
This maxflow code assumes that A represents the adjacencies between
non-terminal nodes. Edges adjecent to source node s and sink node t
are given by vectors svec and tvec.

This code sets s as the first node, and t as the last node.
"""
function maxflow_hlpp(
    A::SparseMatrixCSC{Tf, Ti},
    svec::Vector{Tf},
    tvec::Vector{Tf},
    flowtol=nothing,
) where {Ti <: Integer, Tf}

    n = size(A, 1)

    # Directly set up the flow matrix
    C = [spzeros(1,1) sparse(svec') spzeros(1,1);
         spzeros(n, 1) A spzeros(n, 1);
         spzeros(1,1) sparse(tvec') spzeros(1,1)]

    return maxflow_hlpp(C, 1, n+2, flowtol)
end


"""
Given a flow, stored in an stFlow object, return the set of nodes attached to
the source
"""
function source_nodes(F::stFlow)
    # Run a bfs from the sink node. Anything with distance
    # n is disconnected from the sink. Thus it's part of the minimium cut set
    n = size(F.C,2)
    S = Vector{Int64}()
    for i = 1:n
        if F.height[i] == n
            push!(S,i)
        end
    end

    # Sanity checks: source node is on source side, sink node is on sink side
    @assert(~in(F.t,S))
    @assert(in(F.s,S))

    return S
end


"""
Given a flow, stored in an stFlow object, return the set of nodes attached to
the sink
"""
function sink_nodes(F::stFlow)
    # Run a bfs from the sink node. Anything with distance < n is sink-attached.
    n = size(F.C,2)
    T = Vector{Int64}()
    for i = 2:n
        if F.height[i] < n
            push!(T,i)
        end
    end

    # Sanity checks
    @assert(in(F.t,T))
    @assert(~in(F.s,T))

    return T
end

"""
Gives the cut as a list of edges.
"""
function cut_edges(F::stFlow)
    # Run a bfs from the sink node to get source and sink sets
    n = size(F.C,2)
    T = Vector{Int64}()
    S = Vector{Int64}()
    for i = 1:n
        if F.height[i] < n
            push!(T,i)
        else
            push!(S,i)
        end
    end

    I,J,V = findnz(F.C[S,T])
    return [S[I] T[J]]
end


"""
Gives the non-terminal cut edges.
"""
function cut_edges_nonterminal(F::stFlow)
    # Run a bfs from the sink node to get source and sink sets
    Edges = cut_edges(F)
    T = Vector{Int64}()
    S = Vector{Int64}()
    for i = 1:size(Edges,1)
        I = Edges[i,1]
        J = Edges[i,1]
        if I != F.t && I!= F.s && J != F.t && J != F.s
            push!(S,I)
            push!(T,J)
        end
    end
    return [S T]
end


mutable struct Edge{Tf, Ti}
    to::Ti
    cap::Tf
    flow::Tf
    rev::Ti # pointer to reverse edge
end

"""
Main function for Highest Label Preflow Push Method
"""
function HLPP(
    C::SparseMatrixCSC{Tf, Ti},
    flowtol::Tf,
) where {Ti <: Integer, Tf}
    n = size(C, 1) # number of vertices in the graph
    m = nnz(C)

    # height(level) of nodes
    height = zeros(Ti, n)

    function ConstructAdjlist()
        cursor = zeros(Ti, n)
        m_starts = zeros(Ti, n + 1)
        d = zeros(Ti, n)
        I, J, V = findnz(C)
        for k = eachindex(I)
            u = I[k]; v = J[k];
            if u != v
                d[u] += 1 
                d[v] += 1 
            end 
        end
        for i = 1:n
            cursor[i] = (i == 1) ? 1 : cursor[i - 1] + d[i - 1]
            m_starts[i] = cursor[i]
        end
        m_starts[n + 1] = cursor[n] + d[n]
        edges = Vector{Edge{Tf, Ti}}(undef, m_starts[n+1]-1)
        for k = eachindex(I)
            u = I[k]; v = J[k]; c = V[k]
            if u != v
                edges[cursor[u]] = Edge(v, c, zero(Tf), cursor[v])
                edges[cursor[v]] = Edge(u, zero(Tf), zero(Tf), cursor[u])
                cursor[u] += 1
                cursor[v] += 1
            end 
        end
        return m_starts, edges
    end
    # allocate space for reverse edges, assign the capacities of them as 0

    # active nodes
    # for each level, use a cyclic linked list to store active nodes
    excess = zeros(Tf, n)
    excess_next = zeros(Ti, n * 2 + 1)
    # maximum height of active nodes
    excess_height = zero(Ti) 

    # Infinite capacity
    if Tf <: AbstractFloat
        infinite_cap = 1e15
    elseif Tf <: Integer
        infinite_cap = Tf(round(typemax(Tf) / 2))
    else
        error("Type of Flow not supported")
    end
    infinite_height = Ti(round(typemax(Ti) / 2))

    m_starts, edges = ConstructAdjlist()

    function excess_insert(v::Ti, h::Ti) 
        excess_next[v] = excess_next[n + 1 + h]
        excess_next[n + 1 + h] = v
        if h > excess_height
            excess_height = h
        end
    end

    function excess_add(v::Ti, f::Tf)
        excess[v] += f
        if excess[v] <= f
            excess_insert(v, height[v])
        end
    end

    function excess_remove(v::Ti, f::Tf)
        excess[v] -= f
    end

    gap_prev = zeros(Ti, n * 2 + 1)
    gap_next = zeros(Ti, n * 2 + 1)
    gap_highest = zero(Ti)

    function gap_insert(v::Ti, h::Ti)
        gap_prev[v] = n + 1 + h 
        gap_next[v] = gap_next[n + 1 + h]
        gap_prev[gap_next[v]] = v
        gap_next[gap_prev[v]] = v
        if h > gap_highest
            gap_highest = h
        end
    end


    function gap_erase(v::Ti)
        gap_next[gap_prev[v]] = gap_next[v]
        gap_prev[gap_next[v]] = gap_prev[v]
    end

    
    function update_height(v::Ti, h::Ti)
        if height[v] != infinite_height 
            gap_erase(v)
        end
        height[v] = h
        if h != infinite_height 
            gap_insert(v, h)
            if excess[v] > 0 
                excess_insert(v, h)
            end
        end
    end

    discharge_count::Ti = 0
    function global_relabel()
        discharge_count = 0 

        #initialize head of linked lists
        for i = n + 1: 2 * n + 1
            excess_next[i] = i
            gap_prev[i] = i
            gap_next[i] = i
        end
        fill!(height, infinite_height)
        height[n] = 0
        queue = zeros(Ti, n)
        head = 1
        tail = 1
        queue[tail] = n
        while head <= tail
            u = queue[head]
            head += 1
            for i in m_starts[u]:m_starts[u + 1] - 1 
                v = edges[i].to
                revid = edges[i].rev
                if edges[revid].flow < edges[revid].cap && height[v] > height[u] + 1 
                    update_height(v, height[u] + 1)
                    tail += 1
                    queue[tail] = v
                end
            end
        end
    end

    function push(u::Ti, v::Ti, f::Tf)
        excess_remove(u, f)
        excess_add(v, f)
        F[u, v] += f
        F[v, u] -= f 
    end

    # pointers for current arc heuristic
    cur_arc = ones(Ti, n)

    function discharge(u::Ti)
        h = n 
        pos = cur_arc[u] 
        du = length(Neighbors[u])
        while cur_arc[u] <= du 
            v = Neighbors[u][cur_arc[u]]
            if F[u, v] < C[u, v]
                if height[u] == height[v] + 1
                    push(u, v, min(excess[u], C[u, v] - F[u, v]))
                    if excess[u] <= 0
                        return
                    end
                else
                    if height[v] < h 
                        h = height[v]
                    end
                end
            end
            cur_arc[u] += 1
        end
        cur_arc[u] = 1
        while cur_arc[u] < pos
            v = Neighbors[u][cur_arc[u]]          
            if F[u, v] < C[u, v]
                if height[u] == height[v] + 1
                    push(u, v, min(excess[u], C[u, v] - F[u, v]))
                    if excess[u] <= 0
                        return
                    end
                else
                    if height[v] < h 
                        h = height[v]
                    end
                end
            end
            cur_arc[u] += 1
        end
        discharge_count += 1
        if gap_next[gap_next[n + 1 + height[u]]] <= n
            update_height(u, h == n ? infinite_height : h + 1)
        else
            oldh = height[u]
            for h = height[u]:gap_highest
                while gap_next[n + 1 + h] <= n
                    j = gap_next[n + 1 + h]
                    height[j] = infinite_height
                    gap_erase(j)
                end
            end
            gap_highest = oldh - 1
        end
    end

    function print_key_variables()
        for i = 1:n
            print("$(height[i]) ")
        end
        println("")
        for i = 1:n
            print("$(excess[i]) ")
        end
        println("")
    end

    global_relabel()
    if height[1] < infinite_height
        excess_add(1, infinite_cap)
        excess_remove(n, infinite_cap)
        while excess_height > 0 
            while true
                v = excess_next[n + 1 + excess_height]
                if v > n
                    break
                end
                excess_next[n + 1 + excess_height] = excess_next[v]
                if height[v] != excess_height
                    continue
                end
                discharge(v)
                if discharge_count >= 4 * n
                    global_relabel()
                end
            end
            excess_height -= 1
        end
    end
    S = Vector{Ti}()
    global_relabel()
    for i = 1:n
        if height[i] == infinite_height
            push!(S, i)
        end
    end
    return S, F, height, excess[n] + infinite_cap
end
