#! /usr/bin/zsh -feu

# todo: enforce ZSH!

die()
{
    echo $@ >&2
    exit -1;
}


git_dir()
{
    git rev-parse --git-dir
    # echo $(git rev-parse --show-toplevel)/.git
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
	dump_ref $summand |sed -e 's/^ref:\s\+//';
	done)
}


ref_exists(){
    test -e $GIT_DIR/$1
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

dump_ref_without_ref()
{
    if true; then
	git rev-parse --symbolic-full-name $1
    else
	a=$(dump_ref $1)
	a=${a#ref:}
	a=${a# }
	a=${a#	}
	echo $a
    fi
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

drop_segment()
{
    victim=$1
    drop_symbolic_ref refs/base/$victim
    git update-ref -d refs/start/$victim

    #rm -f $GIT_DIR/$baseref || true
    #rm -f $GIT_DIR/$startref || true
    #git update-ref -d $startref || true
    #git update-ref -d $baseref || true
}

delete_sum_definition()
{
    # delete all of them:
    local name=$1
    git for-each-ref "refs/sums/$name/" --format "%(refname)" |\
    (while read ref;
	do
	drop_symbolic_ref $ref
	done
    )
}

segment_base()
{
    # fixme:  dump_ref $1 ... so full ref is needed!
    # refs/\(heads\|remotes\)
    dump_ref refs/base/$1 | sed -e 's/ref:\s//'
}

segment_start()
{
    # git rev-list  --max-count=1 start/${segment_name}
    dump_ref refs/start/$1
}

# return the distance between start & base
segment_age()
{
    local segment=$1
    git rev-list --count --left-right \
	start/${segment}..base/${segment}| cut -f 2
}

segment_length()
{
    local name=$1
    local startref=refs/start/$name
    git log --oneline $startref..heads/$name|wc --lines
}

# name commit
git-set-start()
{
    local segment=$1
    local start="refs/start/$segment"
# set the reference to the SHA of the Commit.
# sort of git-tag, but...

    local commit=$2
    local sha=$(git rev-list  --max-count=1 $commit)

    git update-ref $start $sha
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

dump_format=tsort
# needed:  dump_format, extern_color
dump_segment()
{
    local segment=$1

    # mmc: why not output the full base ref?
    local segment_name=${segment#refs/base/}
    case $dump_format in
	dot)
	    # for dot(1) we have to follow some restrictions on symbols:
	    #  - has a special meaning.
	    #  and we simplify the names ... as they are directly visible:
	    #  todo: should be done elsewhere

	    local dot_name=${segment_name//-/_}
	    # todo:  #
	    local slash="/"
	    local base_name=${$(segment_base $segment_name)#refs/heads/}
            local dot_base_name=${${${base_name#refs/remotes/}//-/_}//$slash/_}
	    # remotes/debian/master ->  debian_master.

	    # the `incidence':
	    echo "\"$dot_name\" -> \"$dot_base_name\""

	    # now the label for the vertex:
	    local length=$(segment_length $segment_name)
	    # if needs rebase:
	    local age=$(segment_age $segment_name)
	    local color
	    if [ $age = 0 ];then
		color=yellow
	    else
		color=orange
	    fi

	    # show the vertex
	    cat <<EOF
"$dot_name" [label="$segment_name $length\n$age",color=$color,fontsize=14,
	    fontname="Palatino-Italic",fontcolor=black,style=filled];
EOF
        # if the base is `external', dump it:
        # (unfortunately this means multiple times)
        if ! git-segment $base_name &>/dev/null &&
	    ! git-sum $base_name &>/dev/null; then
	    cat <<EOF
	    $dot_base_name [label="$base_name",color=$extern_color,fontsize=14,
		fontname="Palatino-Italic",fontcolor=black,style=filled];
EOF
	fi
	    ;;
	tsort)
	    echo -n "refs/heads/$segment_name\t"; segment_base $segment_name
	    ;;
	raw)
	    # dump the start  segment_start_sha
	    echo segment $segment_name "\t"  $(dump_ref refs/heads/$segment_name) \
		 "\t" $(segment_base $segment_name) \
		 "\t" $(segment_start $segment_name)
	    ;;
	*)
    esac
}


dump_sum()
{
    local sum=$1
    local summand

    case $dump_format in
	raw)
	    echo "sum\t$sum\t$(dump_ref refs/heads/$sum)";
	    ;;
	*)
    esac

    # dump the summands:
    git for-each-ref "refs/sums/$sum/" --format "%(refname)" |\
	{
	while read summand
	do
	    case $dump_format in
		dot)
		    echo -n "\"${sum//-/_}\"" "->"
		    echo "\"${${$(dump_ref $summand |sed -e 's/^ref:\s//')#refs/heads/}//-/_}\""
		    ;;
		tsort)
		    echo -n "refs/heads/$sum\t"; dump_ref_without_ref $summand
		    ;;
		raw)
		    echo -n "\t"; dump_ref_without_ref $summand
		    ;;
		*)
	    esac
	done }

    if [ $dump_format = dot ]; then
        cat <<EOF
"${sum//-/_}" [label="$sum",color=red,fontsize=14,
	      fontname="Palatino-Italic",fontcolor=black,style=filled];
EOF
    fi
}


# Create symlinks to the system copies.
check_git_rebase_hooks()
{
    local HOOK
    if [ ! -d $GIT_DIR/hooks ]; then
	mkdir $GIT_DIR/hooks
    fi

    if [ ! -e ${HOOK::=$GIT_DIR/hooks/rebase-abort} ]; then
	ln -s /usr/share/git-hierarchy/git-rebase-abort $HOOK
    else
	# even if the same symlink. we want to remove it... don't we?
	cecho red "CRITICAL: $HOOK exists, but we must run ... /usr/share/git-hierarchy/git-rebase-abort" >&2
	# for now we check this too late, so no need for exit:
	# exit
    fi

    if [ ! -e ${HOOK::=$GIT_DIR/hooks/post-rebase} ]; then
	# fixme: this should be renamed: git-complete-segment-rebase
	ln -s /usr/share/git-hierarchy/git-rebase-complete $HOOK
    else
	# note: this is a problem! see ~10 lines above!
	cecho red "CRITICAL: $HOOK exists, but we must run ... /usr/share/git-hierarchy/git-rebase-complete" >&2
	# cecho red "cannot proceed: $HOOK exists" >&2
	# exit
    fi
}

## This is about S.Ref `resolution':
# turning the input from user into fully-qualified S.Ref name.
# compare with "git rev-parse"

try_to_expand()
{
    local name=$1
    # echo "try_to_expand $name" >&2
    # Here the priority
    local expanded=$(
	{git show-ref heads/$name || \
	git show-ref remotes/$name || \
	git show-ref $name } |\
	    head -n 1|cut -f 2 '-d ')
    # echo "expanded $expanded" >&2
    echo $expanded
}

expand_ref()
{
    local name=$1
    local my_priority=n
    if [ $# -gt 1 ]; then
       my_priority=$2
    fi
    case $name in
	refs/*)
	    ;;
	heads/*)
	    name=refs/$name
	    ;;
	remotes/*)
	    name=refs/$name
	    ;;
	tags/*)
	    name=refs/$name
	    ;;
	*)
	    if [ ! $my_priority = n ]; then
		name=$(try_to_expand $name)
	    else
		name=$(git rev-parse --symbolic-full-name heads/$name)
	    fi
	    # name=refs/heads/$name
	    # prepend refs/
    esac

    echo $name
}


# remove a file $1, but only if it's a symlink to $2
remove_symlink_to()
{
    # canonicalize $2
    if [ -L $1 -a "$(readlink $1)" = $2 ]
    then
	rm -fv $1
    fi
}


report_error()
{
    echo "$0 ERROR: $@"
    exit -1
}

PROGRAM=$0
trap 'print ${PROGRAM-$0} ERROR: $LINENO:  $ZSH_EVAL_CONTEXT $0' ZERR
#ERR
# DEBUG
# trap 'report_error $LINENO $BASH_SOURCE' ERR


current_branch_poset()
{
    local head
    head=$(dump_ref_without_ref HEAD)
    head=${head##refs/heads/}
    if [ $head = HEAD ]; then
	cecho red "currently not on a poset branch" >&2
	exit 1;
    fi

    echo "$head"
}

# writes to stdout 2 kinds (all for tsort input format!):
#  segment: base
#  sum: summand1 summand2 ...
#
# input: $debug, dump_format (see dump_segment()!)
dump_whole_graph()
{

    local segments
    typeset -a segments
    # this list_segments is also in `git-segment'
    segments=($(git for-each-ref 'refs/base/' --format "%(refname)"))
    if [ 0 =  ${#segments} ]; then
	echo "no segments." >&2
    else
	foreach segment ($segments);
	{
	    dump_segment $segment
	}
    fi


    local sums
    typeset -a sums
    sums=($(list_sums))

    if [ 0 = ${#sums} ]; then
	test $debug = y && echo "no sums." >&2
    else
	foreach sum ($sums)
	{
	    dump_sum $sum
	}
    fi
}
