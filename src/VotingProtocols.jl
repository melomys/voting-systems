module VotingProtocols

using Agents
using Distributions
using DataFrames
using LinearAlgebra
using RCall

include("user_creation.jl")

include("models/upvote_system.jl")
include("models/up_and_downvote_system.jl")

include("model_factory.jl")
include("metric.jl")
include("user_opinion.jl")
include("evaluation.jl")
include("data_collection.jl")

include("default.jl")

include("export_r.jl")


export upvote_system, up_and_downvote_system
export export_data
export default_evaluation_functions, default_model_properties
export dcg, ndcg, spearman, gini, @top_k_gini, @area_under, post_with_no_views, quality_sum, @model_df_column, post_views, vote_count
export metric_hacker_news, metric_reddit_hot, metric_activation, metric_view
export vote_difference, vote_partition, vote_wilson
export user, extreme_user
export no_deviation, std_deviation, mean_deviation
end
