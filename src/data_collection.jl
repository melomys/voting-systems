import Base
using Logging
using Distributed
"""
    collect_model_data(
        model_init_params,
        model_properties,
        evaluation_functions,
        [iterations = 10]

runs a simulation for all model defined in `model_init_params`.

`model_properties`  : defines iteration evaluation functions
`evaluation_functions`: defines model evaluation functions
`iterations` : all models are simulated `iterations` times

Returns evaluated dataframes for the simulated models
"""
function collect_model_data(
    model_init_params,
    model_properties,
    evaluation_functions,
    iterations = 10,
)

    run_id = rand(1:2147483647)

    #creation result dataframe
    models = create_models(model_init_params)
    df = init_result_dataframe(
        evaluation_functions,
        models,
        model_properties,
    )


    model_dfs = []
    try
        for i = 1:iterations
            @info "$((i-1)/iterations*100) % | $(myid())"
            seed = abs(rand(Int32))
            models = create_models(model_init_params; seed = seed)

            for j = 1:length(models)
                @info "Step $i: $j"
                # run model
                tmp_model = models[j]
                agent_df, model_df = run!(
                    tmp_model,
                    tmp_model.agent_step!,
                    tmp_model.model_step!,
                    tmp_model.steps;
                    agent_properties = [],
                    model_properties = model_properties,
                )

                push!(model_dfs, model_df)

                ab_model = tmp_model
                ab_model_df = model_df
                push!(df, map(x -> x(ab_model, ab_model_df), evaluation_functions))
            end
        end
    catch e
        # don't throw away the simulation results, when julia is interrupted
        if isa(e, InterruptException)
            @info "Interrupted"
        else
            throw(e)
        end
    finally
        return model_dfs, df
    end
end


function Base.getproperty(value, name::Symbol, default_value)
    if hasproperty(value, name)
        return getproperty(value, name)
    else
        return default_value
    end
end

"""
    @get_post_data(property, func)

macro to create function, that collects post data over the given aggregation function
    the name function is namend after the collected post property and the given aggregation function
        the returned function can be given to the run! function
"""
macro get_post_data(property, func)
    if eval(func) === identity
        name = Symbol("", eval(property))
    else
        name = Symbol(func, "_", eval(property))
    end
    return :(
        function $name(model)
            collected = map(x -> getproperty(x, $property, NaN), model.posts)
            $func(collected)
        end
    )
end


"""
    @model_property_function(property,[func = identiy])

macro to create a function to return the given property from a model,
    the function is named after the property
"""
macro model_property_function(property, func = identity)
    if eval(func) === identity
        name = Symbol("", eval(property))
    else
        name = Symbol(func, "_", eval(property))
    end

    return :(function $name(model, model_df = Nothing)
        if hasproperty(model, Symbol($name))
            val = model.$(eval(property))
            if typeof(val) <: Union{Function,Distribution, Array, Tuple}
                string(val)
            else
                $func(model.$(eval(property)))
            end
        else
            NaN
        end
    end)
end


"""
    relative_post_data(data)

Returns dataframe, each row holds the given parameter over time of one post.
time in the dataframe is relative to the creation of the post.
the dataframe is right-padded with the last value of each post/NaN.
"""
function relative_post_data(data)
    padding = NaN
    ncols = maximum(map(length, data))
    left_padded = [
        vcat(data[i], ones(ncols - length(data[i])) * padding)
        for i = 1:length(data)
    ]
    left_padded_transformed =
        [map(x -> x[i], left_padded) for i = 1:length(left_padded[1])]
    filter_padding(x) = filter(!isnan, x)
    right_padded = map(
        x -> vcat(
            filter_padding(x),
            ones(length(data) - length(filter_padding(x))) * padding,
        ),
        left_padded_transformed,
    )
    DataFrame(right_padded)
end

"""
    post_data(data)

Returns dataframe, each column holds the given parameter over time of one post.
the dataframe ist left-padded with NaN.
"""
function post_data(data)
    padding = NaN
    ncols = maximum(map(length, data))
    DataFrame(
        Matrix(DataFrame([
            vcat(data[i], ones(ncols - length(data[i])) * padding)
            for i = 1:length(data)
        ]))',
    )
end


"""
    init_result_dataframe(functions, models, model_properties)

Returns initialized dataframe to collect data from the evaluation functions
"""
function init_result_dataframe(functions, models, model_properties)
    tmp_model = models[1]
    agent_df, model_df = run!(
        tmp_model,
        tmp_model.agent_step!,
        tmp_model.model_step!,
        1;
        agent_properties = [],
        model_properties = model_properties,
    )

    corr_dict = Dict()
    for func in functions
        r = func(tmp_model, model_df)
        #if typeof(r) <: Union{Int, Float64, Array, Symbol, String}
        if typeof(r) <: Int
            corr_dict[Symbol(func)] = Float64[]
        else
            corr_dict[Symbol(func)] = typeof(r)[]
        end
        #else
        #    corr_dict[Symbol(func)] = String[]
        #end
    end

    return DataFrame(corr_dict)
end
