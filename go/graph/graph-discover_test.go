package graph

import (
	"testing"
	"fmt"
	"strconv"
)

type testGraph struct {
	n int
}

func (s testGraph) NodeIdentity() string {
	fmt.Println("NodeIdentity", s.n)
	return strconv.Itoa(s.n)
}

func (s testGraph) NodePrepare() NodeExpander { //  testGraph
	return s
}

func (s testGraph) NodeChildren()  []NodeExpander {
	// all divisors
	// testGraph
	var divisors []NodeExpander // *testGraph
	for i := 2;i < s.n; i++ {
		if (s.n % i == 0) {
			divisors = append(divisors,NodeExpander(&testGraph{i}))
		}
	}
	return divisors
}


func TestDiscover(t *testing.T) {
	// var g testGraph = [0..10]
	g := testGraph{10}
	fmt.Println("starting with node", g.NodeIdentity())
	res, graph := DiscoverGraph( &[]NodeExpander{g})
	// toposort
	fmt.Println(res)
	fmt.Println(graph)
}
