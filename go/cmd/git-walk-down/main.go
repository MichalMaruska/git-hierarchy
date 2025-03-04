package main

import (
	"fmt"
	"github.com/michalmaruska/git-hierarchy/git-hierarchy"
	"github.com/michalmaruska/git-hierarchy/graph"

	"github.com/go-git/go-git/v5"
	"github.com/go-git/go-git/v5/plumbing"
)


func main() {

	repository, err := git.PlainOpen(".")
	git_hierarchy.TheRepo = repository

	current, err := repository.Reference(plumbing.ReferenceName("HEAD"), true)
	// fmt.Println(current)


	vertices, incidenceGraph := git_hierarchy.WalkHierarchy(current)

	if false {
		fmt.Println("Visited these git refs:")
		for i, v := range *vertices {
			fmt.Println(i, "->", v.NodeIdentity())
		}

		fmt.Println("Now edges:")
		graph.DumpGraph(incidenceGraph)
	}

	order, err := graph.TopoSort(incidenceGraph)
	git_hierarchy.CheckIfError(err)
	// dump index -> vertices[i]
	// fmt.Println("order:", order)
	for _, j := range order {
		a := (*vertices)[j]
		gh := git_hierarchy.GetHierarchy(a)

		switch v := gh.(type) {
		case  git_hierarchy.Segment:
			fmt.Println("segment", v.Name())
		case  git_hierarchy.Sum:
			fmt.Println("sum", v.Name())
		case  git_hierarchy.Base:
			fmt.Println("plain base reference", v.Name())
		default:
			fmt.Println("unexpected git_hierarchy type")
			// error("unexpected")
		}
	}
	// os.Exit(0)
}
