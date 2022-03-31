using CPLEX
using JuMP
include("parse.jl")


function floydwarshall(weights::Matrix, nvert::Int)
    dist = fill(Inf, nvert, nvert)
    for i in 1:size(weights, 1)
        dist[weights[i, 1], weights[i, 2]] = weights[i, 3]
    end
    # return dist
    next = collect(j != i ? j : 0 for i in 1:nvert, j in 1:nvert)
 
    for k in 1:nvert, i in 1:nvert, j in 1:nvert
        if dist[i, k] + dist[k, j] < dist[i, j]
            dist[i, j] = dist[i, k] + dist[k, j]
            next[i, j] = next[i, k]
        end
    end
 
    return next
    function printresult(dist, next)
        println("pair   dist    path")
        for i in 1:size(next, 1), j in 1:size(next, 2)
            if i != j
                u = i
                path = "$i $j   $(dist[i,j])    $i"
                while true
                    u = next[u, j]
                    path *= " -> $u"
                    if u == j break end
                end
                println(path)
            end
        end
    end
    printresult(dist, next)
end


function make_model_chemins(inst::Instance)
    model = Model(CPLEX.Optimizer)

    make_data(inst)

    weights = map.(x -> isnan(x) ? Inf : x , latencies./graph)
    distances = [k == 1 ? i÷nb_nodes : k == 2 ? (i%nb_nodes + 1) : weights[i÷nb_nodes, (i%nb_nodes + 1)] for i = nb_nodes:(nb_nodes^2 + nb_nodes - 1), k = 1:3]#[i j latencies[i,j]]
    next = floydwarshall(distances, nb_nodes)

    function cost_of_travel(i, j)
        current = i
        cost = 0
        while current != j
            cost += latencies[current, next[current, j]]
            current = next[current, j]
        end
        return cost
    end

    @variable(model, x[k=1:nb_commodities, i=1:nb_nodes, j=1:nb_nodes, c=1:(nb_functions+1)], Bin) # client k empreinte trajet i-j en couche c
    @variable(model, y[i=1:nb_nodes, f=1:nb_functions] >= 0, Int) # nombre de fonctons f en i
    @variable(model, u[i=1:nb_nodes, f=1:nb_functions], Bin) #fonction f en i
    @variable(model, v[i=1:nb_nodes], Bin) #noeud i ouvert

    @objective(model, Min, sum(v[i] * node_costs[i] + sum(costs[f, i] * y[i, f] for f in 1:nb_functions) for i in 1:nb_nodes))

    node_capacity = @constraint(model, [i = 1:nb_nodes], sum(y[i, f] for f in 1:nb_functions) <= v[i] * node_capacities[i], base_name = "node_capacity")
    latency = @constraint(model, [k = 1:nb_commodities], sum(x[k, i, j, c] * cost_of_travel(i, j) for i in 1:nb_nodes, j in 1:nb_nodes, c in 1:(nb_functions+1)) <= max_latency[k], base_name = "latency")
    exclusion = @constraint(model, [i in 1:nb_nodes, index in size(excl, 1); excl[index, 1] != 0], y[i, excl[index, 1]] <= node_capacities[i] * (1 - u[i, excl[index, 2]]), base_name = "exclusion")
    function_capacity = @constraint(model, [i = 1:nb_nodes, f = 1:nb_functions], sum(floww[k] * x[k, j, i, c] * fct_commodities[k, f, c] for j in 1:nb_nodes, k in 1:nb_commodities, c in 1:(nb_functions+1)) <= functions_capacities[f] * y[i, f], base_name = "function_capacity")
    
    function_availability = @constraint(model, [i = 1:nb_nodes, k = 1:nb_commodities, c = 1:max_layer[k]-1], sum(x[k, j, i, c] for j in 1:nb_nodes) <= sum(u[i, f] * fct_commodities[k, f, c] for f in 1:nb_functions), base_name = "function_availability")
    function_activation1 = @constraint(model, [i = 1:nb_nodes, f = 1:nb_functions], node_capacities[i] * u[i, f] >= y[i, f], base_name = "function_activation1")
    function_activation2 = @constraint(model, [i = 1:nb_nodes, f = 1:nb_functions], y[i, f] >= u[i, f], base_name = "function_activation2")
    link = @constraint(model, [f = 1:nb_functions, i = 1:nb_nodes], u[i, f] <= v[i], base_name = "link")

    start = @constraint(model, [k = 1:nb_commodities], sum(x[k, departure_nodes[k], j, 1] for j in 1:nb_nodes) == 1, base_name = "start")
    flow = @constraint(model, [k = 1:nb_commodities, c = 1:max_layer[k]], sum(x[k, i, j, 1] for i in 1:nb_nodes, j in 1:nb_nodes) == 1, base_name = "flow")
    continuity = @constraint(model, [k = 1:nb_commodities, i = 1:nb_nodes, c = 2:max_layer[k]], sum(x[k, j, i, c-1] for j in 1:nb_nodes) == sum(x[k, i, j, c] for j in 1:nb_nodes), base_name = "continuity")
    endd = @constraint(model, [k = 1:nb_commodities], sum(x[k, i, arrival_nodes[k], max_layer[k]] for i in 1:nb_nodes) == 1, base_name = "endd")

    return model
end

function run_chemins(instance::Instance)
    start = time()
    model = make_model_chemins(instance)
    set_silent(model)
    optimize!(model)
    if has_values(model)
        return objective_value(model), solve_time(model), termination_status(model)
    end


    return Inf, time()-start, termination_status(model)
end



println(run_chemins(Instance("test")))
println(run_chemins(Instance("pdh/pdh_1")))