package git_hierarchy

import (
	"fmt"
	"strings"

	// "github.com/go-git/go-git/v5" // why named git not go-git
	"github.com/go-git/go-git/v5/plumbing"
	// "github.com/go-git/go-git/v5/config"
	// ~/git/go-git/config/branch.go
	// "github.com/go-git/go-git/v5/format/config"
)

func SplitRemoteRef(refName plumbing.ReferenceName) (string, string) {
	// Given
	// assert refName.IsRemote()

	prefix, _ := strings.CutSuffix(plumbing.RefRevParseRules[4], "%s")
	// dropPrefix RefRevParseRules[4]
	rest, _ := strings.CutPrefix(refName.String(), prefix)
	// find (/)
	i := strings.Index(rest, "/")
	remote := rest[:i]
	fmt.Println("remote:", remote)
	// split
	remoteBranch := rest[i:]
	return remote, remoteBranch
}

func remoteBranch(remote string, remoteRef *plumbing.ReferenceName) plumbing.ReferenceName{
	return plumbing.ReferenceName("remote/" + remote + branchName(remoteRef))
}

func FetchUpstreamOf(ref *plumbing.Reference) {
	// type
	// switch os := runtime.GOOS; os {
	fmt.Println("Fetching:", ref.Name())

	if refName := ref.Name(); refName.IsRemote() {
		fmt.Println("it's remote:")
		remote, remoteBranch := SplitRemoteRef(refName)

		// fetch it
		// func (r *Remote) Fetch(o *FetchOptions) error
		// get remote and branch
		// TheRepository.Remotes()

		gitRun("fetch", remote, remoteBranch)
		// gitRun("log", "--oneline",  old_head + ".." + "FETCH_HEAD")
		// git branch --force ${base#refs/heads/} $remote/$remote_branch

	} else if refName.IsBranch() {

		// it seems I must checkout for "git pull"
		fmt.Println("it's a branch, remote?")

		config, err := TheRepository.Storer.Config()
		// config.LoadConfig(config.LocalScope)
		//  GlobalScope  ... ~/.gitconfig ... is broken. [x.y] section
		// LocalScope should be read from the a ConfigStorer

		CheckIfError(err, "load config")
		config.Validate()
		br := config.Branches[branchName(ref)] //  refName.String()
		if (br != nil) {
			println("ok, found info: ", br.Name, br.Remote, br.Merge)
		}

		// is it on it?
		if compareRefs(ref, remoteBranch(br.Remote, br.Merge)) {
			// gitRun("pull", refName, string(br.Merge) + ":")
			gitRun("fetch", br.Remote, string(br.Merge) + ":")
		}
		// git fetch debian refs/heads/main:

		// plumbing.ReferenceName
		// look at config  merge
		// git config branch.base.merge
		// remote
		// func (r *Remote) List(o *ListOptions) (rfs []*plumbing.Reference, err error)

		// good idea!
		// w, err := r.Worktree()
		// func (r *Repository) Remotes() ([]*Remote, error)
		// w.Pull(&git.PullOptions{RemoteName: "origin"})
		// gitRun("pull")

	} else {
		fmt.Println("what is it?")
		// no way to modify
		// head
	}
	// rest
}


func fetch_upstream_ofs(nodes []GitHierarchy) {
	for _, gh := range nodes {
		switch gh.(type) {
		case  Base:
			FetchUpstreamOf(gh.(Base).Ref)
		default:
			// no
		}
	}
}
