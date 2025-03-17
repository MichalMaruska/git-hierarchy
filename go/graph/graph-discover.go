package graph

import (
	"fmt"
)

const debug = false

type NodeExpander interface {
	NodeIdentity() string
	NodePrepare() NodeExpander   // visit ... pre-order?
	NodeChildren() []NodeExpander
}

func DiscoverGraph(topNodes *[]NodeExpander) (*[]NodeExpander, *Graph) {
	var vertices []NodeExpander = *topNodes
	// make([]*NodeExpander, 0, 10)

	// vertices = append(vertices, top) // .PushFront
	tail := len(*topNodes)
	// |--------------------......|  vertices
	//        ^ reader      ^appender

	// var known map[string]int
	known  := make(map[string]int)
	for i, node := range *topNodes {
		known[node.NodeIdentity()] = i // current
	}

	graph := NewGraph(1)

	for current := 0; current != tail; current= current+1 {
		this := vertices[current]

		// Body. Only once per node. So terminates.
		if debug {
			fmt.Println("looking at", this.NodeIdentity())
		}

		// todo: convert Ref -> gitHierarchy
		node := this.NodePrepare()
		vertices[current] = node

		children :=  node.NodeChildren()
		// I need edges: ref -> children

		// q.PushBackList(children)
		// reverse
		for _, child := range children {
			// fmt.Println("is", ref.Name().String(), "element?")

			// elem, ok = m[key]
			if childNode, ok := known[child.NodeIdentity()]; ok  {
				// a cycle? or just a sibling?
				// fmt.Println("skipping", child.NodeIdentity(), "but adding edge")
				graph.AddEdge(current, childNode)
				continue
			} else {
				vertices = append(vertices, child) // PushBack()
				known[child.NodeIdentity()] = tail
				// fmt.Println("scheduling", child.NodeIdentity(), "and adding edge")
				childNode = tail
				graph.AddEdge(current, childNode)
				tail += 1
			}
		}
		// fmt.Println("Adding", ref.Name().String())
		// known visited.Add(ref.Name().String())
	}
	graph.vertices = tail
	return &vertices, graph
}
