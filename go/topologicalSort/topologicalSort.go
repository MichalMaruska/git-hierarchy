package topologicalSort

import (
	"fmt"
	"container/list"
)

// Graph represents a directed graph using an adjacency list
type Graph struct {
	vertices int
	adjList  map[int][]int
}
// NewGraph creates a new graph with n vertices
func NewGraph(n int) *Graph {
	return &Graph{
		vertices: n,
		adjList:  make(map[int][]int),
	}
}

// AddEdge adds a directed edge from u to v
func (g *Graph) AddEdge(u, v int) {
	g.adjList[u] = append(g.adjList[u], v)
}



// Function to perform topological sort
// Graph is (node N) -> [neighbour 1 .....],  so N->neighbourX
// n is max?

// edge from -> to
// means we want order (..... from .... to..)
// so to is larger/later ?
func Sort(graph *Graph) ([]int, error) {
	// map[int][]int, verticesCount int
	incidence := graph.adjList
	verticesCount := graph.vertices

	// Step 1: Initialize the in-degree array
	inDegree := make([]int, verticesCount)	  // mmc: or outDegree
	for _, neighbors := range incidence { // _node
		for _, neighbor := range neighbors {
			inDegree[neighbor]++
		}
	}

	// Step 2: Initialize a queue and add all nodes with zero in-degree
	queue := list.New()
	for i := 0; i < verticesCount; i++ {
		if inDegree[i] == 0 {
			queue.PushBack(i)
		}
	}

	// Step 3: Perform BFS
	result := []int{}
	count := 0

	for queue.Len() > 0 {
		// Pop a node from the queue
		// queue.Pop().Value.(int)
		node := queue.Front().Value.(int)
		queue.Remove(queue.Front())

		// Add node to the result
		result = append(result, node)
		count++

		// For each neighbor of the current node, reduce the in-degree
		for _, neighbor := range incidence[node] {
			inDegree[neighbor]-- // of course it was not 0
			if inDegree[neighbor] == 0 {
				queue.PushBack(neighbor)
			}
		}
	}

	// Step 4: Check for cycle (if count != verticesCount, there's a cycle)
	if count != verticesCount {
		return nil, fmt.Errorf("the graph has a cycle, topological sort is not possible")
	}

	return result, nil
}
