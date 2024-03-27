#! /usr/bin/zsh -feu

# todo: enforce ZSH!
readonly PROGRAM=$ZSH_ARGZERO
debug=n
source /usr/share/mmc-shell/git-functions.sh
source /usr/share/mmc-shell/mmc-functions.sh
colors

# apps can add into here!
typeset -a known_divergent
known_divergent=()
global_test_off=n

typeset -a MOVED_SINCE
typeset -a GREATER_SINCE

# obsolete:
# report_error()
# {
#     echo "report_error $0 ERROR: $@"
#     exit -1
# }

#ERR
# DEBUG
# trap 'report_error $LINENO $BASH_SOURCE' ERR

# mmc: so this should EXIT afterwards!
trap 'print ${PROGRAM-$0} Error: $LINENO:  $ZSH_EVAL_CONTEXT $0 >&2; dump_stack; exit 1' ZERR

DEBUG()
{
    if [[ $debug = y ]]; then
        cecho blue "$@" >&2
    fi
}

debug_trace()
{
    if [[ $debug = y ]]; then
        cecho green $@ >&2
    fi
}

CRITICAL()
{
    cecho red $@ >&2
}

function INFO()
{
    cecho blue "$@"
}

# function INFO()
# {
#     cecho yellow "$@"
# }

function STEP()
{
    if [[ $debug = y ]]; then
        cecho blue "$@" >&2
    fi
}

function WARN()
{
    cecho red "$@" >&2
}
function ERROR()
{
    cecho blue "$@" >&2
}




cherry_pick_in_progress()
{
    test -d $(git rev-parse --git-common-dir)/sequencer
}

# todo: static variables!
# GIT_DIR=$(git_dir)


commit_id()
{
    #local sha=$(git rev-list  --max-count=1 $commit)
    git rev-parse $1
}

list_sums()
{
    git for-each-ref 'refs/sums/' --format "%(refname)" --sort refname |\
        sed -e 's|^refs/sums/\([^/]*\)/[[:digit:]]*$|\1|' | sort -u
    # so uniq could be enough?
}

# output full references (to stdout)
summands_of()
{
    # the sum is just the name!
    local sum=$1
    local summand
    # print
    git for-each-ref "refs/sums/$sum/" --format "%(refname)"|\
        ( while read summand;
          do
              dump_ref_without_ref $summand
              echo
          done)
}

# in: $1 the name
# out: array `real_branches' is filled.
sum_resolve_summands()
{
    #### Calculate the summands: for the check and for re-merging.
    # local
    local sum_name=$1
    local result_array=$2

    typeset -a _summand_branches
    # this is `definition'
    _summand_branches=(
        $(git for-each-ref "refs/sums/$sum_name/" --format "%(refname)") )
    #(${(f)_tmp})
    #test $debug = y &&     echo $_summand_branches

    # Those references are symbolic "ref: ref/head/NAME", but we want to
    # use the NAMES in the commit message & interaction with the user.
    # So, `resolve' them:
    typeset -l -a _real_branches=()

    local br
    foreach br ($_summand_branches) {
        _real_branches+=$(dump_ref_without_ref $br)
    }

    set -A $result_array $_real_branches
}


ref_exists(){
    test -e "$(git rev-parse --git-path $1)"
}

