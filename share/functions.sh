#! /usr/bin/zsh -feu

# todo: enforce ZSH!
PROGRAM=$0
debug=n
# mmc: so this should EXIT afterwards!
trap 'print ${PROGRAM-$0} ERROR: $LINENO:  $ZSH_EVAL_CONTEXT $0 >&2' ZERR

cherry_pick_in_progress()
{
    test -d $(git rev-parse --git-common-dir)/sequencer
}

die()
{
    echo $@ >&2
    exit -1;
}

git_dir()
{
    ## --git-common-dir would be global to all worktrees.
    git rev-parse --git-dir
}

# todo: static variables!
# GIT_DIR=$(git_dir)


commit_id()
{
    #local sha=$(git rev-list  --max-count=1 $commit)
    git rev-parse $1
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

# full
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
            dump_symbolic_ref $summand
        done)
}


ref_exists(){
    test -e "$(git rev-parse --git-path $1)"
}

# expand by just 1 level:
dump_ref(){
    # echo "dump_ref $1" >&2

    # does not work:
    # x -> y &  y ->z & z->sha1; then `git symbolic-ref x' will return z.
    #git symbolic-ref $1


    # note: symbolic refs (i.e. those pointing at other refs ,not direct SHA1),
    # are not included in pack-refs.
    # fixme: does not work with packed_refs.
    # cat $GIT_DIR/$1

    # fully resolves:
    # git ref-parse $1

    # fixme: only symbolic: git symbolic-ref $1
    git rev-parse $1
}

