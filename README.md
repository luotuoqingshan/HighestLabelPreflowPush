# HighestLabelPreflowPush
A Julia Implementation of the Highest Label Preflow Push Variant of Push and Relabel Algorithm

## Introduction 
This repo implements the Highest Label Preflow Push(HLPP) algorithm with three heuristics.
- Global Relabeling
- Gap Relabeling
- Current Arc

[[1]](http://i.stanford.edu/pub/cstr/reports/cs/tr/94/1523/CS-TR-94-1523.pdf) is a good reference. This [uoj submission](https://uoj.ac/submission/643971) is an excellent C++ implementation which this repo mainly follows. This repo also 
reuses many code snippets from this [Julia implemetation](https://github.com/nveldt/PushRelabelMaxFlow) of FIFO Push and Relabel.  

```hlpp.jl``` implements one version using arrays to track flow, which is faster. ```hlpp_csc.jl``` implements one version using SparseMatrixCSC to track flow, which is easier to understand although slower. ```hlpp.jl``` is better commented. 

## Usage
```
include("hlpp.jl")

# create adjacency matrix B, source node s, sink node t from your data
# call maxflow

res = hlpp.maxflow(B, s, t)
```
There are two things to pay attention to.
- If you want to specify flowtol when the capacities are floating numbers, make sure flowtol has the same type with capacities.
- I manually set the infinite capacity as 1e15 when capacities are floating numbers, enlarge it when necessary.

## Testing Data
The testing data under ```./data``` folder are from [loj101](https://loj.ac/p/101/files) and [uoj680](https://uoj.ac/problem/680)(click "附件下载", you will get two test cases, I rename them to test case 11 and 12). You can get 36 main test cases of uoj680 from uoj if you email the manager.
Moreover, you can get 25 more test cases from [loj127](https://loj.ac/p/127/files).

### Testing Data Format
The first line contains four integers ```n m s t``` which indicates number of vertices, number of directed edges, index of source node, index of sink node respectively. Each of the following line 
contains three integers ```u v c``` indicating one directed edge from ```u``` to ```v``` with capacity ```c```.

Testing Data may contain self-loops and directed edges between ```s``` and ```t```.

## References
1. Cherkassky, Boris V., and Andrew V. Goldberg. "On implementing push-relabel method for the maximum flow problem." In International conference on integer programming and combinatorial optimization, pp. 157-171. Berlin, Heidelberg: Springer Berlin Heidelberg, 1995.

## Contact
To report bugs or for any other questions, feel free to open an issue or reach out via email to ```huan1754@purdue.edu```.