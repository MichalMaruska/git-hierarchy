package git_hierarchy

import (
	"fmt"
	"strings"
	"strconv"
	"os"
	// "io"
	"github.com/go-git/go-git/v5"
	// . "github.com/go-git/go-git/v5/_examples"
	"github.com/go-git/go-git/v5/plumbing"
	// "github.com/go-git/go-git/v5/plumbing/storer"
	_ "github.com/go-git/go-git/v5/config"
	_ "github.com/go-git/go-git/v5/plumbing/storer"

	"container/list"
)


// todo: move into common file:
func CheckIfError(err error, msgs ...string) {
	if err == nil {
		return
	}

	fmt.Printf("\x1b[31;1m%s\x1b[0m\n", fmt.Sprintf("error: %s", err))

	if len(msgs) > 0 {
		for _, msg := range msgs {
			fmt.Println(msg)
		}
	}

	os.Exit(1)
}


func Unimplemented(){
	fmt.Fprintln(os.Stderr, "Not implemented")
	os.Exit(1)
}



// MatchAny returns true if any of the RefSpec match with the given ReferenceName.
// Massage the user-provided branch name into full reference.
func fullHeadName(repository *git.Repository, refName string) *plumbing.Reference {
	// HEAD -> ?
	// name
	// heads/name
	for _,pattern := range plumbing.RefRevParseRules {
		s := fmt.Sprintf(pattern, refName)
		// existence test:
		// repository.storer.Reference(plumbing.ReferenceName) (*plumbing.Reference, error)
		ref2, error := repository.Reference(plumbing.ReferenceName(s), false) // not resolved
		if (error == nil) {
			// fmt.Println("found", ref2.Name(), s)
			return ref2
		}
	}
	return nil
}

// const
var head_prefix string

// func (s, suffix string) (before string, found bool)
// "refs/heads/"
func init(){
	// note:
	head_prefix, _ = strings.CutSuffix(plumbing.RefRevParseRules[3], "%s")
}

const sumPattern = "refs/sums/%s"
const sumSummandPattern = "refs/sums/%s/%d"
const sumSummandPrefix = "refs/sums/"
const segmentBasePattern = "refs/base/%s"
const segmentStartPattern = "refs/start/%s"


func referenceExists(repository *git.Repository, name string) bool {
	// not resolved
	_, error := repository.Reference(plumbing.ReferenceName(name), false)
	return (error == nil)
}

func sumSummand(name string, n int) plumbing.ReferenceName {

	return plumbing.ReferenceName(
		fmt.Sprintf(sumSummandPattern, name, n))
}


func refsWithPrefix(repository *git.Repository, prefix string) []plumbing.Reference {
	collector := []plumbing.Reference{}

	refIter, _ := repository.References()
	// fmt.Fprintln(os.Stderr, "looking for this prefix:", prefix)
	refIter.ForEach( func(ref *plumbing.Reference) error {
		// fmt.Fprintln(os.Stderr, "looking at", ref.Name().String())

		if strings.HasPrefix(ref.Name().String(), prefix) {
			// fmt.Fprintln(os.Stderr,"found")
			collector = append (collector, *ref) //  yield
			// found = branch
			// return ErrStop
		}

		return nil
	})

	// fmt.Fprintln(os.Stderr,"returning", len(collector))
	return collector
}

func symbolic_refs_to(repository *git.Repository, ref *plumbing.Reference, prefix string) []plumbing.Reference{
	collector := refsWithPrefix(repository, prefix)

	var refs []plumbing.Reference
	// todo: a function for this:
	s := "ref: " + ref.Name().String()

	for _, ref := range collector {
		content := dump_symbolic_ref(&ref)
		// reduced, _ := strings.CutPrefix(content, "ref: ")
		if s == content {
			refs = append(refs, ref)
		}
	}

	return refs
}

func base_for(repository *git.Repository, ref *plumbing.Reference)  []plumbing.Reference {
	// iterate over given prefix
	return symbolic_refs_to(repository, ref, "refs/base/")
}

func summand_of(repository *git.Repository, ref *plumbing.Reference)  []plumbing.Reference{
	return symbolic_refs_to(repository, ref, "refs/sums/")
}


// return collection
func sumSummands(repository *git.Repository, sName string) []plumbing.Reference {
	return refsWithPrefix(repository,  sumSummandPrefix + sName + "/")
}

func isSum(name string, repository *git.Repository) (bool, []plumbing.Reference) {
	// expand all subtree
	summands := sumSummands(repository, name)
	return len(summands) > 0, summands
}


// todo: implicit repository ... global variable?
func segmentBase(name string) plumbing.ReferenceName {
	return plumbing.ReferenceName(
		fmt.Sprintf(segmentBasePattern, name))
}

func segmentStart(name string) plumbing.ReferenceName {
	return plumbing.ReferenceName(fmt.Sprintf(segmentStartPattern, name))
}

func isSegment(name string, repository *git.Repository) (bool,*plumbing.Reference) {
	s := fmt.Sprintf(segmentBasePattern, name)

	// returns the base and boolean?
	base , err :=repository.Reference(plumbing.ReferenceName(s), false)
	return (err == nil), base
	// return referenceExists(repository, s)
}

//  *plumbing.ReferenceName
func dump_symbolic_ref(ref *plumbing.Reference) string {
	// func NewSymbolicReference(n, target ReferenceName) *Reference
	content := ref.Strings()
	fmt.Println("symbolic ref", content[0], "points at", content[1])
	return content[1]
	// return plumbing.NewSymbolicReference("ref:/heads/x", "")
	// *Reference
	// "ref:"
}

