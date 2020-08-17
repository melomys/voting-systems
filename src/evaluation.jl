# Per iteration

"""
    dcg(model)

Return the DCG of the rating metric
"""
function dcg(model)
    ord = zscore(map(post -> relevance(post, model), model.posts))
    dcg = 0
    for i = 1:model.n
        dcg += (2^(ord[model.ranking[i]]) - 1) / log2( i + 1)
    end
    dcg
end

"""
    rdcg(model)

Return the nDCG of the rating metric
"""
function ndcg(model)
    ord = zscore(map(post -> relevance(post,model), model.posts))
    by_quality = sortperm(ord, by= x -> -x)
    bdcg = 0
    for i = 1:model.n
        bdcg += (2^(ord[by_quality[i]]) - 1) / log2( i + 1)
    end
    dcg(model)/bdcg
end

"""
    spearman(model)

Return the spearman rho of the rating metric
"""
function spearman(model)
    ord = (map(post -> relevance(post, model), model.posts))

    by_quality = sortperm(ord, by= x -> -x)
    cor(model.ranking, by_quality)
end

"""
    gini(model)

Returns the gini-coefficient of the rating metric, calculated by the views of the posts
"""
function gini(model)

    posts = model.posts

    s = 0
    cutoff = 70
    if length(model.posts) > 2 * cutoff
        posts = [model.posts[1:cutoff]...,model.posts[length(model.posts) - cutoff + 1:end]...]
    end
    n = sum(map(post -> post.views, posts))
    if n == 0
        return 0.0
    end
    for p1 in posts
        for p2 in posts
            s = s + abs(p1.views - p2.views)
        end
    end
    s/(2*n*(length(posts)-1))

end

"""
    @top_k_gini(k)

Returns a function with the name top_<`k`>_gini, that calculates the gini-coefficient of the `k` best quality posts in the model
"""
macro top_k_gini(k)
    name = Symbol("gini_top_",eval(k))
    return :(function $name(model)
        by_quality = sortperm(model.posts, by=x -> - relevance(x,model))
        posts = model.posts[by_quality[1:minimum([$k,length(model.posts)])]]
        s = 0
        n = sum(map(post -> post.views, posts))
        if n == 0
            return 0.0
        end
        for p1 in posts
            for p2 in posts
                s = s + abs(p1.views - p2.views)
            end
        end
        s/(2*n*(length(posts)-1))
    end)
end

# Model evaluation

"""
    @area_under(parameter)

Returns a function with the signature area_under_<`parameter`>(model, model_df),
that aggregates the given parmeter with the trapezoidial rule
"""
macro area_under(parameter)
    name = Symbol("area_under_", eval(parameter))
    return :(function $name(model,model_df)
            return trapezoidial_rule(model_df[!, $parameter])/model.steps
        end)
end

"""
    posts_with_no_views(model, model_df)

Returns the percentage of posts with no views in the model
"""
function posts_with_no_views(model, model_df)
    no_views = filter(x -> x.views == 0, model.posts)
    return length(no_views)/length(model.posts)
end

"""
    quality_sum(model, model_df)

Return the sum of all postquality in the model
"""
quality_sum(model, model_df) = sum(map(
    x -> model.user_opinion_function(x.quality, ones(model.quality_dimensions)),
    model.posts,
))

"""
    @model_df_column(col)

Macro to create a function with the name `col`, to select evaluate a column of the iteration evaluation dataframe
"""
macro model_df_column(col)
    name = Symbol(eval(col), "_all")
    return :(function $name(model, model_df)
    model_df[!,$col]
    end)
end

"""
    post_views(model, model_df)

Returns the sum of all views of all posts
"""
function post_views(model, model_df)
    views = map(x -> x.views, model.posts)
    return views
end

"""
    vote_count(model, model_df)

Returns the sum of all upvotes of all posts
"""
vote_count(model, model_df) = sum(map(x -> x.votes, model.posts))


# Helpers

"""
    trapezoidial_rule(points)

Returns the size under the area of the points calculated witth the trapezoidial rule
"""
function trapezoidial_rule(points)
    sum(points) - 1 / 2 * (points[1] + points[end])
end


"""
    sigmoid(x [a=1,b=1,c=0]

logistic sigmoid function
"""
sigmoid(x; a = 1, b = 1, c = 0) = a/(1+ℯ^(-x*0.5*b)) - c


"""
    zscore(data)

Returns zscored data
"""
function zscore(data)
    μ = mean(data)
    σ = std(data)
    map(x -> (x - μ)/σ, data)
end
