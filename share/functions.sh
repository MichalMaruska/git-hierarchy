#! /usr/bin/zsh -feu

# todo: enforce ZSH!

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
    local sum=$1
    local summand
    # print
    git for-each-ref "refs/sums/$sum/" --format "%(refname)"|\
    ( while read summand;
	do
	# echo $summand >&2
	dump_ref $summand |sed -e 's/^ref:\s//';
	done)
}

# expand by just 1 level:
dump_ref(){
    # does not work:
    # x -> y &  y ->z & z->sha1; then `git symbolic-ref x' will return z.
    #git symbolic-ref $1

    # note: symbolic refs (i.e. those pointing at other refs ,not direct SHA1), are not included in pack-refs.
    # when that changes, I have to update this tool
    cat $GIT_DIR/$1
}


# is_nontrivial_sum
is_sum()
{
    local sum=$1
    local summands="$(summands_of $sum)"
    [ -n "$summands" ]
}

is_segment()
{
    git show-ref refs/base/$1 >/dev/null;
}

segment_base()
{
    # fixme:  dump_ref $1 ... so full ref is needed!
    # refs/\(heads\|remotes\)
    dump_ref /refs/base/$1 | sed -e 's/ref:\s//'
}


set_symbolic_reference()
{
    local name=$1
    local content=$2

    if expr match $content "^ref:" >/dev/null ; then
	git symbolic-ref $name ${content#ref: }
    else
	git update-ref $name $content
    fi
}

drop_symbolic_ref()
{
    ref=$1
    # fixme:
    git update-ref -d $ref --no-deref
    # ${$(dump_ref $ref)#ref: }
    # With this it was recreating .git/refs/heads/refs/sums/all/10
}

