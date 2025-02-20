package main

import (
        "github.com/michalmaruska/git-hierarchy"

        "fmt"
        "os"
        // "io"
        "github.com/pborman/getopt/v2"  // version 2
        "github.com/go-git/go-git/v5"
        // . "github.com/go-git/go-git/v5/_examples"
        "github.com/go-git/go-git/v5/plumbing"
        // "github.com/go-git/go-git/v5/plumbing/storer"
        _ "github.com/go-git/go-git/v5/config"
        _ "github.com/go-git/go-git/v5/plumbing/storer"
)

func usage(){
        getopt.PrintUsage(os.Stderr)
}

func main(){
        helpFlag := getopt.BoolLong("help", 'h', "display help")
        // no errors, just fail:
        getopt.SetUsage(func () {
                getopt.PrintUsage(os.Stderr)
                fmt.Println("\nparameter:  from  to")})
        getopt.Parse() // os.Args

        if *helpFlag {
                // I want it to stdout!
                fmt.Println(plumbing.RefRevParseRules)
                getopt.Usage()
                os.Exit(0)
        }

        os.Exit(0)
}
