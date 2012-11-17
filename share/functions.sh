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

summands_of()
{
    # the sum is just the name!
    sum=$1
    # print
    git for-each-ref "refs/sums/$sum/" --format "%(refname)"|\
    ( while read summand; do
	    dump_ref $summand |sed -e 's/^ref:\s//';
	    done)
}

# expand by just 1 level:
dump_ref(){
    # git symbolic-ref $ref
    cat $GIT_DIR/$1
}


# is_nontrivial_sum
is_sum()
{
    sum=$1
    summands=$(summands_of $sum)
    [ -n $summands ]
}

is_segment()
{
    git show-ref refs/base/$1 >/dev/null;
}

segment_base()
{
    # fixme:  dump_ref $1 ... so full ref is needed!
    dump_ref /refs/base/$1 | sed -e 's^ref:\srefs/\(heads\|remotes\)/^^'
}