ref_extract_name(){
    local ref=$1
    name=${ref#refs/}
    echo ${name#heads/}
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
    git rev-parse $1 | tr -d '\n'
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
    echo $a
}

dump_ref_without_ref()
{
    setopt pipefail
    if true; then
        # fixme: no newline!
        git rev-parse --symbolic-full-name $1 -- | tr -d '\n'
    else
        a=$(dump_symbolic_ref $1)
        echo ${a#ref: }
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

segment_base_name()
{
    echo "refs/base/$1"
}

segment_base()
{
    # fixme:  dump_ref $1 ... so full ref is needed!
    # refs/\(heads\|remotes\)
    dump_ref_without_ref refs/base/$1
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

# needed: extern_color
dump_segment()
{
    readonly dump_format=$1
    readonly segment_name=$2

    case $dump_format in
        name)
            echo "$segment_name"
            return
            ;;
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
            echo "\"$dot_name\" -> \"$dot_base_name\" [tailtooltip=\"tail\", edgetooltip=\"Edge\", edgelabel=\"E\" ]"

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

            # todo: dump the description
            if ! description=$(git config branch.${segment_name}.description)
            then
                description="segment"
            fi
            cat <<EOF
"$dot_name" [label="$segment_name $length\n$age",color=$color,fontsize=14,URL="gitk://heads/$segment_name",tooltip="$description",
            fontname="Palatino-Italic",fontcolor=black,style=filled];
EOF
# tooltip of the edge? headtooltip, edgetooltip, tailtooltip

        # if the base is `external', dump it:
        # (unfortunately this means multiple times)

        # fixme: what if it's tag:
        if ! git-segment $base_name &>/dev/null &&
            ! git-sum $base_name &>/dev/null; then
            cat <<EOF
            "$dot_base_name" [label="$base_name",color=$extern_color,fontsize=14,
                fontname="Palatino-Italic",fontcolor=black,style=filled];
EOF
        fi
            ;;
        tsort)
            # mmc: so full refs here!
            echo -n "refs/heads/$segment_name\t"; segment_base $segment_name; echo
            ;;
        symbolic)
            local base=$(segment_base $segment_name)
            echo "segment $segment_name\t${base#refs/}"
            ;;
        resolved)
            echo segment $segment_name "\t" $(git rev-parse $segment_name) \
                 "\t" $(segment_base $segment_name) \
                 "\t" $(git rev-parse $(segment_start $segment_name))
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
    local test=n
    if [[ $1 = "--test" ]]; then
        shift
        test=y
    fi

    if [[ $global_test_off = y ]]; then
        DEBUG "tests is off!"
        test=n
    fi

    readonly dump_format=$1
    readonly sum=$2

    case $dump_format in
        raw)
            echo "sum\t$sum\t$(dump_ref refs/heads/$sum)";
            ;;
        symbolic)
            # this is used by git-hierarchy
            # echo "sum $fg[red]$sum$reset_color"
            echo "sum $sum"
            ;;
        name)
            echo "$sum"
            return
            ;;
        # dot does not need anything?
        resolved)
            #
            echo -n "sum\t$sum\t$(dump_ref refs/heads/$sum)";
            ;;
        *)
    esac

    # dump the summands:
    typeset -a real_branches
    sum_resolve_summands $sum real_branches

    local up_to_date=y
    if [[ ${known_divergent[(i)${(q)sum}]} -gt ${#known_divergent} ]]
    then
        equal=n
        test_commit_parents heads/$sum $real_branches[@] >/dev/null
        if [[ "$equal" = n ]]
        then
            if [[ $test == n ]]; then
                up_to_date=n
            else
                echo $reason >&2
                echo "sum $sum is not the merge of other branches! i.e." >&2
                foreach summand ( $real_branches[@] ) {
                    print "\t${summand#refs/heads/}" >&2
                }
                exit -2
            fi
        fi
    else
        up_to_date="dontknow"
    fi

    # git for-each-ref "refs/sums/$sum/" --format "%(refname)"
    # summands_of $sum |\
    foreach summand ( $real_branches[@] )
    {
        case $dump_format in
            dot)
                color=red
                arrowsize=1
                if [[ ${MOVED_SINCE[(i)$summand]} -le ${#MOVED_SINCE} ]]; then
                    color=blue
                    arrowsize=2
                elif [[ ${GREATER_SINCE[(i)$summand]} -le ${#GREATER_SINCE} ]]; then
                    color=yellow
                    arrowsize=3
                fi
                # mmc: why -n?
                echo  "\"${sum//-/_}\"" "->" "\"${${summand#refs/heads/}//-/_}\" [color=$color, arrowsize=$arrowsize];"
                ;;
            tsort)
                echo "refs/heads/$sum\t$summand"
                ;;
            symbolic)
                # mmc: why?
                # "\t${${$(dump_ref_without_ref $summand)#refs/heads/}//-/_}"
                echo "\t${summand#refs/heads/}"
                ;;
            raw| resolved)
                # the first one is not necessary:
                echo -n "\t" $summand
                ;;
            *)
        esac
    }

    # close:
    case $dump_format in
        dot)
            local color=green
            if [[ $up_to_date = n ]]; then
                color="red"
            elif [[ $up_to_date = dontknow ]]; then
                color="blue"
            elif [[ $equal = old ]]; then
                color="olive"
            fi
            cat <<EOF
"${sum//-/_}" [label="$sum",color=$color,fontsize=14,URL="gitk://$sum",
              fontname="Palatino-Italic",fontcolor=black,style=filled];
EOF
            ;;
        symbolic | tsort |raw | resolved)
            echo
            ;;
        *)
    esac
}

