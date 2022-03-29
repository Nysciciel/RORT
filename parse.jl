
filename = "test"

function parse_graph(filename::String)
    lines = readlines("instances/"*filename*"/graph.txt")
    nb_nodes = parse(Int64, lines[2][findlast("nb_nodes", lines[2])[end]+1:end])
    nb_arcs = parse(Int64, lines[3][findlast("nb_arcs", lines[3])[end]+1:end])
    node_capacities = zeros((nb_nodes))
    latencies = zeros((nb_nodes, nb_nodes))
    graph = falses((nb_nodes, nb_nodes))
    node_costs = ones((nb_nodes))
    for line_index in 1:length(lines) - 3
        line = lines[line_index + 3]
        if length(split(line)) == 6
            i, j, ci, cj, lij, node_cost = parse.(Int64, split(line))
            node_costs[i + 1] = node_cost
        else
            i, j, ci, cj, lij = parse.(Int64, split(line))
        end
        graph[i + 1, j + 1] = true
        latencies[i + 1, j + 1] = lij
        node_capacities[i + 1] = ci
        node_capacities[j + 1] = cj
    end
    return graph, latencies, node_capacities, node_costs
end

g, l, Cn, cn = parse_graph(filename)
nb_nodes = size(g)[1]


function parse_commodity(filename::String)
    lines = readlines("instances/"*filename*"/commodity.txt")
    nb_commodities = parse(Int64, lines[2][findlast("nb_commodities", lines[2])[end]+1:end])
    
    departure_nodes = zeros(Int, (nb_commodities))
    arrival_nodes = zeros(Int, (nb_commodities))
    flow = zeros((nb_commodities))
    max_latency = zeros((nb_commodities))
    for line_index in 1:length(lines) - 2
        line = lines[line_index + 2]
        start, endd, fl, lat = parse.(Int64, split(line))
        departure_nodes[line_index] = start + 1
        arrival_nodes[line_index] = endd + 1
        flow[line_index] = fl
        max_latency[line_index] = lat
    end
    return departure_nodes, arrival_nodes, flow, max_latency
end

s, t, b, L = parse_commodity(filename)
nb_commodities = length(s)

function parse_fct_commod(filename::String, nb_commodities::Int64)
    lines = readlines("instances/"*filename*"/fct_commod.txt")
    
    max_f = max( [max(a...) for a in map.(x->parse(Int64,x), split.(lines))]...) + 1

    fct_commodities = falses((nb_commodities, max_f, max_f + 1))
    max_layer = zeros(Int, (nb_commodities))


    for line_index in 1:length(lines)
        line = lines[line_index]
        functions_order = parse.(Int64, split(line))
        for c in 1:length(functions_order)
            f = functions_order[c]
            fct_commodities[line_index, f+1, c] = true
        end
        max_layer[line_index] = length(functions_order) + 1
    end
    return fct_commodities, max_layer
end

C, max_c = parse_fct_commod(filename, nb_commodities)


function parse_functions(filename::String, nb_nodes::Int64)
    lines = readlines("instances/"*filename*"/functions.txt")

    nb_functions = parse(Int64, lines[2][findlast("nb_functions", lines[2])[end]+1:end])

    functions_capacities = zeros((nb_functions))
    costs = zeros((nb_functions, nb_nodes))

    for line_index in 1:length(lines) - 2
        line = lines[line_index + 2]
        capacity, func_costs... = parse.(Int64, split(line))
        functions_capacities[line_index] = capacity
        costs[line_index,:] = func_costs
    end
    return functions_capacities, costs
end

Cf, ci = parse_functions(filename, nb_nodes)
nb_functions = length(Cf)


function parse_affinity(filename::String, nb_commodities::Int64)
    lines = readlines("instances/"*filename*"/affinity.txt")
    exclusions = zeros(Int, (nb_commodities,2))

    for line_index in 1:length(lines)
        line = lines[line_index]
        if length(split(line)) == 0
            exclusions[line_index,:] .= (0,0)
        else
            f,g = parse.(Int64, split(line))
            exclusions[line_index,:] .= (f+1, g+1)
        end
    end
    return exclusions
end

excl = parse_affinity(filename, nb_commodities)