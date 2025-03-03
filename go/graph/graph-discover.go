package graph
// graphDiscover

import (
	"fmt"
	// mapset "github.com/deckarep/golang-set/v2"
)


// any
type NodeExpander interface {
	// Read(b []byte) (n int, err os.Error)
	// these are all implicitly methods!
	NodeIdentity() string
	NodePrepare() NodeExpander
	NodeChildren() []NodeExpander
}

/*
//  move away, from dfs.go
type Graph struct {
	adjList map[int][]int
}

// NewGraph initializes a new graph
func NewGraph() *Graph {
	return &Graph{adjList: make(map[int][]int)}
}

// AddEdge adds an edge to the graph
func (g *Graph) AddEdge(v, w int) {
	g.adjList[v] = append(g.adjList[v], w)
	g.adjList[w] = append(g.adjList[w], v) // For an undirected graph
}
*/


func discoverGraph(topNodes *[]NodeExpander) (*[]NodeExpander, *Graph) {
	// *list.List
	// a slice:
	var vertices []NodeExpander = *topNodes

	// make([]*NodeExpander, 0, 10)
	// list.New()
	// vertices = append(vertices, top) // .PushFront
	tail := len(*topNodes)
	// |--------------------......|  vertices
	//        ^ reader      ^appender

	// var known map[string]int
	known  := make(map[string]int)
	// mapset.NewSet[string]()
	for i, node := range *topNodes {
		known[node.NodeIdentity()] = i // current
	}

	graph := NewGraph(1)

	for current := 0; current != tail; current= current+1 {
		this := vertices[current]

		// Body. Only once per node. So terminates.
		fmt.Println("looking at", this.NodeIdentity())

		// todo: convert Ref -> gitHierarchy
		node := this.NodePrepare()

		children :=  node.NodeChildren()
		// I need edges: ref -> children

		// q.PushBackList(children)
		// reverse
		for _, child := range children {
			// fmt.Println("is", ref.Name().String(), "element?")

			// elem, ok = m[key]
			if childNode, ok := known[child.NodeIdentity()]; ok  {
				// a cycle? or just a sibling?
				// fmt.Println("skipping", ref.Name())
				graph.AddEdge(current, childNode)
				continue
			} else {
				vertices = append(vertices, child) // PushBack()
				childNode = tail
				graph.AddEdge(current, childNode)
				tail += 1
			}
		}
		// fmt.Println("Adding", ref.Name().String())
		// known visited.Add(ref.Name().String())
	}
	return &vertices, graph
}
