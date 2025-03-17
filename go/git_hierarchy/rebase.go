package git_hierarchy

import (
	"fmt"
	"iter"
	"github.com/go-git/go-git/v5/plumbing"
	"github.com/go-git/go-git/v5/plumbing/storer"
	"github.com/go-git/go-git/v5/plumbing/object"
	//                                     ^^ package
	//                 ^^^^ module
	"github.com/samber/lo"
)

// func ReferenceHash

// rev-parse
func RefsToSameCommit(ref1 *plumbing.Reference, ref2 *plumbing.Reference) bool {
	// fmt.Println("comparing:\n", ref1,"\n", ref2)
	// TheRepository.ResolveRevision()

	// read 1 level:
	// ref1, _ = TheRepository.Reference(ref1.Target(), false)

	// this recursively:
	hashRef, err := storer.ResolveReference(TheRepository.Storer,ref1.Name())
	// ReferenceStorer, n plumbing.ReferenceName)
	CheckIfError(err, "resolving reference to hash")
	fmt.Println("ResolveReference:", hashRef.Hash())

	/*
	var hash plumbing.Hash
	for hash = ref1.Hash(); hash == plumbing.ZeroHash; hash = ref1.Hash() {
		fmt.Println("is 000", ref1)
		ref1, _ = TheRepository.Reference(ref1.Target(), false)
		fmt.Println("resolved to", ref1.Hash())
	}
	*/

	return hashRef.Hash() == ref2.Hash()
}

type rebaseResult int

const (
	RebaseNothing rebaseResult = iota
	RebaseDone
	RebaseFailed
)

func rebaseEmptySegment(segment Segment) {
	fmt.Println("rebase empty segment:", segment.Name())

	segment.SegmentResetStart()
	setReferenceTo(TheRepository, segment.Ref, segment.Base)
}


func RebaseSegmentFinish(segment Segment) rebaseResult {
	tempHead := "temp-segment"
	segment.SegmentResetStart()
	// reflog etc.
	gitRun("branch", "--force", segment.Name(), tempHead)
	gitRun("checkout", "--no-track", "-B", segment.Name())

	gitRun("branch", "--delete", tempHead)

	return RebaseDone
}

// todo: method
func RebaseSegment(segment Segment, options map[string]string ) rebaseResult {
	// but lacks the main porcelain operations such as merges.
	// options:
	repository := TheRepository

	//  *Reference
	mark := plumbing.NewSymbolicReference(".segment-cherry-pick", segment.Ref.Name())
	err := repository.Storer.SetReference(mark)

	// onto :=  segmentBase(seg.Name())
	onto := segment.Base
	start := segment.Start.Name().String()

	// err := repository.Storer.CheckAndSetReference(newRef, s.Start)
	onto_ref, err := storer.ResolveReference(repository.Storer, onto.Name()) // why Name?
	CheckIfError(err, "resolving new base")

	onto_ref = onto

	// same commits -- hash
	if RefsToSameCommit(onto_ref, segment.Start) {
		return RebaseNothing
	}

	// todo: empty segment!
	if RefsToSameCommit(segment.Ref, segment.Start) {
		rebaseEmptySegment(segment)
		return RebaseDone
	}

	// const
	tempHead := "temp-segment"
	fmt.Println("rebasing by Cherry-picking!", segment.Name())

	// checkout to that ref
	// todo: git stash
	gitRun("checkout", "--no-track", "-B", tempHead, onto.Name().String())

	err = gitRunStatus("cherry-pick", start + ".." + segment.Ref.Name().String()) // fixme: whole ref
	if err != nil {
		return RebaseFailed
	}

	return RebaseSegmentFinish(segment)
}

// convert from error-push to bool-push:
// func pushIterator[iface object.CommitIter, V *object.Commit] (ci iface) iter.Seq[V] {
func pushIterator (ci object.CommitIter) iter.Seq[*object.Commit] {

	return func(yield func(value *object.Commit) bool) {
		ci.ForEach(func (value *object.Commit) error {
			cont := yield(value)
			if !cont {
				return storer.ErrStop
			}
			return nil
		})
	}
}

func mapSummandsToCommitsReverse(sum Sum) map[plumbing.Hash]*plumbing.Reference {

	var summands = make(map[plumbing.Hash]*plumbing.Reference)

	for _, ref := range sum.summands {
		hash, err := TheRepository.ResolveRevision(plumbing.Revision(ref.Name().String()))
		CheckIfError(err, "resolving ref to hash")

		fmt.Println("summand", ref.Name(), "points at", hash)
		summands[*hash] = ref
	}

	return summands
}

func sumParentIter(sum Sum) object.CommitIter {
	// (*Commit, error)
	commit, err := TheRepository.CommitObject(sum.ref.Hash())
	CheckIfError(err, "resolving ref to commit")

	// git commit -> merge -> parents
	return commit.Parents()
}

