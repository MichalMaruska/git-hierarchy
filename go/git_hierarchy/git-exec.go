package git_hierarchy

import (
	"fmt"
	"log"
	"io"
	"os/exec"
)

func gitRun(args ...string) {
	err := gitRunStatus(args...)

	if err != nil {
		fmt.Println("git execution failed!")
		log.Fatal(err)
		// os.exit(err)
	}
}

func gitRunStatus(args ...string) error {
	cmd := exec.Command("/usr/bin/git", args...)

	if verbose {
		fmt.Println("$>", cmd.String())
		// return
	}

	// return cmd.Run()
	stderr, err := cmd.StderrPipe()
	if err != nil {
		log.Fatal(err)
	}

	if err := cmd.Start(); err != nil {
		log.Fatal(err)
	}

	slurp, _ := io.ReadAll(stderr)
	fmt.Printf("%s\n", slurp)

	err = cmd.Wait()
	return err
}
