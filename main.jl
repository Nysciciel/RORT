using CPLEX
using JuMP
include("parse.jl")



function main(filename::String)
    model = Model(CPLEX.Optimizer)

    graph, latencies, node_capacities, node_costs = parse_graph(filename)
    nb_nodes = size(graph)[1]

    graph #graphe
    node_capacities #capacité des noeuds
    latencies #latence des arcs
    node_costs #coût d'ouverture d'un noeud

    departure_nodes, arrival_nodes, flow, max_latency = parse_commodity(filename)
    nb_commodities = length(departure_nodes)

    departure_nodes #noeud de départs
    arrival_nodes #noeud d'arrivée
    flow #débits
    max_latency #latence max

    fct_commodities, max_layer = parse_fct_commod(filename, nb_commodities)

    fct_commodities # Le client k prends la fonction f en couche c
    max_layer #couche max des commodité

    
    functions_capacities, costs = parse_functions(filename, nb_nodes)
    nb_functions = length(functions_capacities)

    functions_capacities #capacité des fonctions
    costs #coût d'installation d'une fonction

    excl = parse_affinity(filename, nb_commodities)

    excl #fonctions incompatibles

    @variable(model, x[k=1:nb_commodities,i=1:nb_nodes,j=1:nb_nodes,c=1:(nb_functions + 1)], Bin) # client k empreinte trajet i-j en couche c
    @variable(model, y[i=1:nb_nodes,f=1:nb_functions], Int) # nombre de fonctons f en i
    @variable(model, u[i=1:nb_nodes,f=1:nb_functions], Bin) #fonction f en i
    @variable(model, v[i=1:nb_nodes], Bin) #noeud i ouvert

    @objective(model, Min, sum(v[i]*node_costs[i] + sum(costs[f,i]*y[i,f] for f in 1:nb_functions) for i in 1:nb_nodes))

    function_activation1 = @constraint(model, [i=1:nb_nodes,f=1:nb_functions], node_capacities[i]*u[i,f] >= y[i,f], base_name="function_activation1")
    function_activation2 = @constraint(model, [i=1:nb_nodes,f=1:nb_functions], y[i,f] >= u[i,f], base_name="function_activation2")
    link = @constraint(model, [f=1:nb_functions,i=1:nb_nodes], u[i,f] <= v[i], base_name="link")
    node_capacity = @constraint(model, [i=1:nb_nodes], sum(y[i,f] for f in 1:nb_functions) <= v[i]*node_capacities[i], base_name="node_capacity")
    latency = @constraint(model, [k=1:2], sum(x[k,i,j,c]*latencies[i,j] for i in 1:nb_nodes,j in 1:nb_nodes,c in 1:(nb_functions + 1)) <= max_latency[k], base_name="latency")
    exclusion = @constraint(model, [i in 1:nb_nodes, index in size(excl,1); excl[index,1]!=0], y[i,excl[index,1]] <= node_capacities[i]*(1-u[i,excl[index,2]]), base_name="exclusion")
    function_capacity = @constraint(model, [i=1:nb_nodes,f=1:nb_functions], sum(flow[k]*x[k,i,i,c]*fct_commodities[k,f,c] for k in 1:nb_commodities,c in 1:(nb_functions + 1)) <= functions_capacities[f]*y[i,f], base_name="function_capacity")
    function_availability = @constraint(model, [i=1:nb_nodes,k=1:2,c=1:(nb_functions + 1)], x[k,i,i,c] <= sum(u[i,f]*fct_commodities[k,f,c] for f in 1:nb_functions), base_name="function_availability")
    start_flow = @constraint(model, [k=1:2], sum(x[k,departure_nodes[k],i,1] - x[k,i,departure_nodes[k],1] for i in 1:nb_nodes if graph[departure_nodes[k],i]==1) + x[k,departure_nodes[k],departure_nodes[k],1] ==1, base_name="start_flow")
    end_flow = @constraint(model, [k=1:2], sum(x[k,i,arrival_nodes[k],max_layer[k]] - x[k,arrival_nodes[k],i,max_layer[k]] for i in 1:nb_nodes if graph[i,arrival_nodes[k]]==1) + x[k,arrival_nodes[k],arrival_nodes[k],max_layer[k]-1]==1, base_name="end_flow")
    flow0 = @constraint(model, [k=1:2,i=1:nb_nodes,c=1+1:(nb_functions + 1); (!(i == departure_nodes[k] && c==1) && !(i == arrival_nodes[k]&& c==max_layer[k]))], sum(x[k,j,i,c] for j in 1:nb_nodes if graph[j,i]==1) + x[k,i,i,c-1] == sum(x[k,i,j,c] for j in 1:nb_nodes if graph[i,j]==1) + x[k,i,i,c], base_name="flow0")
    flow1 = @constraint(model, [k=1:2,i=1:nb_nodes,c=1; (!(i == departure_nodes[k] && c==1) && !(i == arrival_nodes[k]&& c==max_layer[k]))], sum(x[k,j,i,c] for j in 1:nb_nodes if graph[j,i]==1) == sum(x[k,i,j,c] for j in 1:nb_nodes if graph[i,j]==1) + x[k,i,i,c], base_name="flow1")

    optimize!(model)
    println(termination_status(model))
end

main("pdh/pdh_1")

