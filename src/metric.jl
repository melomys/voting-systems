using Dates
"""
    metric_hacker_news(post, time, model)

Returns postscore calculated after the hacker news metric
"""
function metric_hacker_news(post, time, model)
    v = model.vote_evaluation(post) - 1
    if model.vote_evaluation !== vote_difference
        v = model.vote_evaluation(post)
    end
    v / (time - post.timestamp + 2)^model.gravity
end

epoch = DateTime(1970,1,1)
start_time = DateTime(2020,06,20)


"""
    metric_reddit_hot(post, time, model)

Returns postscore calculated after the reddit hot metric
"""
function metric_reddit_hot(post, time, model)
    seconds = Dates.value(start_time - epoch)/1000 - 1134028003 + post.timestamp * 60 * 30 # 60 Sekunden pro 30 Minuten!!
    order = log(10, max(abs(model.vote_evaluation(post
    )),1))
    round(sign(post.votes - post.downvotes)*order + seconds/45000; digits=7)
end


"""
    metric_activation(post, time, model)

Returns postscore calculated after the activation metric
"""
function metric_activation(post, time,model)
    (model.vote_evaluation(post) - post.score) / (time -post.timestamp + 2)^(model.gravity)
end

"""
    metric_view(post, time, model)

Returns postscore calculated after the view metric
"""
function metric_view(post, time, model)
    ((model.vote_evaluation(post) - 1) / (post.views + 1)) /
    (time - post.timestamp + 2)^model.gravity
end


# vote evaluation


"""
    vote_difference(post)

Returns the differnce of upvotes -  downvotes
"""
function vote_difference(post)
    return post.votes - post.downvotes
end

"""
    vote_partition(post)

Returns the partition of upvotes to total votes
"""
function vote_partition(post)
    if post.votes + post.downvotes == 0
        return 0
    end
    return post.votes/(post.votes + post.downvotes)
end

"""
    vote_wilson(post)

Returns the lower bound of the wilson confidence interval of the binomial distribution
"""
function vote_wilson(post)
    confidence = 0.95
    n = post.votes + post.downvotes
    if n == 0
        return 0
    end
    z = Statistics.quantile(Normal(), 1-(1-confidence)/2)
    phat = 1.0*post.votes/n
    (phat + z*z/(2*n) - z * sqrt(phat*(1- phat) + z*z/(4*n)/n)) / (1 + (z*z)/n)
end
