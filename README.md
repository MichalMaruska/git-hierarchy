### Sample session:


you somehow have "master" to point at some base upstream commit.

    $ git-segment bgnone master

will create branch-segment  "bgnone". You can see with  gitk(1),
that 2 references accompany this: start & base.

"start" is pointing at the commit, which is now current at "master",
"base" is pointing at the head "master".

That means, that when we "git pull", and "master" will move to follow
upstream, "base" will move along with "master", but "start" will
remain.

Then commit something on bgnone.

Create another segment:
       $  git-segment misc master
...  commit something on misc

Now, create a sum of the 2 segments. For example you want to make a feature
branch which relies on the 2 features. Or just to build the SW.

$ git-sum all  bgnone misc
This declares the "sum" of the 2 features.
