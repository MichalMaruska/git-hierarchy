#! /usr/bin/zsh -feu


git_dir()
{
    echo $(git rev-parse --show-toplevel)/.git
}


