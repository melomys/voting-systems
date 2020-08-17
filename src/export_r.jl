using RCall
using Distributed
export export_data


"""
    export_data(model_init_params, name; [...])

Runs the model with the given parameters and exports the evaluation data to .rds format
This function supports multiprocessing
"""
function export_data(model_init_params, name;
    model_properties = default_model_properties,
    evaluation_functions = default_evaluation_functions,
    iterations = 45,
    pack = 1)
    @time begin
    @sync @distributed for i=1:iterations

    model_dfs, corr_df = collect_model_data(
        model_init_params,
        model_properties,
        evaluation_functions,
        pack)
        export_rds(corr_df, model_dfs, name)
        end
    end
end



"""
    export_rds(df, model_dfs[, keyword = ""])

exports dataframes to .rds format
"""
function export_rds(df, model_dfs, keyword = "")

    no = rand(1:2147483647)


    if keyword == ""
        df_file = "data/df$(no).rds"
        model_dfs_file = "data/model_dfs$(no).rds"
    else
        df_file = "data/df_$(keyword)_$(no).rds"
        model_dfs_=ile = "data/model_dfs_$(keyword)_$(no).rds"
    end



    R"""
    saveRDS($(robject(df)), file = $df_file)
    """
end
