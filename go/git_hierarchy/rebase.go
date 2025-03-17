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

// func (*Commit) IsAncestor
func RebaseSum(sum Sum, options map[string]string ) rebaseResult {
	// is the sum a merge?
	// func ParseObjectType(value string) (typ ObjectType, err error)

	// mmc: why?
	var summands = make(map[plumbing.Hash]*plumbing.Reference)

	for _, ref := range sum.summands {
		hash, err := TheRepository.ResolveRevision(plumbing.Revision(ref.Name().String()))
		CheckIfError(err, "resolving ref to hash")
		// ref.Hash()
		fmt.Println("summand", ref.Name(), "points at", hash)
		summands[*hash] = ref
	}

	// (*Commit, error)
	commit, err := TheRepository.CommitObject(sum.ref.Hash())
	// object.GetCommit(TheRepository.Storer, sum.ref.Hash())

	CheckIfError(err, "resolving ref to commit")
	// git commit -> merge -> parents

	// CommitIter*
	citer := commit.Parents()
	var notFound []*object.Commit

	// func(*Commit) error) error
	err = citer.ForEach(func (commit *object.Commit) error {
		// func (c *Commit) ID() plumbing.Hash
		hash := commit.ID()

		if elem, ok := summands[hash]; ok {
			fmt.Println("parent", hash, "found to be", elem.Name())
		} else {
			fmt.Println("parent", hash, "NOT found in summands")
			notFound = append(notFound, commit)
		}
		return nil
	})

	// if len(notFound)  // empty

	// do we have a hint -- another merge?
// citer.Close()
	// git merge
	return RebaseDone
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
		return RebaseSum(v, options)
	case  Base:
		fmt.Println("plain base reference", v.Name())
		return RebaseDone
	default:
		fmt.Println("unexpected git_hierarchy type")
		// error("unexpected")
		return RebaseFailed
	}
}
