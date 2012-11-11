#! /usr/bin/zsh -feu


git_dir()
{
    echo $(git rev-parse --show-toplevel)/.git
}


git-branch-exists()
{
    git show-ref refs/heads/$1 >/dev/null;
}
