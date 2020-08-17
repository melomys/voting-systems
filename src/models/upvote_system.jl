using DrWatson

using Agents
using DataFrames
using Statistics
using Distributions
using LinearAlgebra
using Random

abstract type AbstractPost end
abstract type AbstractUser <: AbstractAgent end

mutable struct Post <: AbstractPost
    quality::Array
    votes::Int64
    downvotes::Int64
    views::Int64
    timestamp::Int64
    score::Float64
end
"""
    Post(rng::MersenneTwister, quality_distribution, time, [init_score = 0])

Creates a post with the given parameters

"""
function Post(rng::MersenneTwister, quality_distribution, time, init_score = 0)
    Post(rand(rng, quality_distribution), 0, 0,0, time, init_score)
end

mutable struct User <: AbstractUser
    id::Int
    quality_perception::Array
    vote_probability::Float64
    activity_probability::Float64
    concentration::Int64
    voted_on::Set{AbstractPost}
    viewed::Set{AbstractPost}
end


"""
    User(
        id::Int,
        quality_perception::Array{Float64},
        vote_probability::Float64,
        activity_probability::Float64,
        concentration::Int64,
    )

Creates a user with given parameters. It is called only by Agents.jl

"""
function User(
    id::Int,
    quality_perception::Array{Float64},
    vote_probability::Float64,
    activity_probability::Float64,
    concentration::Int64,
)
    User(
        id,
        quality_perception,
        vote_probability,
        activity_probability,
        concentration,
        Set{AbstractPost}(),
        Set{AbstractPost}(),
    )
end

"""
    upvote_system(;[...])

Creates a upvote system, agent-based model, and intializes all necessary parameters.
The upvote system allows users to upvote posts only
"""
function upvote_system(;
    activity_distribution = Beta(2.5,5),
    agent_step! = agent_step!,
    concentration_distribution = Poisson(50),
    deviation_function = no_deviation,
    equal_posts = false,
    gravity = 0,
    init_score = 0,
    model_step! = model_step!,
    model_type = upvote_system,
    new_posts_per_step = 10,
    new_users_per_step = 0,
    PostType = Post,
    quality_dimensions = 3,
    quality_distribution = Distributions.MvNormal(
        zeros(quality_dimensions),
        I(quality_dimensions),
    ),
    relevance_gravity = 0,
    rating_metric = scoring,
    seed = 0,
    sorted = 0,
    start_posts = 100,
    start_users = 100,
    steps = 100,
    user = user(),
    UserType = User,
    user_opinion_function = consensus,
    vote_evaluation = vote_difference,
    voting_probability_distribution = Beta(2.5,5),
    qargs...,
)

    # Initializing random generators
    rng_user_posts = MersenneTwister(seed - 1) # for user and posts generation
    rng_model = MersenneTwister(seed) # for other purposes


    posts = PostType[]

    n = start_posts
    ranking = [1:start_posts...]
    time = 0
    """
    # Presorting posts, if sorted != 0 DEACTIVATED
    user_ratings = []
    tmp_properties = @dict(user_opinion_function, time, quality_dimensions, relevance_gravity)
    tmp_model = ABM(UserType; properties = tmp_properties)
    scores = []
    for i = 1:start_posts
        push!(scores, scoring_best(posts[i], tmp_model.time, tmp_model))
    end
    s = -1
    if sorted < 0
        s = 1
    end
    tmp_ranking = sortperm(map(x -> s*x, scores))
    ranking = partial_shuffle(rng_model, tmp_ranking, 1 - abs(sorted))
    """

    # calculate the distribution of user opinion
    nn = 100
    p_qual = rand(rng_user_posts, quality_distribution, nn)
    u_qual = rand(rng_user_posts, quality_distribution, nn)
    rating_distribution = []
    for i in 1:length(p_qual[1,:])
        for j in 1:length(u_qual[1,:])
            push!(rating_distribution, user_opinion_function(p_qual[:,i],u_qual[:,j]))
        end
    end

    sort!(rating_distribution)


    model_id = rand(1:2147483647)

    properties = @dict(
        activity_distribution,
        agent_step!,
        concentration_distribution,
        deviation_function,
        gravity,
        init_score,
        model_id,
        model_step!,
        model_type,
        n,
        new_posts_per_step,
        new_users_per_step,
        posts,
        PostType,
        quality_dimensions,
        quality_distribution,
        ranking,
        rating_distribution,
        relevance_gravity,
        rng_model,
        rng_user_posts,
        rating_metric,
        seed,
        sorted,
        start_posts,
        start_users,
        steps,
        time,
        user,
        UserType,
        user_ratings,
        user_opinion_function,
        vote_evaluation,
        voting_probability_distribution,
    )

    for qarg in qargs
        properties[qarg[1]] = qarg[2]
    end

    # creation of the agent-based model
    model = ABM(UserType; properties = properties)


    # adding users
    if typeof(user) <: Array
        @assert sum(map(x -> x[1], user)) == 1 "user_creation percentages sum is not equal to 1!"
        for p in user
            for i = 1:p[1]*start_users
                p[2](model)
            end
        end
    else
        for i = 1:start_users
            user(model)
        end
    end

    return model