// drop
// ReferenceStorer
func set_symbolic_reference(repository *git.Repository,
	refName plumbing.ReferenceName, content string) *plumbing.Reference {
	// todo: NewReferenceFromStrings(content)
	reduced, _ := strings.CutPrefix(content, "ref: ")

	ref := plumbing.NewSymbolicReference(refName, plumbing.ReferenceName(reduced))
	repository.Storer.SetReference(ref)
	return ref
}


func drop_symbolic_ref(repository *git.Repository, ref *plumbing.Reference ) error {
	// git update-ref --no-deref -d $ref
	return repository.Storer.RemoveReference(ref.Name())
}


// given a reference, change its name? the contents remains the same
func rename_symbolic_reference(repository *git.Repository,
	ref *plumbing.Reference, newName plumbing.ReferenceName){

	fmt.Println("rename symbolic:", ref.Name(), "as", newName)

	if ref.Name() == newName {
		return
	}
	var content = dump_symbolic_ref(ref)
	fmt.Println("contains:", content)

	set_symbolic_reference(repository, newName, content)

	err := drop_symbolic_ref(repository, ref)
	CheckIfError(err)
}

var verbose = true

// not symbolic
func rename_reference(repository *git.Repository, ref *plumbing.Reference,
	newName plumbing.ReferenceName) {

	if verbose {fmt.Println("Renaming ref", ref.Name().String(), "to", newName.String())}

	var content = ref.Hash() // dump_symbolic_ref(ref)
	newRef := plumbing.NewHashReference(newName, content)
	repository.Storer.SetReference(newRef)

	// drop_symbolic_ref(repository, ref)
	err := repository.Storer.RemoveReference(ref.Name())
	CheckIfError(err)
}

func branchName(full *plumbing.Reference) string {
	// fmt.Println("cut", head_prefix, "from", full.Name().String())
	sName, _ := strings.CutPrefix(full.Name().String(), head_prefix) // todo: strip
	return sName
}

// Given a head (sum or segment), rename it.
func Rename(repository *git.Repository, from string, to string) {
	// var found bool
	full := fullHeadName(repository, from)
	if (full == nil) {
		// return error("the branch does not exist")
		return
	}
	sName := branchName(full)

	// no.... just drop the
	toFull := head_prefix + to
		// fullHeadName(repository, to)


	fmt.Println("would use ", sName, "as base for derived references")

	newName, _ := strings.CutPrefix(to, head_prefix)

	// begin transaction!
	rename_reference(repository, full, plumbing.ReferenceName(toFull))

	// todo: duplicate all
	// redirect
	// drop

	// walk all bases, sums,
	// change those:
	above := base_for(repository, full)
	sums_with := summand_of(repository, full)

	var ref plumbing.Reference

	for _, ref = range above {
		set_symbolic_reference(repository, ref.Name(), toFull)
	}
	for _, ref = range sums_with {
		set_symbolic_reference(repository, ref.Name(), toFull)
	}

	// unimplemented()

	if is, summands := isSum(sName, repository); is {
		fmt.Println("Sum summands")
		// for ...
		// walkReferencesTree
		prefix := sumSummandPrefix + sName + "/"

		for _, s := range summands {
			// refIter.ForEach( func(ref *plumbing.Reference) error {
			// fmt.Println(branch.Hash().String(), branch.Name())
			// match
			// func (r *Repository) References() (storer.ReferenceIter, error)
			// ref, err := repository.Reference(sumSummand(sName, n), false)
			// CheckIfError(err)  ParseUint
			end, _ := strings.CutPrefix(s.Name().String(), prefix)
			n, _ := strconv.Atoi(end)
			rename_symbolic_reference(repository, &s, sumSummand(newName, n))
		}
	}

	if is, base := isSegment(sName, repository); is {
		// fmt.Println("it's a segment!")

		// ref, err := repository.Reference(segmentBase(sName), false)
		// CheckIfError(err)
		rename_symbolic_reference(repository, base, segmentBase(newName))

		ref, err := repository.Reference(segmentStart(sName), false)
		CheckIfError(err)
		rename_reference(repository, ref, segmentStart(newName))
	}

}

var TheRepo *git.Repository

type gitHierarchy interface{
	// segment | sum
	Children() []*plumbing.Reference // gitHierarchy
	Name() string
}

type  segment struct {
	ref *plumbing.Reference
	base *plumbing.Reference
	start *plumbing.Hash
}

func (s segment) Name() string {
	return branchName(s.ref)
}

func (s segment) Children() []*plumbing.Reference {
	repository := TheRepo

	base, err := repository.Reference(plumbing.ReferenceName(segmentBase(s.Name())), false)
	CheckIfError(err)
	start, err1 := repository.Reference(plumbing.ReferenceName(segmentStart(s.Name())), false)
	CheckIfError(err1)

	return []*plumbing.Reference{base, start}
}


type  sum struct {
	ref *plumbing.Reference
	summands  []*plumbing.Reference
}

// todo: identical. Generics?
func (s sum) Name() string {
	return branchName(s.ref)
}

func (s sum) Children() []*plumbing.Reference {
	return sumSummands(TheRepo, s.Name())
}

type base struct {
	ref plumbing.Reference
}

// ErrStop
// discover_subgraph
// hopefully acyclic
// type HandlerFunc func(ResponseWriter, *Request)
func walk_graph(top *gitHierarchy) { // func neighbors() []gitHierarchy
	// <node>
	var q List = List.New().PushFront(top)
	// []*gitHierarchy{top}

	// list:
	var visited []*gitHierarchy // references
	for this = q.Front(); this != nil; {
		// this = first(q)

		if member(this, visited) {
			continue
		} else {
			neigh := neighbors(top)


			q = append(q, neigh)
			visited = append(visited, this)
		}
	}
}