dump_array()
{
    local prefix=$1
    shift
    local element
    foreach element ($@) {
        print "$prefix$element"
    }
}

######################################## Test if up-to-date
test_commit_parents()
# options:  --strict to exit when any deviation noticed!

# input: sum_branch summand_branches...
#
# $debug variable!
#
# output
# `returns' the $equal variable is set.
# $reason

# beware: this outputs to stdout
{
    local strict=n
    if [[ $1 = "--strict" ]]; then
        strict=y
        shift
    fi
    local sum_branch=$1
    shift
    summand_branches=($@)  # this is supposedly taken from the definition.

    MOVED_SINCE=()
    GREATER_SINCE=()
    # Take the commit-ids of the summands: (definition)
    # And parent-ids of the sum's head.    (situation)
    # sort & compare
    local -A summands_commit_ids

    local br
    DEBUG "Summands:"
    foreach br ($summand_branches) {
        local commit=$(commit_id $br)
        summands_commit_ids[$br]=$commit
        # summands_commit_ids+=("$br"=$commit)

        DEBUG "\t$br\t$commit"
    }

    # fixme: maybe the sum is NOT a merge. Then either it's one of the summands -- no need to look at parents!
    # But, if the merge is itself one of summands -> should be ok!

    # Parents: situation around the sum:
    typeset -la parents_commit_ids
    parents_commit_ids=($(git show -s --format=format:"%P" $sum_branch))

    test $debug = y && {
        echo "Parents:"
        foreach commit ($parents_commit_ids) {
            echo "\t$commit"
        }
    } >&2

    # new criterion:
    # the parents "include" all summands, and each parent is one of the summands.
    # that is, each parent is fast-forward of summands and a summand itself.
    # fixme!

    equal=y
    reason=""

    # Verify whether ...each parent is one of summands.

    set +u # here we risk the "var. lookup" fails, so we treat it explicitly!

    # Check that parents are subset of "summands" -- i.e. the sum is not AHEAD....btw.
    local sum_commit_id
    sum_commit_id=$(commit_id $sum_branch)

    missing_parents=()
    missing_summands=()

    # if the sum refers to one of the summand commit?
    # (r)
    if [[ ${summands_commit_ids[(r)$sum_commit_id]} = $sum_commit_id ]];then
        INFO "This merge is itself a summand: $sum_commit_id"
    else
        # here the O(N^2) tests:
        # verify
        # fixme:  keys:
        foreach id ($parents_commit_ids[@]) {
            if ! [[ ${summands_commit_ids[(r)$id]} = $id ]] ; then
                reason="parents not in summand"

                INFO "$sum_branch: This parent is not in summands: $id"
                missing_parents+=($id)
                # append & then check it!
                # equal=n
            else
                debug_trace "found $id:  ${(k)summands_commit_ids[(r)$id]}"
                # fixme: I could remove it!
                # $parents_commit_ids[(r)$id]
            fi
        }
    fi
    set -u # here again we don't (intend to) risk it.

    # 2/ each summand is less than the sum. not -> N
    foreach id ($summands_commit_ids[@]) {
        #if still a chance to win:
        if test $id = $sum_commit_id; then
            test $debug = y && echo ignoring ;  # for example S=a+b  but b>a.
        else
            # SOME of the parent covers it:
            if [[ $parents_commit_ids[(i)$id] -gt $#parents_commit_ids  ]]; then
                summand=${(k)summands_commit_ids[(r)$id]}
                missing_summands+=($summand)
                debug_trace "summand $summand is not a parent"
            fi
        fi
    }

    # todo: missing_parents
    if [[ $#missing_parents = 0 && $#missing_summands = 0 ]]; then
       return 0
    fi


    if [[ $debug = y ]]; then
        { cecho red "the remaining are: "
          dump_array "\t" $missing_summands
          dump_array "\t" $missing_parents
        } >&2
    fi

    if [[ $strict = y && ( $#missing_summands -gt 0 || $#missing_parents -gt 0 ) ]]; then
        equal=n
        return
    fi

    # how to get common base for merge:
    # git merge-base

    # analyze the mismatch:
    local unsolved=($missing_summands)
    local copy_missing_parents=($missing_parents)
    foreach summand ($missing_summands) {
        debug_trace "Trying to understand where summand $summand is"
        foreach parent ($missing_parents) {
            if test $(git merge-base $summand $parent) = $parent
            then
                INFO "summand $summand is greater than parent $parent"

                GREATER_SINCE+=($summand)
                equal=old
                unsolved[(r)$summand]=()
                copy_missing_parents[(r)$parent]=()
            elif
                # reflog:
                git log --walk-reflogs --pretty=oneline $summand |grep $parent >/dev/null
            then
                MOVED_SINCE+=($summand)
                cecho green "$sum_branch: summand $summand\thas moved since $parent" >&2
                equal=old
                unsolved[(r)$summand]=()
                copy_missing_parents[(r)$parent]=()
            else
                : unsolved
            fi
        }
    }

    if [[ $#unsolved -gt 0 ]]
    then
        {
            cecho red "$sum_branch: $#unsolved missing summands: "
            dump_array "\t" $unsolved[@]
        }
        equal=n
    elif [[ $#copy_missing_parents -gt 0 ]]; then
        INFO "($sum_branch) parents missing (did the sum-branch move?)"
        equal=n
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
        {
            git show-ref heads/$name || \
            git show-ref remotes/$name || \
            git show-ref $name
        } |\
            head -n 1|cut -f 2 '-d ')
    # echo "expanded $expanded" >&2
    echo $expanded
}

# return the full reference name
# possibly with a fixed preference:
expand_ref()
{
    local -r name=$1
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
                # git rev-parse --symbolic-full-name origin/master

                # why prioritize heads ?
                result=$(git rev-parse --symbolic-full-name $name 2>/dev/null)
                # this can succeed, but print:
                #   warning: refname 'mmc-build' is ambiguous.
                #   error: refname 'mmc-build' is ambiguous
                if [[ ( -z "$result" ) || ( $? != 0 ) ]]; then
                    ERROR "cannot resolve $name: "
                    git rev-parse --symbolic-full-name $name
                    exit 1
                fi
            fi
    esac

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

set_branch_to()
{
    local branch=$1
    local commit_id=$2

    if [ $branch = $(current_branch_name_maybe) ]
    then
        git reset --hard $commit_id
    else
        git branch --force $branch $commit_id
    fi
}

# return the branch checked-out. Error if in "detached HEAD" state.
current_branch_name()
{
    local head
    head=$(dump_ref_without_ref HEAD)
    head=${head##refs/heads/}
    if [ $head = HEAD ]; then
        cecho red "currently not on a branch" >&2
        exit 1;
    fi

    echo "$head"
}

# writes to stdout 2 kinds of lines:
#  segment: base
#   ....
#  sum: summand1 summand2 ...
#
# In alphabetic order?
# input: $debug, dump_format (see dump_segment()!)
# mmc: very low level, does not check the sums!
dump_whole_graph()
{
    readonly segment_format=$1

    local segments
    typeset -a segments
    # this list_segments is also in `git-segment'
    segments=($(git for-each-ref 'refs/base/' --format "%(refname)" --sort refname))
    if [ 0 =  ${#segments} ]; then
        echo "no segments." >&2
    else
        foreach segment ($segments);
        {
            dump_segment $segment_format ${segment#refs/base/}
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
            dump_sum $segment_format $sum
        }
    fi
}


# output with this format $1
# todo: should accept sum-format as $2
# in topological order!
dump_whole_graph_tsort()
{
    readonly segment_format=$1

    dump_whole_graph tsort | tsort | tac | \
        {
            # now in this order!
            while read ref;
            do
                ref=${ref#refs/heads/}
                # echo $ref >&2
                if is_segment $ref; then
                    dump_segment $segment_format $ref
                elif is_sum $ref; then
                    name=$ref

                    # todo: delegate dump_sum to make the check
                    # check the sum is up-to-date:
                    dump_sum --test $segment_format $ref
                else
                    :
                    # base might be just a branch!
                fi
            done
        }
}

test_sum_is_intact()
{
    local sum_name=$1
    local sum_branch=$(expand_ref $sum_name y)

    # summand_branches
    typeset -a real_branches
    sum_resolve_summands $sum_name real_branches
    # if git-branch-exists $sum_name;

    equal=n
    test_commit_parents $sum_branch $real_branches[@]
    if test "$equal" = n;
    then
        die "sum $sum_name is not the merge of other branches! ($real_branches[@])"
        exit -2
    fi
}

typeset -a processed
processed=()

# in environment:  debug
# typeset -a known_divergent
# Breadth first search
# output to STDOUT ?
walk_down_from()
{
    test_option=(--test)
    if [[ $1 = "--notest" ]]
    then
        test_option=()
        shift
    fi
    ref_name=$1
    segment_format=$2
    sum_format=${3-$segment_format}

    # local
    typeset -a queue
    queue=($ref_name)

    local this
    local name
    local cycle=1
    while [[ ${#queue} -ge 1 ]];
    do
        # fixme: processed comes as implicit parameter?
        queue=(${queue:|processed}) # A:|B is A-B.

        if [[ $#queue = 0 ]]; then
            break;
        fi

        this=${queue[1]}
        processed+=($this)

        STEP "processing $this, (queue is $queue ${#queue})"

        # append the base(s), or summands:
        if [[ $this =~ "^finish-(.*)" ]]
        then
            name=${this#finish-}

            if is_sum $name; then
                dump_sum $test_option ${sum_format} $name
            elif is_segment $name; then
                dump_segment $segment_format $name
            else
                die "what? $name"
            fi
        else
            name=${this#refs/heads/}

            # I need depth-first search:
            # pre-order:
            # can I put into queue a markere to have post-order?
            if is_sum $name; then
                # fixme: this should _test_

                # depth-first search: we prepend:
                # += append!
                # prepend:
                queue[1]=("finish-$name" $queue[1])
                queue[1]=($(summands_of $name) $queue[1])
            elif is_segment $name; then
                queue[1]=("finish-$name" $queue[1])
                queue[1]=($(segment_base $name) $queue[1])
            else
                CRITICAL "stopping @ $name -- not segment, nor sum"
            fi
        fi
        debug_trace "iterate $cycle: $queue"
        ((cycle+=1))
    done
}



# in environment:  debug
# typeset -a known_divergent
# Breadth first search
# output to STDOUT ?
walk_up_from()
# Given a name
# dump info on all segments based on that one, sums containing that one.
#
{
    test_option=(--test)
    if [[ $1 = "--notest" ]]
    then
        test_option=()
        shift
    fi
    ref_name=$1
    segment_format=$2
    sum_format=${3-$segment_format}

    # local
    typeset -a queue
    queue=($ref_name)

    local this
    local name
    while [[ ${#queue} -ge 1 ]];
    do
        queue=(${queue:|processed}) # A:|B is A-B. fixme: processed ?

        if [[ $#queue = 0 ]]; then
            break;
        fi

        this=${queue[1]}
        # remove "first" if it's repeated:
        # we don't need += here, since all previously processed cannot be in `queue' anymore,
        # if the graph is DAG (acyclic!):
        processed+=($this)


        # take the first, and append the base(s)
        # also remove "first" if it's repeated.

        # STEP
        STEP "processing $this, (queue is $queue ${#queue}" || : ok

        # append the base(s), or summands:
        name=${this#refs/heads/}

        if is_sum $name; then
            # fixme: this should _test_
            dump_sum $test_option ${sum_format} $name

            queue+=($(summands_of $name))
        elif is_segment $name; then
            dump_segment $segment_format $name
            queue+=($(segment_base $name))
        else
            CRITICAL "stopping @ $name"
        fi

        debug_trace "iterate ${#queue}: $queue"
    done
}



# use $debug
# set roots and tops.
find_roots_and_tops()
{
    readonly GRAPH=$1

    # Covered are those who are ancestors of others!
    # but it's not A base B. it must be verified that B is indeed below it! If B has moved, I want to see it!
    readonly VERTICES=$(mktemp -t git-graph-vertices.XXX)
    readonly ANCESTORS=$(mktemp -t git-graph-ancestors.XXX)

    cat $GRAPH | cut --fields=1 | sort -u > $VERTICES
    cat $GRAPH | cut -d '	' --fields 2- | sed -e "s/ /\n/g"| sort -u > $ANCESTORS
    # 3 common, 2 unique to ancestors = base.
    [ $verbose = "y" ] && { cecho red -n "the maximal bases/summands (ancestors) are "; comm -23  $VERTICES $ANCESTORS }

    # vertices ... roots^1 =  ^root^@ vertices

    #unique to ancestors.
    roots=( $(comm -1 -3 $VERTICES $ANCESTORS) )
    # unique to vertices
    tops=( $(comm -2 -3 $VERTICES $ANCESTORS) )
    rm -f $VERTICES $ANCESTORS
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
            echo "### mismatch! $1 vs $(cat $GIT_DIR/$git_segment_mark)"  >&2
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



# Closure above:
typeset -a fetched
fetched=()
# keys:  $remote:$remote_branch

# uses $dry_only, $fetch, $GIT_P4 $fetched, $debug
function fetch_upstream_of()
{
    local base=$1  # Full reference! refs/xxx/name
    local git_fetch=$fetch # could be $2 ?
    local remote
    local REMOTE_BRANCH
    local this_branch

    # Calculate remote
    if expr match $base 'refs/remotes/p4/' >/dev/null ;
    then
        remote=${base#refs/remotes/p4/}
        REMOTE_BRANCH=${remote}
        if [ $dry_only = no ]; then
            # readonly
            set -x
            local -r old=$(git rev-parse ${base#refs/})
            $GIT_P4 sync --branch $REMOTE_BRANCH --git-dir $(git rev-parse --git-common-dir)
            git log --oneline $old..${base#refs/}
        fi
        git_fetch=no
    elif expr match $base 'refs/remotes/' >/dev/null ;
    then
        remote=${base#refs/remotes/}
        remote_branch=${remote#*/}
        remote=${remote%/*}
        echo "the base is remote: $remote/$remote_branch"

    else
        if ! expr match $base 'refs/heads/' >/dev/null
        then #fixme:
            # so it's a simple name? e.g.  debian-unstable
            this_branch=$base
            base=refs/heads/$base
        fi

        # upstream
        remote_branch=$(git for-each-ref --format='%(upstream:short)' $base)
        if [[ -z $remote_branch ]]; then git_fetch=no; fi

        DEBUG "upstream: $remote_branch"
        remote=${remote_branch%/*}
        remote_branch=${remote_branch#*/}
    fi

    # and fetch it
    if [ $git_fetch = yes ]; then
        key="$remote:$remote_branch"

        if [[ $fetched[(i)${(q)key}] -le ${#fetched} ]]
        then
            DEBUG "already fetched from $remote $remote_branch"
        else
            fetched+=($key)
            INFO "Fetching upstream to $base: $remote" >&2
            if [ $dry_only = no ]; then
                # could this use `git-ff' ?
                local old_head=$(git rev-parse $remote/$remote_branch)
                git fetch $remote $remote_branch
                git log --oneline $old_head..FETCH_HEAD

                # funny: just like a filename: $(basename $base)
                git branch --force ${base#refs/heads/} $remote/$remote_branch
            else
                echo "would fetch from $remote $remote_branch"
            fi
        fi
    fi # manual! todo: understand what error scenarios are possible!

    # sometimes I point the segment base directly at remote, correct?
    if [ $dry_only = no ]; then
        if [ -n "${this_branch-}" ]; then
            warn "setting branch $this_branch to follow upstream"
            set_branch_to $this_branch $remote/$remote_branch
        fi
    fi
}