end


"""
    agent_step!(user, model)

Executes the agents/user actions for a model iteration in a upvote system
"""
function agent_step!(user, model)
    # check activity
    if rand(model.rng_user_posts) < user.activity_probability
        # check concentration
        for i = 1:minimum([user.concentration, model.n])
            post = model.posts[model.ranking[i]]
            # check if user rates the post
            if model.user_opinion_function(
                post.quality,
                user.quality_perception,
            ) > rating_quantile(model,1 - user.vote_probability) && !in(post, user.voted_on)
                push!(user.voted_on, post)
                post.votes += 1

                push!(
                    model.user_ratings,
                    model.user_opinion_function(
                        post.quality,
                        user.quality_perception,
                    ),
                )

            end

            # add view to posts views
            if !in(post, user.viewed)
                push!(user.viewed, post)
                post.views += 1
            end
        end
    end
end



"""
    model_step!(model)

Executes the rating metric, adds new posts und sorts the posts with their score
"""
function model_step!(model)
    # calculate scores
    for i = 1:model.n
        model.posts[i].score =
            model.rating_metric(model.posts[i], model.time, model)
    end

    # add new posts
    for i = 1:model.new_posts_per_step
        push!(
            model.posts,
            model.PostType(
                model.rng_user_posts,
                model.quality_distribution,
                model.time,
                model.init_score,
            ),
        )
        model.n += 1
    end

    # add new users
    for i = 1:model.new_users_per_step
        model.user()(model)
    end

    # calculate random deviaton for all posts
    random_deviation = model.deviation_function(model)

    for (index,post) in enumerate(model.posts)
        post.score += random_deviation[index]
    end

    # sort posts after score
    model.ranking = sortperm(map(x -> -x.score, model.posts))
    model.time += 1

end

"""
    partial_shuffle(rng, v::AbstractArray, percent)

shuffles `v` by ca. `percent` percent
"""
function partial_shuffle(rng, v::AbstractArray, percent)
    amount = round(Int, length(v) * percent)
    indeces = [1:length(v)...]
    ret = copy(v)
    rand_numbers = []
    for i = 1:amount
        new_rand_number = rand(rng, indeces)
        indeces = filter(x -> x != new_rand_number, indeces)
        push!(rand_numbers, new_rand_number)
    end

    for i = 1:2*length(rand_numbers)
        a = rand(rng, rand_numbers)
        b = rand(rng, rand_numbers)
        ret[a], ret[b] = ret[b], ret[a]
    end
    ret
end


"""
    relevance(post, model)

Returns the relevance of a post
"""
function relevance(post, model)
    sum(sigmoid.(post.quality))/(maximum([model.time-post.timestamp,1]))^(model.relevance_gravity)
end


"""
    scoring_best(post, time, model)

Returns the relevance of `post`, the best rating metric
"""
function scoring_best(post, time, model)
    relevance(post,model)
end


"""
    rating_quantile(model, quantile)

Returns the quantile value  of `quantile`  of the rating distribution
"""
function rating_quantile(model, quantile)
    model.rating_distribution[maximum([1,Int64(round(length(model.rating_distribution)*quantile))])]
end
