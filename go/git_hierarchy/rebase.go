package git_hierarchy

import (
	"fmt"
	"github.com/go-git/go-git/v5/plumbing"
	"github.com/go-git/go-git/v5/plumbing/storer"
	"github.com/go-git/go-git/v5/plumbing/object"
	//                                     ^^ package
	//                 ^^^^ module
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

	switch v := gh.(type) {
	case  Segment:
		fmt.Println("segment", v.Name())
		return RebaseSegment(v, options)
	case  Sum:
		fmt.Println("sum !", v.Name())
		// rebaseSum(v, options)
		// return RebaseSum(v, options)
	case  Base:
		fmt.Println("plain base reference", v.Name())
		return RebaseDone
	default:
		fmt.Println("unexpected git_hierarchy type")
		// error("unexpected")
		return RebaseFailed
	}
}