# I bet on always knowing what to expect. for start & base.
# start is always/has to be (by design) non symbolic.
# base ... to be useful, should be symbolic.
# If not, it reduces the segment to a plain branch.
dump_symbolic_ref(){
    # fixme: this drops the "ref: " prefix!
    # previously with the "cat" it was part of the returned!

    # git symbolic-ref $1

    # fixme: this seems to do more than just 1 step!

    # $ cat .git/refs/base/sest
    # ref: refs/remotes/m/master
    # $ git symbolic-ref refs/base/sest
    # refs/remotes/tt-server/ics-dev
    #
    # hence returning:
    # note: http://permalink.gmane.org/gmane.comp.version-control.git/166818
    # http://stackoverflow.com/questions/4986000/whats-the-recommended-usage-of-a-git-symbolic-reference
    # todo: use 'read'
    local a
    a=$(cat $(git rev-parse --git-path $1))
    echo ${a#ref: }
}

dump_ref_without_ref()
{
    if true; then
        git rev-parse --symbolic-full-name $1
    else
        a=$(dump_symbolic_ref $1)
        echo $a
    fi
}

# is_nontrivial_sum
is_sum()
{
    local sum=$1
    local summands="$(summands_of $sum)"
    test -n "$summands"
}

is_segment()
{
    git show-ref refs/base/$1 >/dev/null;
}

drop_segment()
{
    victim=$1
    drop_symbolic_ref refs/base/$victim
    # drop_symbolic_ref ??
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
    dump_symbolic_ref refs/base/$1
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

# fixme:
# reverse of:
# symbolic-ref
set_symbolic_reference()
{
    local name=$1
    local content=$2

    # if expr match $content "^ref:" >/dev/null ; then
    git symbolic-ref $name ${content#ref: }
    #else
    #    git update-ref $name $content
    #fi
}

drop_symbolic_ref()
{
    ref=$1
    # fixme:
    git update-ref --no-deref -d $ref
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
                    echo "\"${${$(dump_symbolic_ref $summand)#refs/heads/}//-/_}\""
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
    local master
    master=/usr/share/git-hierarchy/git-rebase-abort
    if [ ! -e ${HOOK::=$GIT_DIR/hooks/rebase-abort} ]; then
        ln -fs $master $HOOK
    elif [ -L $HOOK -a  "$(readlink $HOOK)" = $master ]; then
        cecho "yellow" "skipping recreating the necessary hook, it's there"
    else
        # even if the same symlink. we want to remove it... don't we?
        cecho red "CRITICAL: $HOOK exists, but we must run ... $master" >&2
        # for now we check this too late, so no need for exit:
        # exit
    fi

    master=/usr/share/git-hierarchy/git-rebase-complete
    if [ ! -e ${HOOK::=$GIT_DIR/hooks/post-rebase} ]; then
        # fixme: this should be renamed: git-complete-segment-rebase
        ln -fs $master $HOOK
    elif [ -L $HOOK -a  "$(readlink $HOOK)" = $master ]; then
        cecho "yellow" "skipping recreating the necessary hook, it's there"
    else
        # note: this is a problem! see ~10 lines above!
        cecho red "CRITICAL: $HOOK exists, but we must run ... $master" >&2
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
    readonly name=$1
    local result
    local my_priority=n
    if [ $# -gt 1 ]; then
       my_priority=$2
    fi
    case $name in
        refs/*)
            result=$name
            ;;
        heads/*)
            result=refs/$name
            ;;
        remotes/*)
            result=refs/$name
            ;;
        tags/*)
            result=refs/$name
            ;;
        *)
            if [ ! $my_priority = n ]; then
                result=$(try_to_expand $name)
            else
                # this can fail, if does not exist.
                # then what? mmc: oh it's in a subshell, so?
                result=$(git rev-parse --symbolic-full-name heads/$name 2>/dev/null)
                if [[ $? != 0 ]]; then
                   exit -1
                fi
            fi
            # name=refs/heads/$name
            # prepend refs/
    esac

    # mmc: this should abort!
    echo $result
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

#ERR
# DEBUG
# trap 'report_error $LINENO $BASH_SOURCE' ERR
set_branch_to()
{
    local branch=$1
    local commit_id=$2

    if [ $branch = $(current_branch_poset) ]
    then
        git reset --hard $commit_id
    else
        git branch -f $branch $commit_id
    fi
}


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

# use $debug
# set roots and tops.
find_roots_and_tops()
{
    readonly GRAPH=$1

    # Covered are those who are ancestors of others!
    # but it's not A base B. it must be verified that B is indeed below it! If B has moved, I want to see it!
    readonly VERTICES=$(tempfile)
    readonly ANCESTORS=$(tempfile)

    cat $GRAPH | cut --fields=1 | sort -u > $VERTICES
    cat $GRAPH | cut -d '	' --fields 2- | sed -e "s/ /\n/g"| sort -u > $ANCESTORS
    # 3 common, 2 unique to ancestors = base.
    [ $verbose = "y" ] && { cecho red -n "the maximal bases/summands (ancestors) are "; comm -23  $VERTICES $ANCESTORS }

    # vertices ... roots^1 =  ^root^@ vertices
    # comm -1 -3 /tmp/fileFDORjK /tmp/fileOgzwpK

    roots=( $(comm -1 -3 $VERTICES $ANCESTORS) ) #unique to ancestors.
    tops=( $(comm -2 -3 $VERTICES $ANCESTORS) ) #unique to ancestors.
    rm -f $VERTICES $ANCESTORS
}

# fixme: protect this:
GIT_STASHED=no
## possibly stash:
# sets the variable STASHED
stash_if_non_clean()
{
    # fixme: some variable is used-before-defined, in upstream code.
    # this is run after processing the command line args. Otherwise -h would be
    # handled by it
    set +u
    . /usr/lib/git-core/git-sh-setup
    # git rev-parse --is-inside-work-tree
    GIT_DIR=$(git_dir)
    set -u

    # todo:
    # octopus can leave half work, so yes, I prefer:
    if ! ( require_clean_work_tree $1 "$(gettext "Please commit or stash them.")" )
    then
        local cmd=""
        # todo: orange:
        cecho yellow "stashing for you..."
        eval $cmd git stash save $1
        GIT_STASHED=yes
    fi
}


unstash_if_stashed()
{
    if [ "$GIT_STASHED" = "yes" ]
    then
        cecho yellow "unstashing now."
        # eval $cmd
        git stash pop --quiet
    fi
}

git_segment_mark=".segment-cherry-pick"
git_poset_mark=".poset-rebased"
#$GIT_DIR/.rebasing-segment
mark_rebase_segment()
{
    echo "$1" >! $GIT_DIR/$git_segment_mark
    # the old version:
    # echo "$1" > $GIT_DIR/.rebasing-segment
}

# $1
unmark_rebase_segment()
{
    if [ -e $GIT_DIR/$git_segment_mark ]; then
        if [ "$1" = "$(cat $GIT_DIR/$git_segment_mark)" ]; then
            echo "### so rebase was completed, moving *start* to the *base*"  >&2
            rm -v $GIT_DIR/$git_segment_mark
        else
            echo "### mismatch!"  >&2
        fi
    fi
}

#
marked_segment()
{
    cat $GIT_DIR/.segment-cherry-pick
}


mark_rebase_poset()
{
    echo "$@" > $GIT_DIR/$git_poset_mark
}

function INFO()
{
    cecho yellow "$@"
}

function STEP()
{
    cecho blue "$@"
}

function WARN()
{
    cecho red "$@"
}


# 1 key/value pair per line.
dump_associative_array()
{
    local map=$1
    local key
    local val

    for key val in ${(kv)${(P)map}}; do
        echo "$key $val"
    done
}
