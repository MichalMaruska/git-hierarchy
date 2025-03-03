package main
// graphDiscover

import (
	"fmt"
	"strconv"
	// mapset "github.com/deckarep/golang-set/v2"
)


// any
type nodeExpander interface {
	// Read(b []byte) (n int, err os.Error)
	// these are all implicitly methods!
	NodeIdentity() string
	NodePrepare() nodeExpander
	NodeChildren() []nodeExpander
}


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


func discoverGraph(topNodes *[]nodeExpander) (*[]nodeExpander, *Graph) {
	// *list.List
	// a slice:
	var vertices []nodeExpander = *topNodes

	// make([]*nodeExpander, 0, 10)
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

	graph := NewGraph()

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


type testGraph struct {
	n int
}


func (s testGraph) NodeIdentity() string {
	fmt.Println("NodeIdentity", s.n)
	return strconv.Itoa(s.n)
}

func (s testGraph) NodePrepare() nodeExpander { //  testGraph
	return s
}

func (s testGraph) NodeChildren()  []nodeExpander {
	// all divisors
	// testGraph
	var divisors []nodeExpander // *testGraph
	for i := 2;i < s.n; i++ {
		if (s.n % i == 0) {
			divisors = append(divisors,nodeExpander(&testGraph{i}))
		}
	}
	return divisors
}


func main() {
	// var g testGraph = [0..10]
	g := testGraph{10}
	fmt.Println("starting with node", g.NodeIdentity())
	res, graph := discoverGraph( &[]nodeExpander{g})
	// toposort
	fmt.Println(res)
	fmt.Println(graph)
}
