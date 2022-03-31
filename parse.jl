
function parse_graph(filename::String)
    lines = readlines("instances/" * filename * "/graph.txt")
    nb_nodes = parse(Int64, lines[2][findlast("nb_nodes", lines[2])[end]+1:end])
    nb_arcs = parse(Int64, lines[3][findlast("nb_arcs", lines[3])[end]+1:end])
    node_capacities = zeros((nb_nodes))
    latencies = zeros((nb_nodes, nb_nodes))
    graph = falses((nb_nodes, nb_nodes))
    node_costs = ones((nb_nodes))
    for line_index in 1:length(lines)-3
        line = lines[line_index+3]
        if length(split(line)) == 6
            i, j, ci, cj, lij, node_cost = parse.(Float64, split(line))
            i, j, ci, cj = round.(Int64, [i, j, ci, cj])
            node_costs[i+1] = node_cost
        else
            i, j, ci, cj, lij = parse.(Float64, split(line))
            i, j, ci, cj = round.(Int64, [i, j, ci, cj])
        end
        graph[i+1, j+1] = true
        latencies[i+1, j+1] = lij
        node_capacities[i+1] = ci
        node_capacities[j+1] = cj
    end
    return graph, node_capacities, latencies, node_costs
end

function parse_commodity(filename::String)
    lines = readlines("instances/" * filename * "/commodity.txt")
    nb_commodities = parse(Int64, lines[2][findlast("nb_commodities", lines[2])[end]+1:end])

    departure_nodes = zeros(Int, (nb_commodities))
    arrival_nodes = zeros(Int, (nb_commodities))
    flow = zeros((nb_commodities))
    max_latency = zeros((nb_commodities))
    for line_index in 1:length(lines)-2
        line = lines[line_index+2]
        start, endd, fl, lat = parse.(Float64, split(line))
        start, endd = round.(Int64, [start, endd])
        departure_nodes[line_index] = start + 1
        arrival_nodes[line_index] = endd + 1
        flow[line_index] = fl
        max_latency[line_index] = lat
    end
    return departure_nodes, arrival_nodes, flow, max_latency
end

function parse_fct_commod(filename::String, nb_commodities::Int64, nb_functions::Int64)
    lines = readlines("instances/" * filename * "/fct_commod.txt")

    fct_commodities = falses((nb_commodities, nb_functions, nb_functions + 1))
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

function parse_functions(filename::String, nb_nodes::Int64)
    lines = readlines("instances/" * filename * "/functions.txt")

    nb_functions = parse(Int64, lines[2][findlast("nb_functions", lines[2])[end]+1:end])

    functions_capacities = zeros((nb_functions))
    costs = zeros((nb_functions, nb_nodes))

    for line_index in 1:length(lines)-2
        line = lines[line_index+2]
        capacity, func_costs... = parse.(Int64, split(line))
        functions_capacities[line_index] = capacity
        costs[line_index, :] = func_costs[1:nb_nodes]
    end
    return functions_capacities, costs
end

function parse_affinity(filename::String, nb_commodities::Int64)
    lines = readlines("instances/" * filename * "/affinity.txt")
    exclusions = zeros(Int, (nb_commodities, 2))

    for line_index in 1:length(lines)
        line = lines[line_index]
        if length(split(line)) == 0
            exclusions[line_index, :] .= (0, 0)
        else
            f, g = parse.(Int64, split(line))
            exclusions[line_index, :] .= (f + 1, g + 1)
        end
    end
    return exclusions
end

mutable struct Instance
    nb_nodes::Int64
    nb_arcs::Int64

    graph #graphe
    node_capacities #capacité des noeuds
    latencies #latence des arcs
    node_costs #coût d'ouverture d'un noeud

    nb_commodities::Int64
    departure_nodes #noeud de départs
    arrival_nodes #noeud d'arrivée
    floww #débits
    max_latency #latence max

    nb_functions::Int64
    fct_commodities # Le client k prends la fonction f en couche c
    max_layer #couche max des commodité

    functions_capacities #capacité des fonctions
    costs #coût d'installation d'une fonction

    excl #fonctions incompatibles
    
    function Instance(filename::String)

        graph, node_capacities, latencies, node_costs = parse_graph(filename)
        nb_nodes, nb_arcs = size(graph)

        departure_nodes, arrival_nodes, flow, max_latency = parse_commodity(filename)
        nb_commodities = length(departure_nodes)

        functions_capacities, costs = parse_functions(filename, nb_nodes)
        nb_functions = length(functions_capacities)

        fct_commodities, max_layer = parse_fct_commod(filename, nb_commodities, nb_functions)

        excl = parse_affinity(filename, nb_commodities)

        new(nb_nodes, nb_arcs, graph, node_capacities, latencies, node_costs,
            nb_commodities, departure_nodes, arrival_nodes, flow, max_latency,
            nb_functions, fct_commodities, max_layer, functions_capacities, costs, excl)
    end
end

function make_data(inst::Instance)
    global inst_ = inst
    for arg in fieldnames(Instance)
        global arg_ = arg
        eval(:($arg_ = getfield(inst_, $(:arg_))))
    end
end