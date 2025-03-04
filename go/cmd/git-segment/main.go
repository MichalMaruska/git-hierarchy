package main

/*
ref_extract_name
ref_exists
dump_symbolic_ref
dump_ref_without_ref
set_symbolic_reference
drop_symbolic_ref
expand_ref



list_sums()
summands_of
sum_resolve_summands
is_sum
delete_sum_definition
dump_sum
test_commit_parents

is_segment
drop_segment
segment_base_name
segment_base
segment_start
segment_age
segment_length
git-set-start
dump_segment

check_git_rebase_hooks

*/


import (
        "fmt"
        "os"
        "github.com/go-git/go-git/v5"
        // "github.com/go-git/go-git/v5/storage/filesystem"
        // "github.com/go-git/go-billy/v5/memfs"
        // with go modules enabled (GO111MODULE=on or outside GOPATH)
        // import "github.com/go-git/go-git" // with go modules disabled
        // "github.com/go-git/go-billy/v5"
        "github.com/go-git/go-git/v5/plumbing"

        // "github.com/pborman/getopt/v2"
        // imported as getopt ??
        // "nullprogram.com/x/optparse"
        // ^^^ I don't want because insists on --color=red not space. -- not true!
)



// In Go, a name is exported if it begins with a capital letter.
// func split(sum int) (x, y int) {
//            named return? .. treated as variables defined at the top of the function.

// A return statement without arguments returns the named return
// values. This is known as a "naked" return.
// They can harm readability in _longer_ functions.

// var i, j int = 1, 2
// Inside a function, the :=  .... implicity type
// const , but not :=

// A method is a function with a special receiver argument.
// You cannot declare a method with a receiver whose type is defined in another package

// Methods with pointer receivers can modify the value to which the receiver points

// func (v Vertex) Scale(f float64) {
// func (v *Vertex) Scale(f float64) { ... changes the receiver.

// methods with pointer receivers take either a value or a pointer

// For the statement v.Scale(5), even though v is a value and not a pointer,
// the method with the pointer receiver is called automatically.
// p.Abs() is interpreted as (*p).Abs().

// In general, all methods on a given type should have either value or
// pointer receivers, but not a mixture of both.
// var a Abser ... Interface!!!

// A type implements an interface by implementing its methods. There is no
// explicit declaration of intent, no "implements" keyword.

// A nil interface value holds neither value nor concrete type.

// fmt.Print takes any number of arguments of type interface{}.
// empty iface

// type assertion
// t = i.(T)
//
// switch v := i.(type) {

// method:  to call as ip.String()
// func (ip IPAddr) String() string {

// ForEach(func(*plumbing.Reference) error) error
// so they return error

// func(branch *plumbing.Reference) error {
//                                  ~~~~~ ?

// CheckIfError should be used to naively panics if an error is not nil.
func CheckIfError(err error) {
        if err == nil {
                return
        }

        fmt.Printf("\x1b[31;1m%s\x1b[0m\n", fmt.Sprintf("error: %s", err))
        os.Exit(1)
}


func main() {
        // %T  type?
        fmt.Println("Hello, world.")

        // what ?
        // func Open(s storage.Storer, worktree billy.Filesystem) (*Repository, error)
        repository, err := git.PlainOpen("..")
        CheckIfError(err)

        refs, err :=repository.References()
        CheckIfError(err)

        refs.ForEach(func(ref *plumbing.Reference) error {
                if ref.Name().IsBranch() {
                        fmt.Println(ref.Hash().String(), ref.Name())
                }
                return nil
        })

        branches, _ := repository.Branches()
        // Reference .isBranch()
        // func (r *Repository) Head() (*plumbing.Reference, error)
        // func (r *Repository) References() (storer.ReferenceIter, error)
        // what is storer.ReferenceIter vs plumbing.Reference ?
        // type ReferenceIter interface
        // I have base/ start/ sum/

        branches.ForEach(func(branch *plumbing.Reference) error {

                // function literal
                fmt.Println(branch.Hash().String(), branch.Name())
                return nil
        })

        //func NewRepositoryFilesystem(dotGitFs, commonDotGitFs billy.Filesystem) *RepositoryFilesystem
        // func New(fs billy.Filesystem) *DotGit
        // files, err := origin.ReadDir(".")
        // dotGitFs := New()


        // fs := NewRepositoryFilesystem(dotGitFs,)

        // RepositoryFilesystem
        // func (fs *RepositoryFilesystem) Open(filename string) (billy.File, error)
                // repository, error := fs.Open(".");
}

/*
// Clone the given repository to the given directory
Info("git clone https://github.com/go-git/go-git")

_, err := git.PlainClone("/tmp/foo", false, &git.CloneOptions{
    URL:      "https://github.com/go-git/go-git",
    Progress: os.Stdout,
})

CheckIfError(err)

*/
