#! /usr/bin/zsh -feu


git_dir()
{
    echo $(git rev-parse --show-toplevel)/.git
}


git-branch-exists()
{
    git show-ref refs/heads/$1 >/dev/null;
}

list_sums()
{
    git for-each-ref 'refs/sums/' --format "%(refname)" |\
        sed -e 's|^refs/sums/\([^/]*\)/[^/]*$|\1|' | sort -u
}

is_sum()
{
    [ -e $SUM_DIR/$1 ]
}

is_segment()
{
    git show-ref refs/base/$1 >/dev/null;
}

segment_base()
{
    cat $GIT_DIR/refs/base/$1 | sed -e 's^ref: refs/\(heads\|remotes\)/^^'
}

# segment_base()
# {
#     cat $1 | sed -e 's^ref: refs/\(heads\|remotes\)/^^'
# }



