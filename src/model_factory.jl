
"""
    grid_paramas(model_params[; seed = 1])

Returns an array of parameterdict for every model configuration given in `model_params`
"""
function grid_params(model_params; seed = 1)
        models = []
        function rec(rest_keys, values, dic, model)
                if isempty(rest_keys)
                        values_with_seed = vcat(values, :seed => seed)
                        push!(models, model => values_with_seed)
                        return
                end
                next_key = rest_keys[1]
                new_rest_keys = filter(x -> x != next_key, rest_keys)
                vals = dic[next_key]
                if typeof(vals) <: Vector
                        for i = 1:length(vals)
                                new_values = vcat(values, next_key => vals[i])
                                rec(new_rest_keys, new_values, dic, model)
                        end
                else
                        new_values = vcat(values, next_key => vals)
                        rec(new_rest_keys, new_values, dic, model)
                end

        end

        all_models = Dict{Symbol,Any}()

        for model in model_params
                if model[1] == :all_models
                        for key in keys(model[2])
                                all_models[key] = model[2][key]
                        end
                end
        end

        model_params = filter(x -> !(typeof(x[1]) <: Symbol), model_params)
        for model in model_params
                # multiple definition of parameters
                if typeof(model[1]) <: Vector
                        for m in model[1]
                                props = add_dicts(model[2], all_models)
                                rec(collect(keys(props)), [], props, m)
                        end
                # simple definition of parameters
                else
                        props = add_dicts(model[2], all_models)
                        rec(collect(keys(props)), [], props, model[1])
                end
        end
        return models
end



"""
    create_models(model_params[; seed =  1])

Returns a list of models, from the configuration in `model_params`
"""
create_models(model_params; seed = 1) = map(x -> x[1](; x[2]...), grid_params(model_params; seed = seed))

get_params(model_params) = map(x -> x[2], grid_params(model_params))


"""
    add_dicts(d_model, d_default)

adding `d_model` and `d_default` together, overwriting entries from `d_default`, if keys are defined in both dicts
"""
function add_dicts(d_model, d_default)
        d_ret = copy(d_default)
        for key in keys(d_model)
                d_ret[key] = d_model[key]
        end
        return d_ret
end
