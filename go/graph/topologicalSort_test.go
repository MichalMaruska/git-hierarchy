package graph
// If the test file is in the same package, it may refer to unexported identifiers within the package.
// If the file is in a separate "_test" package, the package being tested must be imported explicitly

// go test -test.v   ./...
import (
	"testing"
	"fmt"
)

func TestTopoSort(t *testing.T) {
	// Example graph (adjacency list representation)
	// Number of nodes
	// if testing.Short() {
	n := 6

	graph := NewGraph(n)
	graph.AddEdge(5, 2)
	graph.AddEdge(5, 0)
	graph.AddEdge(4, 0)
	graph.AddEdge(4, 1)
	graph.AddEdge(2, 3)
	graph.AddEdge(3, 1)

	/*
	graph := map[int][]int{
		0: {1, 2},
		1: {3},
		2: {3},
		3: {},
	}
	*/

	// Call topologicalSort
	result, err := Sort(graph)
	if err != nil {
		t.Errorf("Error: %s", err)
	} else {
		// assert_equal()
		if testing.Verbose() {
			fmt.Println("Topological Sort Order:", result)
		}
	}
}

func BenchmarkToposort(b *testing.B) {
	n := 6

	graph := NewGraph(n)
	graph.AddEdge(5, 2)
	graph.AddEdge(5, 0)
	graph.AddEdge(4, 0)
	graph.AddEdge(4, 1)
	graph.AddEdge(2, 3)
	graph.AddEdge(3, 1)

	b.ResetTimer()
	for range b.N  { // b.Loop()
	// Call topologicalSort
	result, err := Sort(graph)
	if err != nil {
		// t.Errorf("Error: %s", err)
	} else {
		// assert_equal()
		if testing.Verbose() {
			fmt.Println("Topological Sort Order:", result)
		}
	}
    }
}

// func TestMain(m *testing.M){}

/// Examples
func ExampleHello() {
    fmt.Println("hello")
    // Output: hello
}


// Fuzzing
// randomly generated inputs
//  f.Fuzz(func(t *testing.T, in []byte) {
