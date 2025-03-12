package main

import (
	"fmt"
	"os"
	"slices"

	"github.com/pborman/getopt/v2" // version 2
	"github.com/go-git/go-git/v5"
	"github.com/go-git/go-git/v5/plumbing"

	"github.com/michalmaruska/git-hierarchy/git_hierarchy"
	"github.com/michalmaruska/git-hierarchy/graph"
)

func usage() {
	getopt.PrintUsage(os.Stderr)
}

func main() {
	helpFlag := getopt.BoolLong("help", 'h', "display help")
	// no errors, just fail:
	getopt.SetUsage(func() {
		getopt.PrintUsage(os.Stderr)
		fmt.Println("\nparameter:  from  to")
	})
	getopt.Parse() // os.Args

	if *helpFlag {
		// I want it to stdout!
		fmt.Println(plumbing.RefRevParseRules)
		getopt.Usage()
		os.Exit(0)
	}

	// plan: collect the graph, linearized,
	repository, err := git.PlainOpen(".")
	git_hierarchy.CheckIfError(err, "finding repository")
	git_hierarchy.TheRepository = repository

	args := getopt.Args()

	var top *plumbing.Reference
	// var err Error
	if len(args) > 0 {
		// := leads to crash!
		top = git_hierarchy.FullHeadName(repository, args[0])
		if top == nil {
			os.Exit(-1)
		}
		fmt.Println("Will descend from", top.Name())
	} else {
		current, err := repository.Head()
		git_hierarchy.CheckIfError(err)
		fmt.Println("Current head is", current.Name())
		top = current
	}

	vertices, incidenceGraph := git_hierarchy.WalkHierarchy(top)

	order, err := graph.TopoSort(incidenceGraph)
	git_hierarchy.CheckIfError(err)

	// I need reverse
	for _, j := range slices.Backward(order) {
		gh := git_hierarchy.GetHierarchy((*vertices)[j])

		status := git_hierarchy.RebaseNode(gh)
		if status == git_hierarchy.RebaseFailed {
			fmt.Println("failed on", gh.Name())
			os.Exit(1)
		}
	}

	// fmt.Println(current)
	os.Exit(0)
}
