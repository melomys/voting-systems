"""
    consensus(post_quality, user_quality_perception)

Returns the opinion value in consensus of a post with post quality `post_quality` and a user with the quality perception `quality_perception`
"""
function consensus(post_quality, user_quality_perception)
    sum(sigmoid.(post_quality).^(sigmoid.(user_quality_perception)))/length(post_quality)

end

"""
    dissent(post_quality, user_quality_perception)

Returns the opinion value in dissent of a post with post quality `post_quality` and a user with the quality perception `quality_perception`
"""
function dissent(post_quality, user_quality_perception)
    1 - sqrt(sum((sigmoid.(post_quality) - sigmoid.(user_quality_perception)).^ 2))/sqrt(length(post_quality))
end