// iterate, match with a `map', return list/slice of missing (or iterator)                                    vvvv not Item.
func findMissing[Item any, Item2, Id comparable](
	iterator func(yield func(Item) bool),
	id func(Item) Id,
	known map[Id]Item2) []Item {
	// where
	// K comparable, V int64 | float64

	var notFound []Item
	// = make([]Item, 5, 5) //

	for item := range iterator {
		// err := iter.ForEach(func (item* Item) error {
		hash := id(item)

		if _, ok := known[hash]; ok { // elem
			fmt.Println("parent", hash, "found to be") // id(elem)
		} else {
			fmt.Println("parent", hash, "NOT found in summands")

			notFound = append(notFound, item)
			fmt.Println("now :", len(notFound))
		}
	}

	// CheckIfError(err, "iteration")
	fmt.Println("returning:", len(notFound))
	return notFound
}


// 2 possible ways:
//
// we have Next() so `pull' iterator.
// we could make a push one from that.
// Pull returns 2  functions: next and stop()
// Pull2  converts Seq2 to ... ^^^      ^^^
func RebaseSum(sum Sum, options map[string]string ) rebaseResult {
	// is the sum a merge?

	hashToSummands := mapSummandsToCommitsReverse(sum) // to References !!

	commitIter := sumParentIter(sum)

	var notFound []*object.Commit

	notFound = findMissing[*object.Commit, *plumbing.Reference, plumbing.Hash] (
		// generate objects
		pushIterator(commitIter),
		// name the objects
		func(commit *object.Commit) plumbing.Hash { return commit.ID() },
		// set of known objects:
		hashToSummands)

	piecewise := false
	// empty
	if len(notFound) > 0 {
		fmt.Println("so the sum is not up-to-date!")
		// we have to remerge
		// gitRun("checkout", "--detach", first)
		// gitRuns"branch", "--force", work_branch, "HEAD")

		// resolve & divide:
		first, _ := TheRepository.Reference(sum.summands[0].Target(), false)

		others := lo.Map(sum.summands[1:],
			func (ref *plumbing.Reference, _ int) *plumbing.Reference {
				pointerRef, _ := TheRepository.Reference(ref.Target(), false)
				return pointerRef
			})

		tempHead := "temp-sum"

		// why not checkout  --
		gitRun("checkout", "--no-track", "-B", tempHead, first.Name().String())

		var message = "Sum:" + sum.Name() + "\n\n" + first.Name().String()
		for i, ref := range others {
			// resolve them! maybe sum.summands should be a map N -> ref
			// pointerRef, _ := TheRepository.Reference(ref.Target(), false)
			message += " + " + ref.Name().String()
			if i % 3 == 0 {
				message += "\n"
			}
		}

		otherNames := lo.Map(others,
			func (ref *plumbing.Reference, _ int) string {
				return ref.Name().String()})

		// otherNames...  cannot use otherNames (variable of type []string) as []any value in argument to
		fmt.Println("summands are:", first, otherNames)

		if piecewise {
			// reset & retry
			// piecewise:
			for _, next := range others {
				gitRun("merge", "-m",
					"Sum: " + next.Name().String() + " into " + sum.Name(),
					"--rerere-autoupdate", next.Name().String())
			}
		} else {
			/* fixme: https://go.dev/ref/spec#Passing_arguments_to_..._parameters */
			err := gitRunStatus(append([]string{
				"merge", "-m", message, // todo: newline -> file
				"--rerere-autoupdate",
				"--strategy", "octopus",
				"--strategy", "recursive",
				"--strategy-option", "patience",
				"--strategy-option", "ignore-space-change"},
				otherNames...)...)

			if err != nil {
				return RebaseFailed
			}

			// finish
			gitRun("branch", "--force", sum.Name(), tempHead)
			gitRun("switch", sum.Name())
			gitRun("branch", "--delete", tempHead)
		}
	}
	// do we have a hint -- another merge?
	// git merge
	return RebaseDone
}

var stashCommit *object.Commit

func unstashIfStashed() {
	if stashCommit != nil {
		// cecho yellow "unstashing now."
		gitRun("stash", "pop", "--quiet")
	}
}

// options map
// debug, dry...
// git-rebase-ref $dry_option $GIT_DEBUG_OPTIONS $ref;
func RebaseNode(gh GitHierarchy) rebaseResult {
	// mark
	// unmark
	options := make(map[string]string)
	/*
	if (dry) {
	return
	   }
	*/

	// fmt.Println("rebasing now", gh.Name())

	var result rebaseResult
	switch v := gh.(type) {
	case  Segment:
		fmt.Println("segment", v.Name())
		result = RebaseSegment(v, options)
	case  Sum:
		fmt.Println("sum !", v.Name())
		result = RebaseSum(v, options)
	case  Base:
		fmt.Println("plain base reference", v.Name())
		result = RebaseDone
	default:
		fmt.Println("unexpected git_hierarchy type")
		// error("unexpected")
		result = RebaseFailed
	}

	if (result != RebaseFailed) {
		unstashIfStashed()
	}
	return result
}
