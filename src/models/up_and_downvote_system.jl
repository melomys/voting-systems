"""
    up_and_downvote_system(;[...])

Creates a up and downvote system, agent-based model, and intializes all necessary parameters.
The up and downvote system allows users to upvote and downvote posts, it uses a different agent_step! function,
but takes all parameters from the upvote system
"""
function up_and_downvote_system(;
    user_opinion_function = consensus,
    agent_step! = downvote_agent_step!,
    qargs...,
)
    upvote_system(;
        user_opinion_function = user_opinion_function,
        agent_step! = agent_step!,
        model_type = up_and_downvote_system,
        qargs...,
    )
end

vals = []



"""
    downvote_agent_step!(user, model)

Executes the agents/user actions for a model iteration in a up and downvote system
"""
function downvote_agent_step!(user, model)
    if rand(model.rng_user_posts) < user.activity_probability
        for i = 1:minimum([user.concentration, model.n])
            post = model.posts[model.ranking[i]]
            if !in(post, user.voted_on)
                if model.user_opinion_function(
                    post.quality,
                    user.quality_perception,
                ) < rating_quantile(model, user.vote_probability / 2)
                    post.downvotes += 1
                    push!(user.voted_on, post)
                elseif model.user_opinion_function(
                    post.quality,
                    user.quality_perception,
                ) > rating_quantile(model, 1 - user.vote_probability / 2)
                    post.votes += 1
                    push!(user.voted_on, post)
                end

                push!(
                    model.user_ratings,
                    model.user_opinion_function(
                        post.quality,
                        user.quality_perception,
                    ),
                )
                if !in(post, user.viewed)
                    push!(user.viewed, post)
                    post.views += 1
                end

            end
        end
    end
end
